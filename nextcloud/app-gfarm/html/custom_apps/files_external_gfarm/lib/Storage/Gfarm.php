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
		return "[" . $this->debug_traceid . "](" . __CLASS__ . ": access nextcloud_user=" . $this->nextcloud_user . ". gfarm_user=" . $this->user . ", gfarm_dir=" . $this->gfarm_dir . ", mountpoint=" . $this->mountpoint . ", storage_owner=" . $this->storage_owner . ", auth_scheme=" . $this->auth_scheme . ") ";
	}

	private function debug($message) {
		if ($this->enable_debug) {
			syslog(LOG_DEBUG, $this->log_prefix() . $message);
		}
	}

	private function error($message) {
			syslog(LOG_ERR, $this->log_prefix() . $message);
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
			throw new \InvalidArgumentException('no storage owner username');
		}
		if (! self::is_valid_param($arguments['user'])) {
			throw new \InvalidArgumentException('no Gfarm username');
		}
		if (! self::is_valid_param($arguments['gfarm_dir'])) {
			throw new \InvalidArgumentException('no Gfarm directory');
		}
		if (! self::is_valid_param($arguments['password'])) {
			throw new \InvalidArgumentException('no password for gfarm storage');
		}

		$this->debug_traceid = bin2hex(random_bytes(4));

		$this->storage_owner = $arguments['storage_owner'];
		$this->user = $arguments['user']; // Gfarm username
		$this->gfarm_dir = $arguments['gfarm_dir'];
		$password = $arguments['password'];

		$this->auth_scheme = $arguments['auth_scheme'];

		$this->nextcloud_user = $this->getAccessUser();
		$this->mountpoint = $this->mountpoint_init();

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
			$msg = "unknown auth_scheme";
			$this->error($msg);
			throw new StorageAuthException($msg . ": auth_scheme=" . $this->auth_scheme);
		}

		$remount = false;
		if (! $this->auth->conf_ready()) {
			$this->auth->conf_init();
		}
		if (! $this->auth->authenticated()) {
			$this->auth->conf_init(); // reset
			$this->auth->logon($password);
			$remount = true;
			if (! $this->auth->authenticated()) {
				throw new StorageAuthException("authentication failed: gfarm_user=" . $this->user . ", gfarm_dir=" . $this->gfarm_dir);
			}
		}

		$mount = $arguments['mount'];
		//if (empty($mount) || !is_bool($mount)) { // default
		if($mount !== "false") {
			$mount = "true";
		}  // "false" condition to umount
		if ($mount === "true" && !$this->gfarm_mount($remount)) {
			throw new StorageAuthException("mount failed: gfarm_user=" . $this->user . ", gfarm_dir=" . $this->gfarm_dir);
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
		return str_replace('//', '/', $mountpoint);
	}

	private function gfarm_mount($remount) {
		$gfarm_dir = $this->gfarm_dir;
		$mountpoint = $this->mountpoint;
		$remount_opt = $remount ? "REMOUNT=1" : "REMOUNT=0";

		$command = self::GFARM_MOUNT . " " . $remount_opt . " " .escapeshellarg($gfarm_dir) . " " . escapeshellarg($mountpoint);
		$output = null;
		$retval = null;
		exec($command, $output, $retval);
//syslog(LOG_DEBUG, "command: [" . print_r($command, true) . "]");
//syslog(LOG_DEBUG, "output: [" . print_r($output, true) . "]");
//syslog(LOG_DEBUG, "retval: [" . print_r($retval, true) . "]");
		if ($retval === 0) {
			return true;
		} else {
			return false;
		}
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
	}

	private function logon($password) {
		return $this->myproxy_logon($password);
	}

	private function myproxy_logon($password) {
		$gfarm_dir = $this->gfarm_dir;
		$mountpoint = $this->mountpoint;
		$user = $this->user;

		$command = self::MYPROXY_LOGON . " " . $mountpoint . " " . $user . " " . $gfarm_dir;

		$descriptorspec = array(
			0 => array("pipe", "r"),
			1 => array("pipe", "w"),
			2 => array("pipe", "w") );

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
			fclose($pipes[2]);

			$retval = proc_close($process);
		}
//syslog(LOG_DEBUG, "command: [" . print_r($command, true) . "]");
//syslog(LOG_DEBUG, "output: [" . print_r($output, true) . "]");
//syslog(LOG_DEBUG, "retval: [" . print_r($retval, true) . "]");
	}

	private function grid_proxy_info() {
		$gfarm_dir = $this->gfarm_dir;
		$mountpoint = $this->mountpoint;
		$user = $this->user;

		$command = self::GRID_PROXY_INFO . " " . escapeshellarg($mountpoint);
		$output = null;
		$retval = null;
		exec($command, $output, $retval);
//syslog(LOG_DEBUG, "command: [" . print_r($command, true) . "]");
//syslog(LOG_DEBUG, "output: [" . print_r($output, true) . "]");
//syslog(LOG_DEBUG, "retval: [" . print_r($retval, true) . "]");
		return $retval;
	}

}

abstract class GfarmAuth {

	public function __construct(Gfarm $gf) {
		$this->gf = $gf;
	}

	abstract public function conf_init();
	abstract public function conf_ready();
	abstract public function authenticated();
	abstract public function login();
}

class GfarmAuthGfarmSharedKey extends GfarmAuth {

	public function __construct(Gfarm $gf) {
		parent::__construct($gf);

		$mp = $this->gf->mountpoint;
		$this->gfarm_conf =  $mp . ".gfarm2.conf";
		$this->gfarm_usermap = $mp . ".gfarm_usermap";
		$this->gfarm_shared_key = $mp . ".gfarm_shared_key";

		//$this->private_key_str = $this->gf->arguments['private_key'];
		//$this->x509_proxy_cert = $mp . ".x509_proxy_cert";
		//$this->gx509_private_key = $mp . ".x509_private_key";
	}

	public function conf_init() {
		//file_put_contents
		return true;
	}

	public function conf_ready() {
		return (file_exists($this->gfarm_conf)
				&& file_exists($this->gfarm_usermap)
				&& !file_exists($this->gfarm_shared_key));
	}

	public function authenticated() {
		return true;
		//$command = self::GFKEY . " -e";
		//putenv("GFARM_CONFIG_FILE=" . );
	}

	public function login() {
		return true;
	}
}
