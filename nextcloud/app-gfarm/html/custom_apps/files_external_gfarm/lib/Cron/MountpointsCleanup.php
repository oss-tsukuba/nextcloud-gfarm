<?php

declare(strict_types=1);

namespace OCA\Files_external_gfarm\Cron;

use Exception;
use OCP\BackgroundJob\IJob;
use OCP\BackgroundJob\TimedJob;
use OCP\AppFramework\Utility\ITimeFactory;
use OCA\Files_external_gfarm\Backend;
use OCA\Files_external_gfarm\Storage;

class MountpointsCleanup extends TimedJob {

	public function __construct(ITimeFactory $time) {
		parent::__construct($time);

		// sec.
		//$this->setInterval(60);
		//$this->setInterval(60*60*24);
		$this->setInterval(1);  //TODO
		$this->setTimeSensitivity(IJob::TIME_INSENSITIVE);
	}

	private function is_subdir($dir, $subdir) {
		$len = mb_strlen($dir);
		return (mb_substr($subdir, 0, $len) === $dir);
	}

	private function get_mounted() {
		$command = "mount -t fuse.gfarm2fs | cut -d ' ' -f 3- | awk -F' type fuse' '{print $1}'";
		$output = null;
		$retval = null;
		exec($command, $lines, $retval);
		if ($retval === 0) {
			return $lines;
		} else {
			return null;
		}
	}

	protected function run($arguments) {
		syslog(LOG_INFO, "MountpointsCleanup(for Gfarm) start");
		$service = \OC::$server->getGlobalStoragesService();
		// OCA\Files_External\Lib\StorageConfig
		$configs = $service->getStorageForAllUsers();

		$mountpoint_list = array();

		foreach ($configs as $config) {
			// OCA\Files_External\Lib\Backend\Backend
			$back = $config->getBackend()->jsonSerialize();
			if ($back['identifier'] !== Backend\Gfarm::ID) {
				continue;
			}
			//syslog(LOG_DEBUG, "backend=" . print_r($back, true));

			// OCA\Files_External\Lib\Auth\AuthMechanism;
			$auth = $config->getAuthMechanism();
			$auth->manipulateStorageConfig($config);
			$config->setBackendOption('mount', false); // initialize only
			$opts = $config->getBackendOptions();
			$storage = null;
			try {
				$storage = new Storage\Gfarm($opts);
			} catch (Exception $e) {
				// next entry
				continue;
			}

			// TODO
			// if ($this->umount_if_recently_unused()) {
			//   continue;
			// }

			$mountpoint_list[] = realpath($storage->mountpoint);
			syslog(LOG_DEBUG, "mountpoint from setting: " . $storage->mountpoint);
		}

		// umount unknown mountpoints
		$pool = realpath(Storage\Gfarm::GFARM_MOUNTPOINT_POOL);
		$mounted_list = $this->get_mounted();
		foreach ($mounted_list as $mounted) {
			syslog(LOG_DEBUG, "mountpoint from mount command: " . $mounted);
			if ($this->is_subdir($pool, $mounted)
				&& ! in_array($mounted, $mountpoint_list, true)) {
				// umount unknown mp (removed or changed from settings)
				try {
					Storage\Gfarm::umount_static($mounted);
					syslog(LOG_INFO, "auto umount: " . $mounted);
				} catch (Exception $e) {
					// ignore
				}
			}
		}
		return true;
	}
}
