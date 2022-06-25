<?php

namespace OCA\Files_external_gfarm\Backend;

use OCP\IL10N;

class GfarmMyProxy extends GfarmBackend {

	protected function init(IL10N $l) {
		$this->identifier = 'gfarm_myproxy';
		$this->text = $l->t('Gfarm X.509 MyProxy');
	}
}
