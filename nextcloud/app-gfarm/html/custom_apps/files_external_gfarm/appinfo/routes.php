<?php

if (\OC::$server->getAppManager()->isEnabledForUser('files_external')) {
	$application = new \OCA\Files_external_gfarm\AppInfo\Application();
}
