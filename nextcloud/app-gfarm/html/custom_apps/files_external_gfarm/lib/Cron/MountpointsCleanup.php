<?php

declare(strict_types=1);

namespace OCA\Files_external_gfarm\Cron;

use Exception;
use OCP\BackgroundJob\IJob;
use OCP\BackgroundJob\TimedJob;
use OCP\AppFramework\Utility\ITimeFactory;
use OCP\IConfig;

use OCA\Files_external_gfarm\Backend;
use OCA\Files_external_gfarm\Storage;

// clean unused mountpoints
class MountpointsCleanup extends TimedJob {

	public function __construct(ITimeFactory $time) {
		parent::__construct($time);
		$this->config = \OC::$server->get(IConfig::class);
		$this->enable_debug = $this->config->getSystemValue('debug', false);

		// sec.
		$this->setInterval(60);
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

	private function debug($msg) {
		if ($this->enable_debug) {
			syslog(LOG_DEBUG, $msg);
		}
	}

	private function info($msg) {
		syslog(LOG_INFO, $msg);
	}

	private function error($msg) {
		syslog(LOG_ERR, $msg);
	}

	protected function run($arguments) {
		$this->debug("MountpointsCleanup(for Gfarm) start");
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
			//$this->debug("backend=" . print_r($back, true));

			// OCA\Files_External\Lib\Auth\AuthMechanism;
			$auth = $config->getAuthMechanism();
			$auth->manipulateStorageConfig($config);
			$config->setBackendOption('mount', false); // initialize only
			$opts = $config->getBackendOptions();
			$storage = null;
			try {
				$storage = new Storage\Gfarm($opts);
			} catch (Exception $e) {
				$this->debug($e->__toString());
				// next entry
				continue;
			} catch (Error $e) {
				$this->debug($e->__toString());
				// next entry
				continue;
			}

			try {
				$mountpoint = realpath($storage->mountpoint);
				if (! $mountpoint) {
					$mountpoint = $storage->mountpoint;
				}
			} catch (Exception $e) {
				$mountpoint = $storage->mountpoint;
			} catch (Error $e) {
				$mountpoint = $storage->mountpoint;
			}
			$mountpoint_list[] = $mountpoint;
			$this->debug("mountpoint from DB: " . $mountpoint);
		}

		// umount
		$pool = realpath(Storage\Gfarm::GFARM_MOUNTPOINT_POOL);
		$mounted_list = $this->get_mounted();
		foreach ($mounted_list as $mounted) {
			$this->debug("mountpoint from mount command: " . $mounted);
			if ($this->is_subdir($pool, $mounted)
				&& ! in_array($mounted, $mountpoint_list, true)) {
				// umount unknown mp (removed or changed from settings)
				try {
					Storage\Gfarm::umount_static($this, $mounted);
					$this->info("auto umount: " . $mounted);
				} catch (Exception $e) {
					// ignore
				} catch (Error $e) {
					// ignore
				}
			}
		}
		return true;
	}
}
