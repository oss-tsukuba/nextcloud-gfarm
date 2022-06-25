<?php

namespace OCA\Files_external_gfarm\Backend;

use OCP\IL10N;

class GfarmSharedKey extends GfarmBackend {

	protected function init(IL10N $l) {
		$this->identifier = 'gfarm_shared_key';
		$this->text = $l->t('Gfarm shared key');
	}
}
