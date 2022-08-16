<?php
declare(strict_types=1);

namespace OCA\Files_external_gfarm\Auth;

use OCA\Files_External\Lib\Auth\AuthMechanism;
use OCA\Files_External\Lib\DefinitionParameter;
use OCA\Files_External\Lib\StorageConfig;
use OCP\IUser;

class AuthMechanismGfarm extends AuthMechanism {
	// NOTE: cannot be changed later
	public const SCHEME_GFARM_SHARED_KEY = 'gfarm_shared_key';
	public const SCHEME_GFARM_GSI_MYPROXY = 'gfarm_gsi_myproxy';
	public const SCHEME_GFARM_GSI_X509_PROXY = 'gfarm_gsi_x509proxy';
	//public const SCHEME_GFARM_GSI_X509_PRIV_KEY = 'gfarm_gsi_x509privkey';

	public const SCHEME_KEY_PREFIX = 'scheme_';

	public const ADMIN_NAME = "__ADMIN__";

	private static function has_scheme($args, $scheme) {
		return isset($args[self::SCHEME_KEY_PREFIX . $scheme]);
	}

	public static function get_scheme($args) {
		if (self::has_scheme($args, self::SCHEME_GFARM_SHARED_KEY)) {
			return self::SCHEME_GFARM_SHARED_KEY;
		} elseif (self::has_scheme($args, self::SCHEME_GFARM_GSI_MYPROXY)) {
			return self::SCHEME_GFARM_GSI_MYPROXY;
		} elseif (self::has_scheme($args, self::SCHEME_GFARM_GSI_X509_PROXY)) {
			return self::SCHEME_GFARM_GSI_X509_PROXY;
		}
		return null;
	}

	protected function finish() {
		// to recognize AuthMechanism scheme type (value is not used)
		$scheme = $this->getScheme();
		$this->addParameter(
			(new DefinitionParameter('scheme_' . $scheme, 'scheme'))
			->setType(DefinitionParameter::VALUE_HIDDEN)
			->setFlag(DefinitionParameter::FLAG_OPTIONAL)
			);
		// NOTE: effective for all after FLAG_OPTIONAL
	}

	// StorageModifierTrait
	// public function wrapStorage(Storage $storage) {
	// }

	// StorageModifierTrait
	public function manipulateStorageConfig(StorageConfig &$storage, IUser $iuser = null) {
		// $iuser (session user) is not used

		$storage->setBackendOption('manipulated', true);

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

	}
}
