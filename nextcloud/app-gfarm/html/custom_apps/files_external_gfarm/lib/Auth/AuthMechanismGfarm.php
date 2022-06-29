<?php
declare(strict_types=1);

namespace OCA\Files_external_gfarm\Auth;

use OCA\Files_External\Lib\Auth\AuthMechanism;
use OCA\Files_External\Lib\StorageConfig;
use OCP\IUser;

class AuthMechanismGfarm extends AuthMechanism {
	public const SCHEME_GFARM_SHARED_KEY = 'gfarm::shared_key';
	public const SCHEME_GFARM_MYPROXY = 'gfarm::myproxy';
	public const SCHEME_GFARM_X509_PROXY = 'gfarm::x509proxy';

	public const ADMIN_NAME = "__ADMIN__";

	// StorageModifierTrait
	public function manipulateStorageConfig(StorageConfig &$storage, IUser $iuser = null) {
		// access (session) $user is not used

		$storage->setBackendOption('auth_scheme', $this->getScheme());

		$type = $storage->getType();
		// StorageConfig::MOUNT_TYPE_*
		$storage->setBackendOption('mount_type', $type);

		$owner = self::ADMIN_NAME;
		if ($type === StorageConfig::MOUNT_TYPE_PERSONAl) {
			$values = $storage->getApplicableUsers();
			if (count($values) > 0) {
				$owner = $values[0];
			} else {
				throw new \UnexpectedValueException(
					'no owner of StorageConfig::MOUNT_TYPE_PERSONAl');
			}
			if ($owner === self::ADMIN_NAME) {
				throw new \UnexpectedValueException(
					'invalid owner of StorageConfig::MOUNT_TYPE_PERSONAl');
			}
		}
		$storage->setBackendOption('storage_owner', $owner);

		$username = $storage->getBackendOption('user');
		if ($username === '__USER__') {
			$storage->setBackendOption('user', $owner);
		}
	}
}
