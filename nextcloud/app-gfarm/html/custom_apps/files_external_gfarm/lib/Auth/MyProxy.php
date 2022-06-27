<?php
namespace OCA\Files_external_gfarm\Auth;

use OCA\Files_External\Lib\Auth\AuthMechanism;
use OCA\Files_External\Lib\DefinitionParameter;
use OCA\Files_External\Lib\StorageConfig;
use OCP\IUser;
use OCP\IL10N;

/**
 * for myproxy-logon
 */
class MyProxy extends AuthMechanismGfarm {
	public function __construct(IL10N $l) {
		$this
			->setIdentifier(self::SCHEME_GFARM_MYPROXY)
			->setScheme(self::SCHEME_GFARM_MYPROXY)
			->setText($l->t('myproxy-logon'))
			->addParameters(
				[
					(new DefinitionParameter('user', $l->t('Username')))
					->setTooltip($l->t('MyProxy username (__USER__ is equal to the name of this settings owner)')),

					(new DefinitionParameter('password', $l->t('Passphrase')))
					->setType(DefinitionParameter::VALUE_PASSWORD)
					->setTooltip($l->t('for myproxy-logon')),

					]);
	}

	// StorageModifierTrait
	public function manipulateStorageConfig(StorageConfig &$storage, IUser $user = null) {
		parent::manipulateStorageConfig($storage, $user);
	}
}
