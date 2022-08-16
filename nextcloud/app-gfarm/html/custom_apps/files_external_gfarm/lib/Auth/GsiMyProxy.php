<?php
declare(strict_types=1);

namespace OCA\Files_external_gfarm\Auth;

use OCA\Files_External\Lib\Auth\AuthMechanism;
use OCA\Files_External\Lib\DefinitionParameter;
use OCA\Files_External\Lib\StorageConfig;
use OCP\IUser;
use OCP\IL10N;

/**
 * for myproxy-logon
 */
class GsiMyProxy extends AuthMechanismGfarm {
	public function __construct(IL10N $l) {
		$this
			->setIdentifier(self::SCHEME_GFARM_GSI_MYPROXY)
			->setScheme(self::SCHEME_GFARM_GSI_MYPROXY)
			->setText($l->t('GSI:myproxy-logon'))
			->addParameters(
				[
					(new DefinitionParameter('user', $l->t('Username')))
					->setTooltip($l->t('MyProxy username')),

					(new DefinitionParameter('password', $l->t('Passphrase')))
					->setType(DefinitionParameter::VALUE_PASSWORD)
					->setTooltip($l->t('for myproxy-logon')),

					])
			->finish();  // AuthMechanismGfarm
	}

	// StorageModifierTrait
	// public function manipulateStorageConfig(StorageConfig &$storage, IUser $user = null) {
	// 	parent::manipulateStorageConfig($storage, $user);
	//}
}
