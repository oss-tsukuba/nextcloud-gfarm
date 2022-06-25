<?php

declare(strict_types=1);

namespace OCA\Files_external_gfarm\AppInfo;

use OCP\AppFramework\App;
use OCP\AppFramework\Bootstrap\IBootstrap;
use OCA\Files_External\Lib\Config\IBackendProvider;
use OCA\Files_External\Service\BackendService;
use OCA\Files_external_gfarm\Backend\GfarmSharedKey;
use OCA\Files_external_gfarm\Backend\GfarmMyProxy;
use OCA\Files_external_gfarm\Backend\GfarmGridProxy;

/**
 * @package OCA\Files_external_gfarm\AppInfo
 */
class Application extends App implements IBackendProvider
{

	public function __construct(array $urlParams = array())
	{
		parent::__construct('files_external_gfarm', $urlParams);
	}

	/**
	 * @{inheritdoc}
	 */
	public function getBackends()
	{
		$container = $this->getContainer();
		return [
			$container->query(GfarmSharedKey::class),
			$container->query(GfarmMyProxy::class),
			$container->query(GfarmGridProxy::class),
		];
	}

	public function register()
	{
		$container = $this->getContainer();
		$server = $container->getServer();

		\OC::$server->getEventDispatcher()->addListener(
			'OCA\\Files_External::loadAdditionalBackends',
			function() use ($server) {
				$backendService = $server->query(BackendService::class);
				$backendService->registerBackendProvider($this);
			}
		);
	}
}
