<?php

// app.php (deprecated)

declare(strict_types=1);

namespace OCA\Files_external_gfarm\AppInfo;

$app = \OC::$server->query(Application::class);
$app->register0();
