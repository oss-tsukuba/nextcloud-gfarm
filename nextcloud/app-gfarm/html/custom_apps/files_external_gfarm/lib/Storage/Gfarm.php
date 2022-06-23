<?php

namespace OCA\Files_external_gfarm\Storage;

use OC\Files\Storage\Flysystem;
use OC\Files\Storage\Flysystem\Common;
use OCP\Files\StorageAuthException;

class Gfarm extends \OC\Files\Storage\Local {
	//const APP_NAME = 'files_external_gfarm';

	const MYPROXY_LOGON = "/var/www/bin/dummy-myproxy-logon";
	const GRID_PROXY_INFO = "/var/www/bin/dummy-grid-proxy-info";
	const GFARM_MOUNT = "/var/www/bin/dummy-gfarm-mount";
	const GFARM_UMOUNT = "fusermount -u";
	const GFARM_MOUNTPOINT_POOL = "/tmp/gfarm/";

	private $debug_traceid = NULL;
	private $enable_debug = true;

	private function log_prefix() {
		return "[" . $this->debug_traceid . "](" . __CLASS__ . ": nextcloud user=" . $this->nextcloud_user . ". gfarm user=" . $this->user . ", gfarm path=" . $this->gfarm_path . ", mountpoint=" . $this->mountpoint . ", settings owner=" . $this->owner . ") ";
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

	public function __construct($arguments) {
		if ($this->enable_debug) {
			syslog(LOG_DEBUG, __CLASS__ . ": __construct()");
			syslog(LOG_DEBUG, "__construct: arguments: " . print_r($arguments, true));
		}

		if (!isset($arguments['gfarm_path'])
			|| !is_string($arguments['gfarm_path'])) {
			throw new \InvalidArgumentException('No data directory (Gfarm Path) set for gfarm storage');
		}
		if (!isset($arguments['user'])
			|| !is_string($arguments['user'])
			|| !isset($arguments['password'])
			|| !is_string($arguments['password'])) {
			throw new \InvalidArgumentException('No authentication info set for gfarm storage');
		}

		$this->debug_traceid = bin2hex(random_bytes(4));

		$this->gfarm_path = $arguments['gfarm_path'];
		$this->user = $arguments['user'];
		$password = $arguments['password'];

		$this->nextcloud_user = $this->getUser();
		$this->mountpoint = $this->mountpoint_init();

		$retval = $this->grid_proxy_info();
		if ($retval != 0) {
			$this->logon($password);
		}

		if (!$this->gfarm_mount()) {
			throw new StorageAuthException("mount failed: gfarm user=" . $this->user . ", gfarm path=" . $gfarm_path);
		}

		$this->debug("__construct() done");

		$arguments['datadir'] = $this->mountpoint;
		parent::__construct($arguments);
	}

	public function __destruct() {
		//$this->gfarm_umount();  //TODO umount in backgroud ?

		$this->debug("__destruct() done");
	}

	// override Local
	public function stat($path) {
		$this->debug("stat: " . $path);

		return parent::stat($path);
	}

	private function getUser() {
		//$user = get_current_user();
		//$user = $userSession->getUser();
		//$user = OC\User::getUser();
		//$user = OCP\User::checkLoggedIn();
		//$user = $this->userSession->getUser();
		//$user = $userSession->getUser()->getDisplayName();
		//$user = $this->userManager->get($status->getUserId());
		//$user = getDisplayName();
		$user = \OC_User::getUser();
		return $user;
	}

	private function mountpoint_init() {
		$gfarm_path = $this->gfarm_path;
		$user = $this->user;
		$length = 8;

		$hashed_path = substr(sha1($gfarm_path), 0, $length);
		$mountpoint = self::GFARM_MOUNTPOINT_POOL . "/" . $user . "/" . $hashed_path;
		return str_replace('//', '/', $mountpoint);
	}

	private function gfarm_mount() {
		$gfarm_path = $this->gfarm_path;
		$mountpoint = $this->mountpoint;

		$command = self::GFARM_MOUNT . " " . escapeshellarg($gfarm_path) . " " . escapeshellarg($mountpoint);
		$output = null;
		$retval = null;
		exec($command, $output, $retval);
//syslog(LOG_DEBUG, "command: [" . print_r($command, true) . "]");
//syslog(LOG_DEBUG, "output: [" . print_r($output, true) . "]");
//syslog(LOG_DEBUG, "retval: [" . print_r($retval, true) . "]");
		if ($retval == 0) {
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
		$gfarm_path = $this->gfarm_path;
		$mountpoint = $this->mountpoint;
		$user = $this->user;

		$command = self::MYPROXY_LOGON . " " . $mountpoint . " " . $user . " " . $gfarm_path;

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
		$gfarm_path = $this->gfarm_path;
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
