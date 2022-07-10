set -eu
#set -x

DOCKER=$(make -s ECHO_DOCKER)
COMPOSE=$(make -s ECHO_COMPOSE)
PROJECT_NAME=$(make -s ECHO_PROJECT_NAME)
SUDO=$(make -s ECHO_SUDO)

SERVICE_ID=$(${COMPOSE} ps -q nextcloud)

BACKUP_DIR="/backup"
SECRETS_DIR_NAME="secrets"

IMAGE=${PROJECT_NAME}_nextcloud

NAME=nextcloud-gfarm-backup-$(date +%Y%m%d-%H%M)
NAME_TAR=${NAME}.tar
NAME_ENC=${NAME_TAR}.enc

#COMPRESS_PROG=bzip2
COMPRESS_PROG=pbzip2

NEXTCLOUD_BACKUP_ENCRYPT="aes-256-cbc"
NEXTCLOUD_BACKUP_ENCRYPT_PBKDF2_ITER=10000

TMPDIR=$(mktemp --directory)
WORKDIR=${TMPDIR}/${NAME}

remove_tmpdir()
{
    rm -rf "${TMPDIR}"
}

reset_on_error()
{
    make occ-maintenancemode-off
    remove_tmpdir
}

trap reset_on_error ERR
trap remove_tmpdir EXIT
