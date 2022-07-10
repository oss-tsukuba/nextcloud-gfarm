set -eu
#set -x

DOCKER=$(make -s ECHO_DOCKER)
COMPOSE=$(make -s ECHO_COMPOSE)
SERVICE=nextcloud
SERVICE_ID=$(${COMPOSE} ps -q ${SERVICE})

BACKUP_DIR="/backup"
SECRETS_NAME="secrets"
CONF_NAME="config.env"

NAME=nextcloud-gfarm-backup-$(date +%Y%m%d-%H%M)
NAME_TAR=${NAME}.tar
NAME_ENC=${NAME_TAR}.enc

# see nextcloud/config.sh (cannot be commonized)
NEXTCLOUD_BACKUP_ENCRYPT="aes-256-cbc"
NEXTCLOUD_BACKUP_ENCRYPT_PBKDF2_ITER=10000

TMPDIR=$(mktemp --directory)
WORKDIR="${TMPDIR}/${NAME}"

remove_tmpdir()
{
    rm -rf "${TMPDIR}"
}

reset_on_error()
{
    remove_tmpdir
}

trap reset_on_error ERR
trap remove_tmpdir EXIT
