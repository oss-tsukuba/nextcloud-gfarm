<?php

namespace OCA\Files_external_gfarm\Backend;

use OCA\Files_External\Lib\Auth\AuthMechanism;
use OCA\Files_External\Lib\Auth\Password\Password;
use OCA\Files_External\Lib\DefinitionParameter;
use OCA\Files_External\Lib\LegacyDependencyCheckPolyfill;
use OCA\Files_External\Lib\Backend;
use OCP\IL10N;

class Gfarm extends Backend\Backend {

	public function __construct(IL10N $l, Password $legacyAuth) {
syslog(LOG_DEBUG, "@@@ Backend.Gfarm.__construct");
		$user = \OC_User::getUser();

//syslog(LOG_DEBUG, "__construct: user: " . print_r($user, true));
		$this
			->setIdentifier('gfarm')
			->addIdentifierAlias('OCA\Files_external_gfarm\Storage\Gfarm') // legacy compat
			->setStorageClass('OCA\Files_external_gfarm\Storage\Gfarm')
			->setText($l->t('Gfarm'))
			->addParameters([
				new DefinitionParameter('gfarm_path', $l->t('Gfarm Subfolder')),

//				(new DefinitionParameter('user', $l->t('Username'))),
//				(new DefinitionParameter('password', $l->t('Password')))
//					->setType(DefinitionParameter::VALUE_PASSWORD),

			])
			->addAuthScheme(AuthMechanism::SCHEME_PASSWORD)
			->setLegacyAuthMechanism($legacyAuth)
		;
	}
}
