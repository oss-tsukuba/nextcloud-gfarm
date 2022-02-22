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
EXEC_ROOT = $(EXEC_COMMON_USER) nextcloud

OCC = $(COMPOSE) exec -u www-data nextcloud php /var/www/html/occ
SHELL=/bin/bash

# use selfsigned certificate
SSC_COMPOSE = $(COMPOSE) -f docker-compose.selfsigned.yml

CONTAINERS = nextcloud mariadb redis revproxy

.PONY =

define gentarget
       $(foreach name,$(CONTAINERS),$(1)-$(name))
endef

TARGET_LOGS = $(call gentarget,logs)
.PONY += $(TARGET_LOGS)

TARGET_LOGS_FOLLOW = $(call gentarget,logs-follow)
.PONY += $(TARGET_LOGS_FOLLOW)

TARGET_LOGS_TIME = $(call gentarget,logs-time)
.PONY += $(TARGET_LOGS_TIME)

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

selfsigned-cert-ps:
	$(SSC_COMPOSE) ps

selfsigned-cert-config:
	$(SSC_COMPOSE) config

selfsigned-cert-fingerprint:
	$(EXEC_COMMON_ROOT) revproxy /cert-fingerprint.sh

config:
	$(COMPOSE) config

down:
	$(COMPOSE) down --remove-orphans
	$(MAKE) prune

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

down-REMOVE_VOLUMES:
	$(call yesno,ERASE ALL LOCAL DATA. Do you have a backup?)
	echo $(COMPOSE) down --volumes --remove-orphans

reborn:
	$(COMPOSE) build
	$(MAKE) down
	$(COMPOSE) up -d || { $(MAKE) logs; false; }
	$(MAKE) auth-init || { $(MAKE) logs; false; }

reborn-withlog:
	$(MAKE) reborn
	$(MAKE) logs-follow

build-nocache:
	$(COMPOSE) build --no-cache

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart || $(MAKE) logs
	$(MAKE) auth-init

restart-withlog:
	$(MAKE) restart
	$(MAKE) logs-follow

restart-revproxy:
	$(COMPOSE) restart revproxy

shell:
	$(EXEC) /bin/bash

shell-root:
	$(EXEC_ROOT) bash

shell-revproxy:
	$(COMPOSE) exec revproxy /bin/bash

logs:
	$(COMPOSE) logs nextcloud

logs-follow:
	$(COMPOSE) logs --follow nextcloud

$(TARGET_LOGS): logs-%:
	$(COMPOSE) logs $*

$(TARGET_LOGS_FOLLOW): logs-follow-%:
	$(COMPOSE) logs --follow $*

$(TARGET_LOGS_TIME): logs-time-%:
	$(COMPOSE) logs --timestamps $*

occ-add-missing-indices:
	$(OCC) db:add-missing-indices

occ-maintenancemode-on:
	$(OCC) maintenance:mode --on

occ-maintenancemode-off:
	$(OCC) maintenance:mode --off

files-scan:
	$(EXEC) /nc-gfarm/files_scan.sh

backup:
	$(call yesno,Nextcloud service will be temporarily stopped.  Do you wish to continue?)
	$(EXEC) /nc-gfarm/backup.sh

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
