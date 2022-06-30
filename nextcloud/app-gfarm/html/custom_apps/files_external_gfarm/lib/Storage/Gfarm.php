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

	const GFARM_MOUNTPOINT_POOL = "/tmp/gf/";
	//const GFARM_MOUNTPOINT_POOL = "/dev/shm/gf/";

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
			. ", mountpoint=" . $this->mountpoint
			. ", auth_scheme=" . $this->auth_scheme
			. ") ";
	}

	private function debug($message) {
		if ($this->enable_debug) {
			syslog(LOG_DEBUG, $this->log_prefix() . $message);
		}
	}

	private function error($message) {
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

	private function invalid_arg_exception($message) {
			$this->error($message);
			return new \InvalidArgumentException($message  . $this->exception_params());
	}

	private function auth_exception($message) {
			$this->error($message);
			return new StorageAuthException($message  . $this->exception_params());
	}

	private function stacktrace() {
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

		if (! self::is_valid_param($arguments['storage_owner'])) {
			throw $this->invalid_arg_exception('no storage owner username');
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

		$this->debug_traceid = bin2hex(random_bytes(4));

		$this->storage_owner = $arguments['storage_owner'];

		$this->gfarm_dir = $arguments['gfarm_dir'];
		$this->user = $arguments['user']; // Gfarm username
		$this->password = $arguments['password'];

		$this->auth_scheme = $arguments['auth_scheme'];

		$this->nextcloud_user = $this->getAccessUser();
		$this->mountpoint = $this->mountpoint_init();
		if ($this->mountpoint === null) {
			throw $this->invalid_arg_exception('cannot create mountpoint');
		}

		$this->arguments = $arguments;

		$this->debug("all parameters initialized");

		// ----------------------------------------

		if ($this->auth_scheme
			=== AuthMechanismGfarm::SCHEME_GFARM_SHARED_KEY) {
			$this->auth = new GfarmAuthGfarmSharedKey($this);
		} elseif ($this->auth_scheme
				  === AuthMechanismGfarm::SCHEME_GFARM_MYPROXY) {
			//$this->auth = new GfarmAuthMyProxy($this); //TODO
			$this->auth = new GfarmAuthGfarmSharedKey($this);
		} elseif ($this->auth_scheme
				  === AuthMechanismGfarm::SCHEME_GFARM_X509_PROXY) {
			//$this->auth = new GfarmAuthX509Proxy($this); //TODO
			$this->auth = new GfarmAuthGfarmSharedKey($this);
		} else {
			throw this->auth_exception("unknown auth_scheme");
		}

		$remount = false;
		if (! $this->auth->conf_ready()) {
			if (! $this->auth->conf_init()) {
				throw $this->auth_xception("cannot create files for authentication");
			}
		}
		if (! $this->auth->authenticated()) {
			if (! $this->auth->conf_init()) { // reset
				throw $this->auth_xception("cannot recreate files for authentication");
			}
			if (! $this->auth->logon()) {
				throw $this->auth_exception("logon failed");
			}
			$remount = true;
			if (! $this->auth->authenticated()) {
				throw $this->auth_exception("authentication failed");
			}
		}

		if (isset($arguments['mount'])) {
			$mount = $arguments['mount'];
		} else {
			$mount = "true"; // default
		}
		if($mount !== "false") {  // not bool type
			$mount = "true"; // default
		}
		// "false" to umount
		if ($mount === "true"
			&& ! $this->gfarm_mount($remount)) {
			throw $this->auth_exception("gfarm mount failed");
		}

		//$this->debug("__construct() done");

		# for Local.php
		$arguments['datadir'] = $this->mountpoint;
		parent::__construct($arguments);
	}

	public function __destruct() {
		//$this->gfarm_umount();  //TODO umount in backgroud ?

		//$this->debug("__destruct() done");
	}

	// override Local
	// public function stat($path) {
	// 	$this->debug("stat: " . $path);
	// 	return parent::stat($path);
	// }

	private function getAccessUser() {
		return \OC_User::getUser();
	}

	private function mountpoint_init() {
		$owner_dir = $this->storage_owner;
		$user = $this->user;
		$gfarm_dir = $this->gfarm_dir;
		$length = 8;

		$hashed_path = substr(sha1($gfarm_dir), 0, $length);
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
		$this->debug("gfarm_check_auth");
		return $this->mount_common("CHECK_AUTH");
	}

	public function gfarm_mount($remount) {
		$mode = $remount ? "REMOUNT" : "MOUNT";
		return $this->mount_common($mode);
	}

	public function gfarm_umount() {
		$command = self::GFARM_UMOUNT . " " . escapeshellarg($this->mountpoint);
		$output = null;
		$retval = null;
		exec($command, $output, $retval);
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

	private function support_auth_common($filename, $type) {
		// check once
		if (file_exists($filename)) {
			$flag = trim(file_get_contents($filename));
			return ($flag === "1");
		}

		// TODO from config ?
		return true;

		// not work because gfstatus call gfarm_initialize() before
		// preparing configuration files.

		// $command = "gfstatus";
		// exec($command, $output, $retval);
		// if ($retval !== 0) {
		// 	return false;
		// }
		// foreach ($output as $line) {
		// 	if (preg_match('^client auth ' . $type, $line)
		// 		&& preg_match(': available', $line)) {
		// 		file_put_contents($filename, "1");
		// 		return true;
		// 	}
		// }
		// file_put_contents($filename, "0");
		// return false;
	}

	private const SUPPORT_GSI_FILE = "SUPPORT_GSI";
	private const SUPPORT_TLS_FILE = "SUPPORT_TLS";
	private const SUPPORT_KERBEROS_FILE = "SUPPORT_KERBEROS";

	protected function support_gsi() {
		$f = $this->gf::GFARM_MOUNTPOINT_POOL . self::SUPPORT_GSI_FILE;
		return $this->support_auth_common($f, 'gsi');
	}

	protected function support_tls() {
		$f = $this->gf::GFARM_MOUNTPOINT_POOL . self::SUPPORT_TLS_FILE;
		return $this->support_auth_common($f, 'tls');
	}

	protected function support_kerberos() {
		$f = $this->gf::GFARM_MOUNTPOINT_POOL . self::SUPPORT_KERBEROS_FILE;
		return $this->support_auth_common($f, 'kerberos');
	}

	public const METHOD_SHARED_KEY = 0x01;
	public const METHOD_TLS        = 0x02;
	public const METHOD_TLS_CLIENT = 0x04;
	public const METHOD_GSI_AUTH   = 0x08;
	public const METHOD_GSI        = 0x10;
	public const METHOD_KRB_AUTH   = 0x20;
	public const METHOD_KRB        = 0x40;

	private function enabled($a, $b) {
		return ($a & $b) ? "enable" : "disable";
	}

	protected function auth_conf($methods) {
		$enable_sharedsecret = $this->enabled($methods, self::METHOD_SHARED_KEY);
		$enable_tls = $this->enabled($methods, self::METHOD_TLS);
		$enable_tls_client = $this->enabled($methods, self::METHOD_TLS_CLIENT);
		$enable_gsi_auth = $this->enabled($methods, self::METHOD_GSI_AUTH);
		$enable_gsi = $this->enabled($methods, self::METHOD_GSI);
		$enable_kerberos_auth = $this->enabled($methods, self::METHOD_KRB_AUTH);
		$enable_kerberos = $this->enabled($methods, self::METHOD_KRB);

		$delete_tls = "";
		$delete_gsi = "";
		$delete_kerberos = "";

		if (! $this->support_tls()) {
			$delete_tls = "# ";
		}
		if (! $this->support_gsi()) {
			$delete_gsi = "# ";
		}
		if (! $this->support_kerberos()) {
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

	public function conf_init() {
		$conf_str = <<<EOF
shared_key_file   "{$this->gfarm_shared_key}"
local_user_map    "{$this->gfarm_usermap}"

EOF;
		$conf_str = $conf_str . $this->auth_conf(self::METHOD_SHARED_KEY);

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
