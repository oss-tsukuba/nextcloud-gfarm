COMPOSE_PROJECT_NAME = nextcloud-gfarm

ENV_FILE = --env-file config.env

SUDO = $(shell docker version > /dev/null 2>&1 || echo sudo)
DOCKER = $(SUDO) docker
COMPOSE_V1 = docker-compose
COMPOSE_V2 = docker compose
COMPOSE_SW = $(shell ${COMPOSE_V2} version > /dev/null 2>&1 && echo ${COMPOSE_V2} || echo ${COMPOSE_V1})
COMPOSE = $(SUDO) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) $(COMPOSE_SW) $(ENV_FILE)

EXEC_COMMON_USER = $(COMPOSE) exec -u www-data
EXEC_COMMON_ROOT = $(COMPOSE) exec -u root

EXEC = $(EXEC_COMMON_USER) nextcloud
EXEC_ROOT = $(EXEC_COMMON_ROOT) nextcloud

OCC = $(EXEC) php /var/www/html/occ
SHELL=/bin/bash

# use selfsigned certificate
SSC_COMPOSE = $(COMPOSE) -f docker-compose.selfsigned.yml

CONTAINERS = nextcloud mariadb redis revproxy

.PONY =

define gentarget
       $(foreach name,$(CONTAINERS),$(1)@$(name))
endef

TARGET_LOGS = $(call gentarget,logs)
.PONY += $(TARGET_LOGS)

TARGET_LOGS_FOLLOW = $(call gentarget,logs-follow)
.PONY += $(TARGET_LOGS_FOLLOW)

TARGET_LOGS_TIME = $(call gentarget,logs-time)
.PONY += $(TARGET_LOGS_TIME)

TARGET_SHELL = $(call gentarget,shell)
.PONY += $(TARGET_SHELL)

define yesno
	@read -p "$1 (y/N): " YN; \
	case "$$YN" in [yY]*) true;; \
	*) echo "Aborted ($${YN})"; false;; \
	esac
endef

ps:
	$(COMPOSE) ps

init:
	./init.sh template.env

init-hpci:
	./init.sh template-hpci.env

init-dev:
	./init.sh template-docker_dev.env

prune:
	$(DOCKER) system prune -f

selfsigned-cert-generate:
	$(SSC_COMPOSE) up
	$(SSC_COMPOSE) down

selfsigned-cert-ps:
	$(SSC_COMPOSE) ps

selfsigned-cert-check-config:
	$(SSC_COMPOSE) config

selfsigned-cert-fingerprint:
	$(EXEC_COMMON_ROOT) revproxy /cert-fingerprint.sh

check-config:
	$(COMPOSE) config

down:
	$(COMPOSE) down --remove-orphans
	$(MAKE) prune

volume-list:
#	@$(COMPOSE) config --volumes
	@$(DOCKER) volume ls -q | grep $(COMPOSE_PROJECT_NAME)_

volume-list-2:
	@ $(COMPOSE) ps -q \
	 | xargs docker container inspect \
		-f '{{ range .Mounts }}{{ .Name }} {{ end }}' \
	 | xargs -n 1 echo

service-list:
	@$(COMPOSE) config --services

_REMOVE_ALL_FOR_DEVELOP:
	$(MAKE) down-REMOVE_VOLUMES || true
	BACKUP_CONF=config.env.`date +%Y%m%d`; [ -f $$BACKUP_CONF ] || cp config.env || true
	rm -f ./secrets/db_password
	rm -f ./docker-compose.override.yml ./config.env

_REINSTAL_FOR_DEVELOP:
	$(MAKE) _REMOVE_ALL_FOR_DEVELOP
	$(MAKE) init-dev
	$(MAKE) selfsigned-cert-generate
	$(MAKE) reborn-withlog

down-REMOVE_VOLUMES_FORCE:
	$(COMPOSE) down --volumes --remove-orphans

down-REMOVE_VOLUMES:
	$(call yesno,ERASE ALL LOCAL DATA. Do you have a backup?)
	$(MAKE) down-REMOVE_VOLUMES_FORCE

COMMIT_HASH := nextcloud/commit_hash.sh
commit_hash:
	echo -n "NEXTCLOUD_GFARM_COMMIT_HASH=" > $(COMMIT_HASH)
	git rev-parse HEAD >> $(COMMIT_HASH) || true

reborn-nowait:
	$(MAKE) build
	$(MAKE) down
	$(COMPOSE) up -d || { $(MAKE) logs; false; }
	$(MAKE) auth-init || { $(MAKE) logs; false; }

reborn:
	$(MAKE) reborn-nowait
	./wait.sh

reborn-withlog:
	$(MAKE) reborn-nowait
	$(MAKE) logs-follow

build: commit_hash
	$(COMPOSE) build

build-nocache: commit_hash
	$(COMPOSE) build --no-cache

stop:
	$(COMPOSE) stop

restart-nowait:
	$(COMPOSE) restart || $(MAKE) logs
	$(MAKE) auth-init

restart:
	$(MAKE) restart-nowait
	./wait.sh

restart-withlog:
	$(MAKE) restart-nowait
	$(MAKE) logs-follow

restart@revproxy:
	$(COMPOSE) restart revproxy

shell:
	$(EXEC) /bin/bash

shell-root:
	$(EXEC_ROOT) bash

$(TARGET_SHELL): shell@%:
	$(COMPOSE) exec $* /bin/sh

logs:
	$(COMPOSE) logs nextcloud

logs-follow:
	$(COMPOSE) logs --follow nextcloud

nextcloud.log:
	$(OCC) log:tail 10000 | sed 's/\s*$$//g'

nextcloud.log-follow:
	$(OCC) log:tail -f | sed 's/\s*$$//g'

$(TARGET_LOGS): logs@%:
	$(COMPOSE) logs $*

$(TARGET_LOGS_FOLLOW): logs-follow@%:
	$(COMPOSE) logs --follow $*

$(TARGET_LOGS_TIME): logs-time@%:
	$(COMPOSE) logs --timestamps $*

ECHO_PROJECT_NAME:
	@echo $(COMPOSE_PROJECT_NAME)

ECHO_SUDO:
	@echo $(SUDO)

ECHO_DOCKER:
	@echo eval $(DOCKER)

ECHO_COMPOSE:
	@echo eval $(COMPOSE)

occ-add-missing-indices:
	$(OCC) db:add-missing-indices

occ-maintenancemode-on:
	@$(OCC) maintenance:mode --on

occ-maintenancemode-off:
	@$(OCC) maintenance:mode --off

files-scan:
	$(EXEC) /nc-gfarm/files_scan.sh

backup-force:
	$(EXEC) /nc-gfarm/backup.sh

backup:
	$(call yesno,Nextcloud service will be temporarily stopped.  Do you wish to continue?)
	$(MAKE) backup-force

restore-test:
	$(EXEC_ROOT) /nc-gfarm/restore-test.sh

auth-init:
	$(MAKE) grid-proxy-init
	$(MAKE) myproxy-logon

grid-proxy-init-withlog:
	$(MAKE) grid-proxy-init
	$(MAKE) logs-follow

grid-proxy-init:
	$(EXEC) /nc-gfarm/grid-proxy-init.sh

grid-proxy-init-force:
	$(EXEC) /nc-gfarm/grid-proxy-init.sh --force

myproxy-logon-withlog:
	$(MAKE) myproxy-logon
	$(MAKE) logs-follow

myproxy-logon:
	$(EXEC) /nc-gfarm/myproxy-logon.sh

myproxy-logon-force:
	$(EXEC) /nc-gfarm/myproxy-logon.sh --force

grid-proxy-info:
	$(EXEC) grid-proxy-info

gfkey-e:
	$(EXEC) gfkey -e

timeleft-proxy_cert:
	$(EXEC) /nc-gfarm/timeleft-proxy_cert.sh

timeleft-gfarm_shared_key:
	$(EXEC) /nc-gfarm/timeleft-gfarm_shared_key.sh

gfarm_check_online:
	$(EXEC) bash /nc-gfarm/gfarm_check_online.sh

gfarm_check_online-verbose:
	$(EXEC) bash -x /nc-gfarm/gfarm_check_online.sh

copy-gfarm_shared_key:
	$(EXEC_ROOT) /nc-gfarm/copy_gfarm_shared_key.sh

copy-gsi_user_proxy:
	$(EXEC_ROOT) /nc-gfarm/copy_gsi_user_proxy.sh

resetpassword-admin:
	./resetpassword-admin.sh "$(EXEC_COMMON_USER)" nextcloud

show-nextcloud-version:
	$(OCC) --version

cron-force:
	$(EXEC) php /var/www/html/cron.php

version:
	@$(EXEC) cat /nc-gfarm/version.txt
