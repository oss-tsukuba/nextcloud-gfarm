<?php
declare(strict_types=1);

namespace OCA\Files_external_gfarm\Storage;

use OC\Files\Storage\Flysystem;
use OC\Files\Storage\Flysystem\Common;
use OCP\Files\StorageAuthException;
use OCA\Files_External\Lib\StorageConfig;

use OCA\Files_external_gfarm\Auth\AuthMechanismGfarm;

class Gfarm extends \OC\Files\Storage\Local {
	//const APP_NAME = 'files_external_gfarm';

	const MYPROXY_LOGON = "/nc-gfarm/app-gfarm/bin/dummy-myproxy-logon";
	const GRID_PROXY_INFO = "/nc-gfarm/app-gfarm/bin/dummy-grid-proxy-info";
	const GFARM_MOUNT = "/nc-gfarm/app-gfarm/bin/gfarm-mount";
	const GFARM_UMOUNT = "fusermount -u";

	public const GFARM_MOUNTPOINT_POOL = "/tmp/gf/";
	//public const GFARM_MOUNTPOINT_POOL = "/dev/shm/gf/";

	private $debug_traceid = NULL;
	private $enable_debug = true;
	//private $enable_debug = false;

	private function log_prefix() {
		return "[" . $this->debug_traceid . "]("
			. __CLASS__
			. ": access nextcloud_user=" . $this->nextcloud_user
			. ", storage_owner=" . $this->storage_owner
			. ", gfarm_user=" . $this->user
			. ", gfarm_dir=" . $this->gfarm_dir
			. ", encryption=" . print_r($this->encryption, true)
			. ", mountpoint=" . $this->mountpoint
			. ", auth_scheme=" . $this->auth_scheme
			. ") ";
	}

	public function debug($message) {
		if ($this->enable_debug) {
			syslog(LOG_DEBUG, $this->log_prefix() . $message);
		}
	}

	public function error($message) {
			syslog(LOG_ERR, $this->log_prefix() . $message);
	}

	private function exception_params() {
		return " (access nextcloud_user=" . $this->nextcloud_user
			. ", storage_owner=" . $this->storage_owner
			. ". gfarm_user=" . $this->user
			. ", gfarm_dir=" . $this->gfarm_dir
			. ", auth_scheme=" . $this->auth_scheme
			. ")";
	}

	public function invalid_arg_exception($message) {
		$this->error($message);  // print empty arguments
		return new \InvalidArgumentException($message);
	}

	public function auth_exception($message) {
		$this->error($message);
		return new StorageAuthException($message  . $this->exception_params());
	}

	public function stacktrace() {
		$backtrace = debug_backtrace(0, 0);
		foreach ($backtrace as $step) {
			if (isset($step['class'], $step['function'])) {
				$c = $step['class'];
				$f = $step['function'];
				syslog(LOG_DEBUG, ">> " . print_r($c, true) . " " . print_r($f, true));
			}
			else {
				syslog(LOG_DEBUG, ">> " . gettype($step));
			}
		}
	}

	private static function is_valid_param($param) {
		return !empty($param) && is_string($param);
	}

	public function __construct($arguments) {
		if ($this->enable_debug) {
			//syslog(LOG_DEBUG, __CLASS__ . ": __construct()");
			syslog(LOG_DEBUG, "__construct: arguments: " . print_r($arguments, true));
		}

		if (! self::is_valid_param($arguments['user'])) {
			throw $this->invalid_arg_exception('no Gfarm username');
		}
		if (! self::is_valid_param($arguments['gfarm_dir'])) {
			throw $this->invalid_arg_exception('no Gfarm directory');
		}
		if (! self::is_valid_param($arguments['password'])) {
			throw $this->invalid_arg_exception('no password');
		}

		// false: not mount, to get informations only, to umount
		$mount = true;
		if (isset($arguments['manipulated']) && $arguments['manipulated']) {
			$this->storage_owner = $arguments['storage_owner'];
			$this->auth_scheme = $arguments['auth_scheme'];
			$this->mount_type = $arguments['mount_type'];
			$this->encryption = $arguments['encryption'];
		} else {
			$mount = false;
		}

		$this->debug_traceid = bin2hex(random_bytes(4));
		$this->gfarm_dir = $arguments['gfarm_dir'];
		$this->user = $arguments['user']; // Gfarm username
		$this->password = $arguments['password'];
		$this->nextcloud_user = $this->getAccessUser();

		$this->arguments = $arguments;

		if ($mount === true) {
			if (isset($arguments['mount'])) {
				$mount = $arguments['mount'];
			}
		}
		if ($mount) {
			$this->mountpoint = $this->mountpoint_init();
			if ($this->mountpoint === null) {
				throw $this->invalid_arg_exception('cannot create mountpoint');
			}
		} else {
			$this->mountpoint = /
		}
		$this->debug("all parameters initialized");

		if ($mount) {
			$this->mount_start();
		}

		# for Local.php
		$arguments['datadir'] = $this->mountpoint;
		parent::__construct($arguments);
		//$this->debug("__construct() done");
	}

	private function mount_start() {
		if ($this->auth_scheme
			=== AuthMechanismGfarm::SCHEME_GFARM_SHARED_KEY) {
			$this->auth = new GfarmAuthGfarmSharedKey($this);
		} elseif ($this->auth_scheme
				  === AuthMechanismGfarm::SCHEME_GFARM_MYPROXY) {
			$this->auth = new GfarmAuthMyProxy($this);
		} elseif ($this->auth_scheme
				  === AuthMechanismGfarm::SCHEME_GFARM_X509_PROXY) {
			//$this->auth = new GfarmAuthX509Proxy($this); //TODO
			throw $this->auth_exception("not implemented yet");
		} else {
			throw $this->auth_exception("unknown auth_scheme");
		}

		if ($this->encryption && ! $this->auth->encryption_supported()) {
			throw $this->auth_exception("encryption unsupported");
		}

		$remount = false;
		if (! $this->auth->conf_ready()) {
			if (! $this->auth->conf_init()) {
				throw $this->auth_exception("cannot create files for authentication");
			}
		}
		if (! $this->auth->authenticated()) {
			if (! $this->auth->conf_init()) { // reset
				throw $this->auth_exception("cannot recreate files for authentication");
			}
			if (! $this->auth->logon()) {
				throw $this->auth_exception("logon failed");
			}
			$remount = true;
			if (! $this->auth->authenticated()) {
				$this->gfarm_umount();
				throw $this->auth_exception("authentication failed");
			}
		}

		if (! $this->gfarm_mount($remount)) {
			throw $this->auth_exception("gfarm mount failed");
		}
	}

	public function __destruct() {
	}

	private function getAccessUser() {
		return \OC_User::getUser();
	}

	private function mountpoint_init() {
		$owner_dir = $this->storage_owner;
		$user = $this->user;
		$gfarm_dir = $this->gfarm_dir;
		$encryption = $this->encryption;
		$length = 8;
		$allowed_chars = str_split('_ ');

		$owner_dir_tmp = str_replace($allowed_chars, '', $owner_dir);
		if (! ctype_alnum($owner_dir_tmp)) {
			$owner_dir = 'H:' . substr(sha1($owner_dir), 0, $length);
		}

		if ($encryption) {
			$enc_str = "ENC:";
		} else {
			$enc_str = "NOENC:";
		}
		$hashed_path = substr(sha1($enc_str . $gfarm_dir), 0, $length);
		$mountpoint = self::GFARM_MOUNTPOINT_POOL . "/" . $owner_dir . "/" . $user . "/" . $hashed_path;
		$mountpoint = str_replace('//', '/', $mountpoint);
		$recursive = true;
		if (! file_exists($mountpoint)) {
			mkdir($mountpoint, 0700, $recursive); // may race
			if (! file_exists($mountpoint)) {
				return null;
			}
		}
		return $mountpoint;
	}

	private function mount_common($mode) {
		$command = self::GFARM_MOUNT
				   . " "
				   . $mode
				   . " "
				   . escapeshellarg($this->gfarm_dir)
				   . " "
				   . escapeshellarg($this->mountpoint)
				   . " "
				   . escapeshellarg($this->auth->type)
				   . " "
				   . escapeshellarg($this->auth->gfarm_conf)
				   . " "
				   . escapeshellarg($this->auth->x509_proxy_cert)
				   . " "
				   . escapeshellarg($this->debug_traceid)
				   ;
		$output = null;
		$retval = null;
		exec($command, $output, $retval);
		if ($retval === 0) {
			return true;
		} else {
			return false;
		}
	}

	public function gfarm_check_auth() {
		//$this->debug("gfarm_check_auth");
		return $this->mount_common("CHECK_AUTH");
	}

	public function gfarm_mount($remount) {
		$mode = $remount ? "REMOUNT" : "MOUNT";
		return $this->mount_common($mode);
	}

	public static function umount_static($mountpoint) {
		$command = self::GFARM_UMOUNT . " " . escapeshellarg($mountpoint);
		$output = null;
		$retval = null;
		exec($command, $output, $retval);
		try {
			rmdir($mountpoint);
		} catch (Exception $e) {
			// ignore
		}
		return $retval;
	}

	public function gfarm_umount() {
		$retval = self::umount_static($this->mountpoint);
		if ($retval === 0) {
				$this->debug("gfarm_umount done");
		} else {
				$this->error("gfarm_umount failed");
		}
		$this->auth->conf_clear();
	}

// 	private function logon() {
// 		return $this->myproxy_logon($password);
// 	}

// 	private function myproxy_logon($password) {
// 		$gfarm_dir = $this->gfarm_dir;
// 		$mountpoint = $this->mountpoint;
// 		$user = $this->user;

// 		$command = self::MYPROXY_LOGON . " " . $mountpoint . " " . $user . " " . $gfarm_dir;

// 		$descriptorspec = array(
// 			0 => array("pipe", "r"),
// 			1 => array("pipe", "w"),
// 			2 => array("pipe", "w") );

// 		$cwd = '/';
// 		$env = array();

// 		$process = proc_open($command, $descriptorspec, $pipes, $cwd, $env);

// 		$output = null;
// 		$retval = null;
// 		if (is_resource($process)) {
// 			fwrite($pipes[0], "$password\n");
// 			fclose($pipes[0]);
// 			$output = stream_get_contents($pipes[1]);
// 			fclose($pipes[1]);
// 			fclose($pipes[2]);

// 			$retval = proc_close($process);
// 		}
// //syslog(LOG_DEBUG, "command: [" . print_r($command, true) . "]");
// //syslog(LOG_DEBUG, "output: [" . print_r($output, true) . "]");
// //syslog(LOG_DEBUG, "retval: [" . print_r($retval, true) . "]");
// 	}

// 	private function grid_proxy_info() {
// 		$gfarm_dir = $this->gfarm_dir;
// 		$mountpoint = $this->mountpoint;
// 		$user = $this->user;

// 		$command = self::GRID_PROXY_INFO . " " . escapeshellarg($mountpoint);
// 		$output = null;
// 		$retval = null;
// 		exec($command, $output, $retval);
// //syslog(LOG_DEBUG, "command: [" . print_r($command, true) . "]");
// //syslog(LOG_DEBUG, "output: [" . print_r($output, true) . "]");
// //syslog(LOG_DEBUG, "retval: [" . print_r($retval, true) . "]");
// 		return $retval;
// 	}

}

abstract class GfarmAuth {
	public const LOCAL_USER = "www-data";

	public function __construct(Gfarm $gf, $type) {
		$this->type = $type;
		$this->gf = $gf;
		$this->mp = $gf->mountpoint;
		$this->gfarm_conf =  $this->mp . ".gfarm2.conf";
		$this->x509_proxy_cert = $this->mp . ".x509_proxy_cert";
	}

	abstract public function encryption_supported();
	abstract public function conf_init();
	abstract public function conf_ready();
	abstract public function conf_clear();
	abstract public function authenticated();
	abstract public function logon();

	protected function file_put($filename, $content) {
		if (! file_exists($filename)) {
			touch($filename);
			if (! chmod($filename, 0600)) {
				return false;
			}
		}
		return file_put_contents($filename, $content, LOCK_EX);
	}

	private const SUPPORT_AUTH_TYPE_GSI = 'gsi';
	private const SUPPORT_AUTH_TYPE_TLS = 'tls';
	private const SUPPORT_AUTH_TYPE_KERBEROS = 'kerberos';

	// type => filename
	private const SUPPORT_AUTH = array(
		GfarmAuth::SUPPORT_AUTH_TYPE_GSI => 'SUPPORT_AUTH_TYPE_GSI',
		GfarmAuth::SUPPORT_AUTH_TYPE_TLS => 'SUPPORT_AUTH_TYPE_TLS',
		GfarmAuth::SUPPORT_AUTH_TYPE_KERBEROS => 'SUPPORT_AUTH_TYPE_KERBEROS',
		);

	private function support_auth_common($type) {
		$filename = self::SUPPORT_AUTH[$type];
		$filepath = $this->gf::GFARM_MOUNTPOINT_POOL . $filename;
		if (file_exists($filepath)) {  // initialized
			$flag = trim(file_get_contents($filepath));
			return ($flag === "1");
		}

		// initializing

		// TODO : not work because gfstatus call gfarm_initialize()
		// before preparing configuration files.

		// $command = "gfstatus";
		// exec($command, $lines, $retval);
		// if ($retval !== 0) {
		// 	return false;
		// }

		$output_str = <<<EOF
client auth gsi     : available
client auth tls     : available
client auth kerberos: not available

EOF;
		$lines = explode("\n",
						  str_replace(array("\r\n", "\r", "\n"), "\n",
									  $output_str));

		$result = false;
		foreach (array_keys(self::SUPPORT_AUTH) as $t) {
			$tmp = $this->support_auth_init($lines, $t);
			if ($type === $t) {
				$result = $tmp;
			}
		}
		return $result;
	}

	private function support_auth_init($gfstatus_lines, $type) {
		$filename = self::SUPPORT_AUTH[$type];
		$filepath = $this->gf::GFARM_MOUNTPOINT_POOL . $filename;
		foreach ($gfstatus_lines as $line) {
			if (preg_match('/^client auth ' . $type . '/', $line)
				&& preg_match('/: available/', $line)) {
				file_put_contents($filepath, "1");
				return true;
			}
		}
		file_put_contents($filepath, "0");
		return false;
	}

	protected function support_auth_gsi() {
		return $this->support_auth_common(self::SUPPORT_AUTH_TYPE_GSI);
	}

	protected function support_auth_tls() {
		return $this->support_auth_common(self::SUPPORT_AUTH_TYPE_TLS);
	}

	protected function support_auth_kerberos() {
		return $this->support_auth_common(self::SUPPORT_AUTH_TYPE_KERBEROS);
	}

	public const METHOD_SHARED     = 0x01;
	public const METHOD_TLS_SHARED = 0x02;
	public const METHOD_TLS_CLIENT = 0x04;
	public const METHOD_GSI_AUTH   = 0x08;
	public const METHOD_GSI        = 0x10;
	public const METHOD_KRB_AUTH   = 0x20;
	public const METHOD_KRB        = 0x40;

	private function enabled($a, $b) {
		return ($a & $b) ? "enable" : "disable";
	}

	protected function auth_conf($methods) {
		$enable_sharedsecret = $this->enabled($methods, self::METHOD_SHARED);
		$enable_tls = $this->enabled($methods, self::METHOD_TLS_SHARED);
		$enable_tls_client = $this->enabled($methods, self::METHOD_TLS_CLIENT);
		$enable_gsi_auth = $this->enabled($methods, self::METHOD_GSI_AUTH);
		$enable_gsi = $this->enabled($methods, self::METHOD_GSI);
		$enable_kerberos_auth = $this->enabled($methods, self::METHOD_KRB_AUTH);
		$enable_kerberos = $this->enabled($methods, self::METHOD_KRB);

		$delete_tls = "";
		$delete_gsi = "";
		$delete_kerberos = "";

		if (! $this->support_auth_tls()) {
			$delete_tls = "# ";
		}
		if (! $this->support_auth_gsi()) {
			$delete_gsi = "# ";
		}
		if (! $this->support_auth_kerberos()) {
			$delete_kerberos = "# ";
		}

		$conf_str = <<<EOF
auth {$enable_sharedsecret} sharedsecret *
{$delete_tls}auth {$enable_tls} tls_sharedsecret *
{$delete_tls}auth {$enable_tls_client} tls_client_certificate *
{$delete_gsi}auth {$enable_gsi_auth} gsi_auth *
{$delete_gsi}auth {$enable_gsi} gsi *
{$delete_kerberos}auth {$enable_kerberos_auth} kerberos_auth *
{$delete_kerberos}auth {$enable_kerberos} kerberos *

EOF;
		return $conf_str;
	}
}

class GfarmAuthGfarmSharedKey extends GfarmAuth {
	public const TYPE = "sharedsecret";

	public function __construct(Gfarm $gf) {
		parent::__construct($gf, self::TYPE);

		$this->gfarm_usermap = $this->mp . ".gfarm_usermap";
		$this->gfarm_shared_key = $this->mp . ".gfarm_shared_key";

		//$this->private_key_str = $this->gf->arguments['private_key'];
		//$this->gx509_private_key = $mp . ".x509_private_key";
	}

	public function encryption_supported() {
		return $this->support_auth_tls();
	}

	public function conf_init() {
		$conf_str = <<<EOF
shared_key_file   "{$this->gfarm_shared_key}"
local_user_map    "{$this->gfarm_usermap}"

EOF;
		if ($this->gf->encryption && $this->support_auth_tls()) {
			$conf_str = $conf_str . $this->auth_conf(self::METHOD_TLS_SHARED);
		} else {
			$conf_str = $conf_str . $this->auth_conf(self::METHOD_SHARED);
		}
		$gfarm_user = $this->gf->user;
		$local_user = self::LOCAL_USER;
		$usermap_str = <<<EOF
$gfarm_user $local_user

EOF;

		// overwrite
		if (! $this->file_put($this->gfarm_conf, $conf_str)) {
			return false;
		}
		if (! $this->file_put($this->gfarm_usermap, $usermap_str)) {
			return false;
		}
		if (! $this->file_put($this->gfarm_shared_key, $this->gf->password . "\n")) {
			return false;
		}
		return true;
	}

	public function conf_ready() {
		return (file_exists($this->gfarm_conf)
				&& file_exists($this->gfarm_usermap)
				&& !file_exists($this->gfarm_shared_key));
	}

	public function conf_clear() {
		unlink($this->gfarm_conf);
		unlink($this->gfarm_usermap);
		unlink($this->gfarm_shared_key);
	}

	public function authenticated() {
		return $this->gf->gfarm_check_auth();
	}

	public function logon() {
		return true;
	}
}

class GfarmAuthMyProxy extends GfarmAuth {
	public const TYPE = "myproxy";

	public function __construct(Gfarm $gf) {
		parent::__construct($gf, self::TYPE);
	}

	public function encryption_supported() {
		return true;
	}

	public function conf_init() {
		if ($this->gf->encryption) {
			$conf_str = $this->auth_conf(self::METHOD_GSI);
		} else {
			$conf_str = $this->auth_conf(self::METHOD_GSI_AUTH);
		}

		$usermap_str = <<<EOF
$gfarm_user $local_user

EOF;

		// overwrite
		if (! $this->file_put($this->gfarm_conf, $conf_str)) {
			return false;
		}
		return true;
	}

	public function conf_ready() {
		return (file_exists($this->gfarm_conf));
	}

	public function conf_clear() {
		unlink($this->gfarm_conf);
	}

	public function authenticated() {
		return $this->gf->gfarm_check_auth();
	}

	public function logon() {
		// TODO myproxy-logon
		return true;
	}

}
