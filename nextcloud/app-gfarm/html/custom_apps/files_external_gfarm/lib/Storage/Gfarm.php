<?php

namespace OCA\Files_external_gfarm\Storage;

use OC\Files\Storage\Flysystem;
use OC\Files\Storage\Flysystem\Common;
use OCP\Files\StorageAuthException;
use OCA\Files_External\Lib\StorageConfig;

class Gfarm extends \OC\Files\Storage\Local {
	//const APP_NAME = 'files_external_gfarm';

	const MYPROXY_LOGON = "/nc-gfarm/app-gfarm/bin/dummy-myproxy-logon";
	const GRID_PROXY_INFO = "/nc-gfarm/app-gfarm/bin/dummy-grid-proxy-info";
	const GFARM_MOUNT = "/nc-gfarm/app-gfarm/bin/gfarm-mount";
	const GFARM_UMOUNT = "fusermount -u";

	//const GFARM_MOUNTPOINT_POOL = "/tmp/gfarm/";
	const GFARM_MOUNTPOINT_POOL = "/dev/shm/gf/";

	const MOUNT_TYPE_ADMIN_DIR_NAME = "__ADMIN__";

	private $debug_traceid = NULL;
	private $enable_debug = true;

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
			syslog(LOG_DEBUG, __CLASS__ . ": __construct()");
			syslog(LOG_DEBUG, "__construct: arguments: " . print_r($arguments, true));
		}

		if (! self::is_valid_param($arguments['gfarm_dir'])) {
			throw new \InvalidArgumentException('Empty Gfarm directory');
		}
		if (! self::is_valid_param($arguments['password'])) {
			throw new \InvalidArgumentException('Empty password for gfarm storage');
		}

		if (self::is_valid_param($arguments['storage_owner'])) {
			if ($arguments['mount_type'] === StorageConfig::MOUNT_TYPE_ADMIN) {
				$this->storage_owner = self::MOUNT_TYPE_ADMIN_DIR_NAME;
			} else {
				// from Personal External storage settings
				$this->storage_owner = $arguments['storage_owner'];
			}
		} else {
			// from Administration External storage settings
			$this->storage_owner = self::MOUNT_TYPE_ADMIN_DIR_NAME;
		}

		// Gfarm username
		if (self::is_valid_param($arguments['user'])) {
			$this->user = $arguments['user'];
		} else {
			$this->user = $this->storage_owner;
		}

		$this->debug_traceid = bin2hex(random_bytes(4));

		$this->gfarm_dir = $arguments['gfarm_dir'];
		$password = $arguments['password'];
		$this->private_key = $arguments['private_key'];

		$this->auth_scheme = $arguments['auth_scheme'];

		$this->nextcloud_user = $this->getAccessUser();
		$this->mountpoint = $this->mountpoint_init();

		$this->debug("all parameters initialized");

		// ----------------------------------------

		$remount = false;
		if (! $this->authenticated()) {
			$this->logon($password);
			$remount = true;
		}

		if (!$this->gfarm_mount($remount)) {
			throw new StorageAuthException("mount failed: gfarm user=" . $this->user . ", gfarm path=" . $this->gfarm_dir);
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

	private function gfarm_umount() {
		$command = self::GFARM_UMOUNT . " " . escapeshellarg($this->mountpoint);
		$output = null;
		$retval = null;
		exec($command, $output, $retval);
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

	private function authenticated() {
		return $this->grid_proxy_info();
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
