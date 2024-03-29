<?php
declare(strict_types=1);

namespace OCA\Files_external_gfarm\Auth;

use OCA\Files_External\Lib\Auth\AuthMechanism;
use OCA\Files_External\Lib\DefinitionParameter;
use OCA\Files_External\Lib\StorageConfig;
use OCP\IUser;
use OCP\IL10N;

/**
 * for .gfarm_shared_key
 */
class GfarmSharedKey extends AuthMechanismGfarm {
	public function __construct(IL10N $l) {
		$this
			->setIdentifier(self::SCHEME_GFARM_SHARED_KEY)
			->setScheme(self::SCHEME_GFARM_SHARED_KEY)
			->setText($l->t('Gfarm shared key'))
			->addParameters(
				[
					(new DefinitionParameter('user', $l->t('Username')))
					->setTooltip($l->t('Gfarm username')),

					(new DefinitionParameter('password', $l->t('Shared key string')))
					->setType(DefinitionParameter::VALUE_PASSWORD)
					->setTooltip($l->t('"gfkey -l" or "cat ~/.gfarm_shared_key"')),

					])
			->finish();  // AuthMechanismGfarm
	}

	// StorageModifierTrait
	// public function manipulateStorageConfig(StorageConfig &$storage, IUser $user = null) {
	// 	parent::manipulateStorageConfig($storage, $user);
	//}
}
