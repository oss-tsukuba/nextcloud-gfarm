<?php
declare(strict_types=1);

namespace OCA\Files_external_gfarm\Auth;

use OCA\Files_External\Lib\Auth\AuthMechanism;
use OCA\Files_External\Lib\DefinitionParameter;
use OCA\Files_External\Lib\StorageConfig;
use OCP\IUser;
use OCP\IL10N;

/**
 * for XOAUTH2 with jwt-agent
 */
class XOAuth2JWTAgent extends AuthMechanismGfarm {
	public function __construct(IL10N $l) {
		$this
			->setIdentifier(self::SCHEME_GFARM_XOAUTH2_JWTAGENT)
			->setScheme(self::SCHEME_GFARM_XOAUTH2_JWTAGENT)
			->setText($l->t('XOAUTH2:jwt-agent (DO NOT USE)'))
			->addParameters(
				[
					(new DefinitionParameter('user', $l->t('Username')))
					->setTooltip($l->t('Username for OpenID provider and jwt-server')),

					(new DefinitionParameter('password', $l->t('Passphrase')))
					->setType(DefinitionParameter::VALUE_PASSWORD)
					->setTooltip($l->t('Passphrase from jwt-server')),

					(new DefinitionParameter('url', $l->t('URL')))
					->setTooltip($l->t('URL of jwt-server')),

					])
			->finish();  // AuthMechanismGfarm
	}

	// StorageModifierTrait
	// public function manipulateStorageConfig(StorageConfig &$storage, IUser $user = null) {
	// 	parent::manipulateStorageConfig($storage, $user);
	//}
}
