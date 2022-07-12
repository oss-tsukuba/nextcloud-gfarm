set -eu
#set -x

DOCKER=$(make -s ECHO_DOCKER)
COMPOSE=$(make -s ECHO_COMPOSE)
PROJECT_NAME=$(make -s ECHO_PROJECT_NAME)
SUDO=$(make -s ECHO_SUDO)

BACKUP_DIR="/backup"
SECRETS_DIR_NAME="secrets"
CONF_FILE_NAME="config.env"
VERSION_FILE_NAME="version.txt"

BACKUP_FILES=("${SECRETS_DIR_NAME}" "${CONF_FILE_NAME}")

IMAGE=${PROJECT_NAME}_nextcloud
IMAGE_SIMPLE=alpine

#COMPRESS_PROG=bzip2
COMPRESS_PROG=pbzip2

NEXTCLOUD_BACKUP_ENCRYPT="aes-256-cbc"
NEXTCLOUD_BACKUP_ENCRYPT_PBKDF2_ITER=10000

TMPDIR=$(mktemp --directory)

remove_tmpdir()
{
    rm -rf "${TMPDIR}"
}

reset_on_error()
{
    call_on_error
    remove_tmpdir
}

trap reset_on_error ERR
trap remove_tmpdir EXIT
