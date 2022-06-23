<?php

namespace OCA\Files_external_gfarm\Backend;

use OCA\Files_External\Lib\Auth\AuthMechanism;
use OCA\Files_External\Lib\Auth\Password\Password;
use OCA\Files_External\Lib\DefinitionParameter;
use OCA\Files_External\Lib\LegacyDependencyCheckPolyfill;
use OCA\Files_External\Lib\Backend\Backend;
use OCP\IL10N;

// TODO GfarmMyProxy, setIdentifier('gfarm_myproxy')
class Gfarm extends Backend {

	public function __construct(IL10N $l, Password $legacyAuth) {
		//$user = \OC_User::getUser();

		$this
			->setIdentifier('gfarm')
			->addIdentifierAlias('OCA\Files_external_gfarm\Storage\Gfarm') // legacy compat
			->setStorageClass('OCA\Files_external_gfarm\Storage\Gfarm')
			->setText($l->t('Gfarm'))
			->addParameters([
				new DefinitionParameter('gfarm_path', $l->t('Gfarm sub directory')),
//				(new DefinitionParameter('user', $l->t('Username'))),
//				(new DefinitionParameter('password', $l->t('Password')))
//					->setType(DefinitionParameter::VALUE_PASSWORD),

			])
			->addAuthScheme(AuthMechanism::SCHEME_PASSWORD)
			->setLegacyAuthMechanism($legacyAuth)
		;
	}
}
