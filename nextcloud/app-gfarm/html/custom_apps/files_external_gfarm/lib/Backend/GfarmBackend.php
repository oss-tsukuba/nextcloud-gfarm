<?php

namespace OCA\Files_external_gfarm\Backend;

use OCA\Files_External\Lib\Auth\AuthMechanism;
use OCA\Files_External\Lib\Auth\Password\Password;
use OCA\Files_External\Lib\DefinitionParameter;
use OCA\Files_External\Lib\LegacyDependencyCheckPolyfill;
use OCA\Files_External\Lib\Backend\Backend;
use OCP\IL10N;

class GfarmBackend extends Backend {

	public function __construct(IL10N $l, Password $legacyAuth) {
		$storage_class = 'OCA\Files_external_gfarm\Storage\Gfarm';
		$this->init($l);
		return $this
			->setIdentifier($this->identifier)
			->addIdentifierAlias($storage_class) // legacy compat
			->setStorageClass($storage_class)
			->setText($this->text)
			->addParameters([
				new DefinitionParameter('gfarm_dir',
										$l->t('Gfarm directory')),
			])
			->addAuthScheme(AuthMechanism::SCHEME_PASSWORD)
			->setLegacyAuthMechanism($legacyAuth)
		;
	}
}
