<?php

declare(strict_types=1);

namespace OCA\Files_external_gfarm\AppInfo;

use OCP\AppFramework\App;
use OCP\AppFramework\Bootstrap\IBootstrap;
use OCA\Files_External\Lib\Config\IAuthMechanismProvider;
use OCA\Files_External\Lib\Config\IBackendProvider;
use OCA\Files_External\Service\BackendService;
use OCA\Files_external_gfarm\Backend;
use OCA\Files_external_gfarm\Auth;

/**
 * @package OCA\Files_external_gfarm\AppInfo
 */
class Application extends App implements IBackendProvider, IAuthMechanismProvider
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
			$container->query(Backend\Gfarm::class),
		];
	}

	/**
	 * @{inheritdoc}
	 */
	public function getAuthMechanisms() {
		$container = $this->getContainer();

		return [
			$container->get(Auth\MyProxy::class),
			$container->get(Auth\X509ProxyCert::class),
			$container->get(Auth\GfarmSharedKey::class),
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
				$backendService->registerAuthMechanismProvider($this);
			}
		);
	}
}
