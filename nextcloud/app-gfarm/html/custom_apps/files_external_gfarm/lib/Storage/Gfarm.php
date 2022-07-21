<?php
declare(strict_types=1);

namespace OCA\Files_external_gfarm\Storage;

use OC\Files\Storage\Common;
use OCP\Files\StorageAuthException;
use OCP\Files\Storage\IStorage;
use OCP\IConfig;
use OCA\Files_External\Lib\StorageConfig;

use OCA\Files_external_gfarm\Auth\AuthMechanismGfarm;

class Gfarm extends \OC\Files\Storage\Local {
	//const APP_NAME = 'files_external_gfarm';

	const GRID_PROXY_INFO = "/nc-gfarm/app-gfarm/bin/dummy-grid-proxy-info";
	const GFARM_MOUNT = "/nc-gfarm/gfarm-mount";
	const GFARM_UMOUNT = "fusermount -u";

	public const GFARM_MOUNTPOINT_POOL = "/tmp/gf/";

	private $enable_debug = false;

	public $debug_traceid = NULL;
	public $nextcloud_user = NULL;
	public $storage_owner = NULL;
	public $user = NULL;
	public $gfarm_dir = NULL;
	public $secureconn = NULL;
	public $mountpoint = NULL;
	public $auth_scheme = NULL;

	private function log_prefix() {
		return "[" . $this->debug_traceid . "]("
			. __CLASS__
			. ": access nextcloud_user=" . $this->nextcloud_user
			. ", storage_owner=" . $this->storage_owner
			. ", gfarm_user=" . $this->user
			. ", gfarm_dir=" . $this->gfarm_dir
			. ", secureconn=" . print_r($this->secureconn, true)
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
		$this->config = \OC::$server->get(IConfig::class);
		$this->enable_debug = $this->config->getSystemValue('debug', false);
		if ($this->enable_debug) {
			//syslog(LOG_DEBUG, __CLASS__ . ": __construct()");
			//syslog(LOG_DEBUG, "!!!DANGER: Must be commented out!!! __construct: arguments: " . print_r($arguments, true));
		}

		if (! self::is_valid_param($arguments['gfarm_dir'])) {
			throw $this->invalid_arg_exception('no Gfarm directory');
		}
		if (! self::is_valid_param($arguments['password'])) {
			throw $this->invalid_arg_exception('no password');
		}

		$this->debug_traceid = bin2hex(random_bytes(4));

		// false: not mount, to get informations only, to umount
		if (isset($arguments['manipulated']) && $arguments['manipulated']) {
			// NOTE: These values cannot be used for datadir.
			$this->mount_type = $arguments['mount_type'];
			$this->storage_owner = $arguments['storage_owner'];
			$mount = true;
		} else {
			$this->mount_type = null;
			$this->storage_owner = null;
			$mount = false;
		}
		if ($mount === true) {
			if (isset($arguments['mount'])) {
				$mount = $arguments['mount'];
			}
		}
		$this->mount = $mount;

		$this->secureconn = $arguments['secureconn'];
		if ($this->secureconn === 1 || $this->secureconn === true) {
			$this->secureconn = true;
		} else {
			$this->secureconn = false;
		}

		$this->gfarm_dir = $arguments['gfarm_dir'];
		$this->user = $arguments['user']; // Gfarm user or Myproxy user
		$this->password = $arguments['password'];
		$this->nextcloud_user = $this->getAccessUser();

		$this->arguments = $arguments;

		$this->auth_scheme = AuthMechanismGfarm::get_scheme($arguments);
		if ($this->auth_scheme === null) {
			throw $this->invalid_exception("no auth_scheme");
		} elseif ($this->auth_scheme === AuthMechanismGfarm::SCHEME_GFARM_X509_PROXY) { // TODO
			throw $this->invalid_exception("not implemented yet");
		}

		// required by GfarmAuth::create
		if (! file_exists(self::GFARM_MOUNTPOINT_POOL)) {
			try {
				mkdir(self::GFARM_MOUNTPOINT_POOL, 0700, true);
			} catch (Error $e) {
			}
			if (! file_exists(self::GFARM_MOUNTPOINT_POOL)) {
				throw $this->invalid_exception("cannot create directory: " . self::GFARM_MOUNTPOINT_POOL);
			}
		}

		$this->auth = GfarmAuth::create($this);
		// mountpoint is not ready here
		$this->id_init();

		# NOTE: datadir is not used for getId() (overrided),
		# because getId() must be unique among all users.
		# To make mountpoint unique, mountpoint includes password as hash,
		# but password may not be passed to Storage\Gfarm.
		if (isset($this->password)) {
			$this->mountpoint = $this->mountpoint_init();
			if ($this->mountpoint === null) {
				throw $this->invalid_arg_exception('cannot create mountpoint');
			}
		} elseif ($mount) {
				throw $this->invalid_arg_exception('unexpected condition');
		} else {
			$this->mountpoint = "__DUMMY__";
		}

		$this->debug("Gfarm storage parameters are ready");

		if ($mount) {
			$this->mount_start();
		}

		# for Local.php
		$arguments['datadir'] = $this->mountpoint;
		parent::__construct($arguments);
		//$this->debug("__construct() done");
	}

	// public function __destruct() {
	// }

	private function getAccessUser() {
		return \OC_User::getUser();
	}

	private function secureconn_str() {
		if ($this->secureconn) {
			return "SEC";
		} else {
			return "INSEC";
		}
	}

	private function id_init() {
		// NOTE: password is not available for Id
		$method = $this->auth->auth_method();
		$user = $this->auth->username();
		$gfarm_dir = $this->gfarm_dir;
		$secure = $this->secureconn_str();

		// DO NOT CHANGE
		$this->id = 'gfarm::' . sha1($method . $user . $gfarm_dir . $secure);
	}

	// override
	public function isLocal() {
		return false;
	}

	// override
	public function getId() {
		return $this->id;
	}

	// override
	public function instanceOfStorage($class) {
		if (ltrim($class, '\\') === 'OC\Files\Storage\Local') {
			// to avoid calling rename() in moveFromStorage()
			// when a file is deleted.
			return false;
		}
		return parent::instanceOfStorage($class);
	}

	private function mountpoint_init() {
		// return "/tmp/gf/METHOD_USER_BASENAME_HASH(base64)"
		// HASH = base64_encode(hash(id+password))
		$method = $this->auth->auth_method();
		$user = $this->auth->username();
		$gfarm_dir = $this->gfarm_dir;
		//$secure = $this->secureconn_str();
		$password = $this->password;
		$id = $this->id;
		$hash_algo = 'sha512/224';

		$pattern = '/[^\w\d]+/';
		$replacement = '';
		$user_mod = preg_replace($pattern, $replacement, $user);
		$bn = basename($gfarm_dir);
		$bn = preg_replace($pattern, $replacement, $bn);

		$hash_src =  $id . $password;
		//$this->debug($hash_src);
		$hash_str = base64_encode(hash($hash_algo, $hash_src, true));
		$hash_str = str_replace('/', '-', $hash_str);
		$hash_str = str_replace('=', '', $hash_str);

		$mountpoint = self::GFARM_MOUNTPOINT_POOL . '/' . $method . '_' . $user_mod . '_' .  $bn . '_' . $hash_str;
		$mountpoint = str_replace('//', '/', $mountpoint);
		$recursive = false;
		if ($this->mount && !file_exists($mountpoint)) {
			try {
				mkdir($mountpoint, 0700, $recursive); // may race
			} catch (Error $e) {
			}
			if (! file_exists($mountpoint)) {
				return null;
			}
		}
		return $mountpoint;
	}

	private function mount_start() {
		if ($this->gfarm_check_mount()) { // shortcut
			// already mounted
			return;
		}

		if ($this->secureconn && ! $this->auth->secureconn_supported()) {
			throw $this->auth_exception("secureconn unsupported");
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
				   . escapeshellarg($this->auth->gfarm_conf())
				   . " "
				   . escapeshellarg($this->auth->x509_proxy_cert())
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

	public function gfarm_check_mount() {
		//$this->debug("gfarm_check_mount");
		return $this->mount_common("CHECK_MOUNT");
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
		foreach (glob($mountpoint . '.*') as $filename) {
			try {
				$ret = unlink($filename);
			} catch (Error $e) {
				// ignore
			}
		}
		$retry_max = 10;
		for ($i = 0; $i < $retry_max; $i++) {
			try {
				if (rmdir($mountpoint)) {
					break;
				}
			} catch (Error $e) {
				// ignore
			}
			sleep(1);
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
		try {
			$this->auth->conf_clear();
		} catch (Exception $e) {
			// ignore
		}
	}

}

abstract class GfarmAuth {
	public const LOCAL_USER = "www-data";

	// NOTE: $this->gf->mountpoint is not used yet
	public static function create($gfarm) {
		$auth_scheme = $gfarm->auth_scheme;
		if ($auth_scheme
			=== AuthMechanismGfarm::SCHEME_GFARM_SHARED_KEY) {
			return new GfarmAuthGfarmSharedKey($gfarm);
		} elseif ($auth_scheme
				  === AuthMechanismGfarm::SCHEME_GFARM_MYPROXY) {
			return new GfarmAuthMyProxy($gfarm);
		} elseif ($auth_scheme
				  === AuthMechanismGfarm::SCHEME_GFARM_X509_PROXY) {
			//$this->auth = new GfarmAuthX509Proxy($this); //TODO
			throw $gfarm->invalid_exception("not implemented yet");
		}
		throw $gfarm->invalid_exception("unknown auth_scheme: " . $auth_scheme);
	}

	protected function init(Gfarm $gf, $type) {
		$this->type = $type;
		$this->gf = $gf;
	}

	protected function secureconn_info_set($enabled_func, $secure, $insecure) {
		$this->sec = $this->$enabled_func();
		if ($this->gf->secureconn && $this->sec) {
			$this->method = $secure;
		} else {
			$this->method = $insecure;
		}
	}

	public function secureconn_supported() {
		return $this->sec;
	}

	public function username() {
		return $this->gf->user;
	}

	public function auth_method() {
		return $this->method;
	}

	// The followings MUST be called after $gf->mountpoint_init()
	// return array(funcname, secure, insecure)
	abstract public function conf_init();

	abstract public function conf_ready();
	abstract public function conf_clear();
	abstract public function authenticated();
	abstract public function logon();

	public function gfarm_conf() {
		if (!isset($this->gfconf)) {
			$this->gfconf = $this->gf->mountpoint . ".gfarm2.conf";
		}
		return $this->gfconf;
	}

	public function x509_proxy_cert() {
		if (!isset($this->x509proxy)) {
			$this->x509proxy = $this->gf->mountpoint . ".x509_proxy_cert";
		}
		return $this->x509proxy;
	}

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

		$command = 'gfstatus -S 2> /dev/null';
		exec($command, $lines, $retval);
		if ($retval === 0) {
			// Gfarm version 2.8 or later
		} else {
			// Gfarm version 2.7
			$output_str = <<<EOF
client auth gsi     : available
client auth tls     : not available
client auth kerberos: not available

EOF;
			$lines = explode("\n",
					 str_replace(array("\r\n", "\r", "\n"), "\n",
								 $output_str));
		}

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

	public const METHOD_SHARED     = 's';
	public const METHOD_TLS_SHARED = 'S';
	public const METHOD_TLS_CLIENT = 'T';
	public const METHOD_GSI_AUTH   = 'g';
	public const METHOD_GSI        = 'G';
	public const METHOD_KRB_AUTH   = 'k';
	public const METHOD_KRB        = 'K';

	private function enabled($a, $b) {
		return ($a === $b) ? "enable" : "disable";
	}

	protected function auth_conf() {
		$method = $this->method;
		$enable_s = $this->enabled($method, self::METHOD_SHARED);
		$enable_S = $this->enabled($method, self::METHOD_TLS_SHARED);
		$enable_T = $this->enabled($method, self::METHOD_TLS_CLIENT);
		$enable_g = $this->enabled($method, self::METHOD_GSI_AUTH);
		$enable_G = $this->enabled($method, self::METHOD_GSI);
		$enable_k = $this->enabled($method, self::METHOD_KRB_AUTH);
		$enable_K = $this->enabled($method, self::METHOD_KRB);

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
auth {$enable_s} sharedsecret *
{$delete_tls}auth {$enable_S} tls_sharedsecret *
{$delete_tls}auth {$enable_T} tls_client_certificate *
{$delete_gsi}auth {$enable_g} gsi_auth *
{$delete_gsi}auth {$enable_G} gsi *
{$delete_kerberos}auth {$enable_k} kerberos_auth *
{$delete_kerberos}auth {$enable_K} kerberos *

EOF;
		return $conf_str;
	}
}

class GfarmAuthGfarmSharedKey extends GfarmAuth {
	public const TYPE = "sharedsecret";

	public function __construct(Gfarm $gf) {
		$this->init($gf, self::TYPE);
		$this->secureconn_info_set('support_auth_tls', self::METHOD_TLS_SHARED, self::METHOD_SHARED);
	}

	private function gfarm_usermap() {
		if (!isset($this->usermap)) {
			$this->usermap = $this->gf->mountpoint . ".gfarm_usermap";
		}
		return $this->usermap;
	}

	private function gfarm_shared_key() {
		if (!isset($this->shared_key)) {
			$this->shared_key = $this->gf->mountpoint . ".gfarm_shared_key";
		}
		return $this->shared_key;
	}

	public function conf_init() {
		$conf_str = <<<EOF
shared_key_file   "{$this->gfarm_shared_key()}"
local_user_map    "{$this->gfarm_usermap()}"

EOF;
		$conf_str = $conf_str . $this->auth_conf();
		$gfarm_user = $this->gf->user;
		$local_user = self::LOCAL_USER;
		$usermap_str = <<<EOF
$gfarm_user $local_user

EOF;

		// overwrite
		if (! $this->file_put($this->gfarm_conf(), $conf_str)) {
			return false;
		}
		if (! $this->file_put($this->gfarm_usermap(), $usermap_str)) {
			return false;
		}
		if (! $this->file_put($this->gfarm_shared_key(), $this->gf->password . "\n")) {
			return false;
		}
		return true;
	}

	public function conf_ready() {
		return (file_exists($this->gfarm_conf())
				&& file_exists($this->gfarm_usermap())
				&& !file_exists($this->gfarm_shared_key()));
	}

	public function conf_clear() {
		unlink($this->gfarm_conf());
		unlink($this->gfarm_usermap());
		unlink($this->gfarm_shared_key());
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
	//public const MYPROXY_LOGON = "/nc-gfarm/dummy-myproxy-logon";
	public const MYPROXY_LOGON = "/nc-gfarm/myproxy-logon";

	public function __construct(Gfarm $gf) {
		$this->init($gf, self::TYPE);
		$this->secureconn_info_set('support_auth_gsi', self::METHOD_GSI, self::METHOD_GSI_AUTH);
	}

	public function conf_init() {
		$conf_str = $this->auth_conf();

		// overwrite
		return $this->file_put($this->gfarm_conf(), $conf_str);
	}

	public function conf_ready() {
		return (file_exists($this->gfarm_conf())
				&& file_exists($this->x509_proxy_cert()));
	}

	public function conf_clear() {
		unlink($this->gfarm_conf());
		unlink($this->x509_proxy_cert());
	}

	public function authenticated() {
		return $this->gf->gfarm_check_auth();
	}

	public function logon() {
		// myproxy-logon
		$user = $this->gf->user;
		$proxy = $this->x509_proxy_cert();
		$password = $this->gf->password;

		$command = self::MYPROXY_LOGON
				   . " " . escapeshellarg($user)
				   . " " . escapeshellarg($proxy);
		$this->gf->debug($command);

		$descriptorspec = array(
			0 => array("pipe", "r"),
			1 => array("pipe", "w"),
			2 => array("file", "/tmp/nextcloud-gfarm-debug.txt", "a") );

		$cwd = '/';
		$env = array();

		$process = proc_open($command, $descriptorspec, $pipes, $cwd, $env);

		$output = null;
		$retval = null;
		if (is_resource($process)) {
			fwrite($pipes[0], "$password\n");
			fclose($pipes[0]);
			$output = stream_get_contents($pipes[1]);
			fclose($pipes[1]);
			if (isset($pipes[2])) {
				fclose($pipes[2]);
			}

			$retval = proc_close($process);
			$this->gf->debug("retval=$retval");
		}
		if ($retval === 0) {
			$this->gf->debug("true");
			return true;
		} else {
			$this->gf->debug("false");
			return false;
		}
	}
}

// TODO GfarmAuthX509Proxy
	//$this->gf->arguments['private_key'];
	//$mp . ".x509_private_key";
