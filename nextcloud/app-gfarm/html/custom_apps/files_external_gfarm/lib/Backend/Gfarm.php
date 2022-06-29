<?php
declare(strict_types=1);

namespace OCA\Files_external_gfarm\Backend;

use OCA\Files_External\Lib\Auth\Password\Password;
use OCA\Files_External\Lib\DefinitionParameter;
use OCA\Files_External\Lib\LegacyDependencyCheckPolyfill;
use OCA\Files_External\Lib\Backend\Backend;
use OCP\IL10N;
use OCA\Files_external_gfarm\Auth\AuthMechanismGfarm;

class BackendGfarm extends Backend {

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
			->addAuthScheme(AuthMechanismGfarm::SCHEME_GFARM_SHARED_KEY)
			->addAuthScheme(AuthMechanismGfarm::SCHEME_GFARM_MYPROXY)
			->addAuthScheme(AuthMechanismGfarm::SCHEME_GFARM_X509_PROXY)
			->setLegacyAuthMechanism($legacyAuth)
		;
	}
}

class Gfarm extends BackendGfarm {

	public const ID = 'gfarm';

	protected function init(IL10N $l) {
		$this->identifier = self::ID;
		$this->text = $l->t('Gfarm');
	}
}
