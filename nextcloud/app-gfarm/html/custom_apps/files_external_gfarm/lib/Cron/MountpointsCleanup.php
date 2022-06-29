<?php

declare(strict_types=1);

namespace OCA\Files_external_gfarm\Cron;

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
		$this->setInterval(60*60*24);
		//$this->setTimeSensitivity(IJob::TIME_INSENSITIVE);
	}

	protected function run($arguments) {
		$service = \OC::$server->getGlobalStoragesService();
		// OCA\Files_External\Lib\StorageConfig
		$configs = $service->getStorageForAllUsers();

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
			$config->setBackendOption('mount', 'false');
			$opts = $config->getBackendOptions();
			$storage = new Storage\Gfarm($opts);
			// TODO umount_if_recently_unused()
			$storage->gfarm_umount();
		}

		return true;
	}
}
