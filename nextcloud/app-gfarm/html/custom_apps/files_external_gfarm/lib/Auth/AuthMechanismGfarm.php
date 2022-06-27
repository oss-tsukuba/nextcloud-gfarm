<?php
namespace OCA\Files_external_gfarm\Auth;

use OCA\Files_External\Lib\Auth\AuthMechanism;
use OCA\Files_External\Lib\StorageConfig;
use OCP\IUser;

class AuthMechanismGfarm extends AuthMechanism {
	public const SCHEME_GFARM_SHARED_KEY = 'gfarm::shared_key';
	public const SCHEME_GFARM_MYPROXY = 'gfarm::myproxy';
	public const SCHEME_GFARM_X509_PROXY = 'gfarm::x509proxy';

	// StorageModifierTrait
	public function manipulateStorageConfig(StorageConfig &$storage, IUser $user = null) {
		$storage->setBackendOption('auth_scheme', $this->getScheme());

		if ($user === null) {
			$user_id = null;
		} else {
			$user_id = $user->getUID();
		}
		$storage->setBackendOption('storage_owner', $user_id);

		// StorageConfig::MOUNT_TYPE_*
		$storage->setBackendOption('mount_type', $storage->getType());

		$user = $storage->getBackendOption('user');
		if ($user === '__USER__') {
			$storage->setBackendOption('user', $user_id);
		}
	}
}
