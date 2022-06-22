<?php

namespace OCA\Files_external_gfarm\Storage;

use OC\Files\Storage\Flysystem;
use OC\Files\Storage\Flysystem\Common;
//use OCA\Files_External\Lib\StorageConfig;
//TODO use OCP\Files\ForbiddenException;
use OCP\Files\StorageAuthException;

class Gfarm extends \OC\Files\Storage\Local {
	const APP_NAME = 'files_external_gfarm';
	const MYPROXY_LOGON = "/var/www/bin/dummy-myproxy-logon";
	const GRID_PROXY_INFO = "/var/www/bin/dummy-grid-proxy-info";
	const GFARM_MOUNT = "/var/www/bin/dummy-gfarm-mount";
	const GFARM_MOUNTPOINT_POOL = "/tmp/gfarm/";
	private $debug_traceid = NULL;

	public function __construct($arguments) {
syslog(LOG_DEBUG, "@@@ Storage.Gfarm.__construct");
syslog(LOG_DEBUG, "__construct: class(this): " . get_class($this));
//syslog(LOG_DEBUG, "__construct: arguments: " . gettype($arguments));
		$this->debug_traceid = bin2hex(random_bytes(8));
//syslog(LOG_DEBUG, "__construct: " . $this->debug_traceid);
//syslog(LOG_DEBUG, "__construct: storageId: " . print_r($this->storageId, true));
//syslog(LOG_DEBUG, "__construct: owner: " . gettype($this->owner));

//$storage_type = $storage->getType();
//		$is_personal = $storage->getType() === StorageConfig::MOUNT_TYPE_PERSONAl;
//syslog(LOG_DEBUG, "__construct: is_personal: " . print_r($is_personal, true));

//$backtrace = debug_backtrace(0, 0);
//foreach ($backtrace as $step) {
//	if (isset($step['class'], $step['function'], $step['args'][0])) {
//		$c = $step['class'];
//		$f = $step['function'];
//		$a = $step['args'];
//		//syslog(LOG_DEBUG, ">> " . print_r($c, true) . " " . print_r($f, true) . " " . gettype($a));
//		syslog(LOG_DEBUG, ">> " . print_r($c, true) . " " . print_r($f, true));
//	}
//	else {
//		syslog(LOG_DEBUG, ">> " . gettype($step) . "-");
//	}
//}

		if (!isset($arguments['gfarm_path']) || !is_string($arguments['gfarm_path'])) {
			throw new \InvalidArgumentException('No data directory (Gfarm Path) set for gfarm storage');
		}
		if (!isset($arguments['user']) || !is_string($arguments['user']) ||
		    !isset($arguments['password']) || !is_string($arguments['password'])) {
			throw new \InvalidArgumentException('No authentication info set for gfarm storage');
		}

		$gfarm_path = $arguments['gfarm_path'];
		$this->gfarm_user = $arguments['user'];
		$gfarm_password = $arguments['password'];

//syslog(LOG_DEBUG, "gfarm_path: [" . print_r($gfarm_path, true) . "]");
//syslog(LOG_DEBUG, "gfarm_user: [" . print_r($this->gfarm_user, true) . "]");
//syslog(LOG_DEBUG, "gfarm_password: [" . print_r($gfarm_password, true) . "]");

//		$nextcloud_user = $this->getUser();

		$this->mountpoint = $this->gfarm_mountpoint($gfarm_path, $this->gfarm_user);

		$datadir = str_replace('//', '/', $this->mountpoint);

//syslog(LOG_DEBUG, "datadir: [" . print_r($this->datadir, true) . "]");

		$retval = $this->grid_proxy_info($gfarm_path, $datadir, $this->gfarm_user);
//syslog(LOG_DEBUG, "stat: call parent::start()");
		if ($retval != 0) {
			$this->myproxy_logon($gfarm_path, $datadir, $this->gfarm_user, $gfarm_password);
		}

		$this->gfarm_mount($gfarm_path, $this->mountpoint);

//syslog(LOG_DEBUG, "__construct end");

		$arguments['datadir'] = $datadir;
		parent::__construct($arguments);
	}

	// override
	public function stat($path) {
syslog(LOG_DEBUG, "stat: " . $this->debug_traceid . " [" . $path . "]");

//TODO cache
		// if (!ret) {
		// 	throw new StorageAuthException("unauthorized: gfarm username=" . $this->gfarm_user);
		// }
		return parent::stat($path);
	}

//	private function stacktrace() {
//		$backtrace = debug_backtrace(0, 0);
//		foreach ($backtrace as $step) {
//			if (isset($step['class'], $step['function'])) {
//				$c = $step['class'];
//				$f = $step['function'];
//				syslog(LOG_DEBUG, ">> " . print_r($c, true) . " " . print_r($f, true));
//			}
//			else {
//				syslog(LOG_DEBUG, ">> " . gettype($step));
//			}
//		}
//	}

	private function getUser() {
		//$user = "004";

//syslog(LOG_DEBUG, "getUser: START [" . print_r($user, true) . "]");

		//$user = get_current_user();
		//$user = $userSession->getUser();
		//$user = OC\User::getUser();
		$user = \OC_User::getUser();
		//$user = OCP\User::checkLoggedIn();
		//$user = $this->userSession->getUser();
		//$user = $userSession->getUser()->getDisplayName();
		//$user = $this->userManager->get($status->getUserId());
		//$user = getDisplayName();

//syslog(LOG_DEBUG, "getUser: [" . print_r($user, true) . "]");
		return $user;
	}

	// TODO mountpoint()
	private function gfarm_mountpoint($gfarm_path, $gfarm_user) {
syslog(LOG_DEBUG, "gfarm_mountpoint: [" . $gfarm_path . "] [" . $gfarm_user . "]");
syslog(LOG_DEBUG, "gfarm_user: (" . gettype($gfarm_user) . ")");
syslog(LOG_DEBUG, "gfarm_user: [" . $gfarm_user . "]");
		$hashed_path = sha1($gfarm_path);
syslog(LOG_DEBUG, "hashed_path: (" . gettype($hashed_path) . ")");
syslog(LOG_DEBUG, "hashed_path: [" . $hashed_path . "]");
		$mountpoint = self::GFARM_MOUNTPOINT_POOL . "/" . $gfarm_user . "/" . $hashed_path;
		$mountpoint = str_replace('//', '/', $mountpoint);
syslog(LOG_DEBUG, "mountpoint: [" . $mountpoint . "]");

		return $mountpoint;
	}

	private function gfarm_mount($gfarm_path, $mountpoint) {
//syslog(LOG_DEBUG, "gfarm_mount: [" . $gfarm_path . "] [" . $mountpoint . "]");
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

	//TODO logon_switch
	private function myproxy_logon($gfarm_path, $mountpoint, $user, $password) {
//syslog(LOG_DEBUG, "myproxy_logon");
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

	// TODO authenticated()
	private function grid_proxy_info($gfarm_path, $mountpoint, $user) {
//syslog(LOG_DEBUG, "grid_proxy_info");
		$command = self::GRID_PROXY_INFO . " " . escapeshellarg($mountpoint);
		$output = null;
		$retval = null;
		exec($command, $output, $retval);
//syslog(LOG_DEBUG, "command: [" . print_r($command, true) . "]");
//syslog(LOG_DEBUG, "output: [" . print_r($output, true) . "]");
syslog(LOG_DEBUG, "retval: [" . print_r($retval, true) . "]");
		return $retval;
	}

}
