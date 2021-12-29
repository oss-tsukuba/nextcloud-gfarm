COMPOSE_PROJECT_NAME = nextcloud-gfarm

SUDO = $(shell docker version > /dev/null 2>&1 || echo sudo)
DOCKER = $(SUDO) docker
COMPOSE_V1 = docker-compose
COMPOSE_V2 = docker compose
COMPOSE_SW = $(shell which ${COMPOSE_V1} || echo ${COMPOSE_V2})
COMPOSE = $(SUDO) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) $(COMPOSE_SW)

EXEC = $(COMPOSE) exec -u www-data nextcloud
EXEC_ROOT = $(COMPOSE) exec -u root nextcloud

OCC = $(COMPOSE) exec -u www-data nextcloud php /var/www/html/occ

ps:
	$(COMPOSE) ps

prune:
	$(DOCKER) system prune -f

down:
	$(COMPOSE) down --remove-orphans
	$(MAKE) prune

down-REMOVE_VOLUMES:
	$(COMPOSE) down --volumes --remove-orphans

reborn:
	$(COMPOSE) build
	$(MAKE) down
	$(COMPOSE) up -d || $(MAKE) logs
	$(MAKE) auth-init

reborn-withlog:
	$(MAKE) reborn
	$(COMPOSE) logs --follow

build-nocache:
	$(COMPOSE) build --no-cache

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart || $(MAKE) logs
	$(MAKE) auth-init

restart-withlog:
	$(MAKE) restart
	$(COMPOSE) logs --follow

shell:
	$(EXEC) /bin/bash

shell-root:
	$(EXEC_ROOT) bash

shell-proxy:
	$(COMPOSE) exec proxy /bin/bash

logs:
	$(COMPOSE) logs

logs-follow:
	$(COMPOSE) logs --follow

logs-less:
	$(COMPOSE) logs | less -R

occ-add-missing-indices:
	$(OCC) db:add-missing-indices

occ-maintenancemode-on:
	$(OCC) maintenance:mode --on

occ-maintenancemode-off:
	$(OCC) maintenance:mode --off

files-scan:
	$(EXEC) /nc-gfarm/files_scan.sh

backup:
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

copy-globus_user_proxy:
	$(EXEC_ROOT) /nc-gfarm/copy_globus_user_proxy.sh
