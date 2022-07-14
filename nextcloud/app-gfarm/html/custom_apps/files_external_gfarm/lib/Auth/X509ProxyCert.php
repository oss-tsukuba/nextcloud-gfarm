<?php
declare(strict_types=1);

namespace OCA\Files_external_gfarm\Auth;

use OCA\Files_External\Lib\Auth\AuthMechanism;
use OCA\Files_External\Lib\DefinitionParameter;
use OCA\Files_External\Lib\StorageConfig;
use OCP\IUser;
use OCP\IL10N;

/**
 * for grid-proxy-init
 */
class X509ProxyCert extends AuthMechanismGfarm {
	public function __construct(IL10N $l) {
		$this
			->setIdentifier(self::SCHEME_GFARM_X509_PROXY)
			->setScheme(self::SCHEME_GFARM_X509_PROXY)
			->setText($l->t('grid-proxy-init'))
			->addParameters(
				[
					(new DefinitionParameter('password', $l->t('Passphrase')))
					->setType(DefinitionParameter::VALUE_PASSWORD)
					->setTooltip($l->t('for grid-proxy-init')),

					(new DefinitionParameter('private_key', $l->t('Private key')))
					->setType(DefinitionParameter::VALUE_TEXT)
					->setTooltip($l->t('X.509 PEM string for grid-proxy-init')),

					(new DefinitionParameter('user', 'user'))
					->setType(DefinitionParameter::VALUE_HIDDEN)
					->setFlag(DefinitionParameter::FLAG_OPTIONAL)
					])
			->finish();  // AuthMechanismGfarm
	}

	// StorageModifierTrait
	// public function manipulateStorageConfig(StorageConfig &$storage, IUser $user = null) {
	// 	parent::manipulateStorageConfig($storage, $user);

	// 	// TODO unnecessary
	// 	// use hash of private key as username
	// 	$private_key = $storage->getBackendOption('private_key');
	// 	$private_key_hash = substr(sha1($private_key), 0, 8);
	// 	$storage->setBackendOption('user', $private_key_hash);
	// }
}
