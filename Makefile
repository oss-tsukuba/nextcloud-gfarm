COMPOSE_PROJECT_NAME = nextcloud-gfarm
SUDO = sudo

DOCKER = $(SUDO) docker

COMPOSE_V1 = docker-compose
COMPOSE_V2 = docker compose
COMPOSE = $(SUDO) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) $(COMPOSE_V1)
#COMPOSE = $(SUDO) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) $(COMPOSE_V2)

ps:
	$(COMPOSE) ps

prune:
	$(DOCKER) system prune -f

down:
	$(COMPOSE) down --remove-orphans
	$(MAKE) prune

down-REMOVE_VOLUMES:
	$(COMPOSE) down --volumes --remove-orphans

reborn update:
	$(COMPOSE) build
	$(MAKE) down
	$(COMPOSE) up -d

reborn-withlog:
	$(MAKE) reborn
	$(COMPOSE) logs --follow

build-nocache:
	$(COMPOSE) build --no-cache

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart

restart-withlog:
	$(MAKE) restart
	$(COMPOSE) logs --follow

shell:
	$(COMPOSE) exec -u www-data nextcloud /bin/bash

shell-root:
	$(COMPOSE) exec nextcloud bash

logs:
	$(COMPOSE) logs

logs-follow:
	$(COMPOSE) logs --follow

copy-gfarm_shared_key:
	$(COMPOSE) exec -u root nextcloud /copy_gfarm_shared_key.sh
