#ARG NEXTCLOUD_VERSION=latest
ARG NEXTCLOUD_VERSION
FROM nextcloud:${NEXTCLOUD_VERSION}
RUN echo ${NEXTCLOUD_VERSION}

ARG GFARM_SRC_URL
ARG GFARM2FS_SRC_URL

RUN apt-get update && apt-get install -y \
  sudo \
  netbase \
  libssl-dev \
  libldap2-dev \
  libpq-dev \
  libglobus-gssapi-gsi-dev \
  pkg-config \
  libfuse-dev \
  libacl1-dev \
  fuse \
  globus-gsi-cert-utils-progs \
  globus-proxy-utils \
  myproxy \
  mariadb-client \
  tar \
  supervisor \
  vim \
  less \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /root
RUN curl -sLJO ${GFARM_SRC_URL}
RUN ARCH=`ls -1 gfarm-*.tar.gz` && \
  tar xf ${ARCH} && \
  DIRNAME=`echo ${ARCH} | sed 's/\.tar\.gz$//g'` && \
  cd ${DIRNAME} && \
  ./configure --with-globus --without-openldap --without-postgresql && \
  make -j && \
  make -j install
RUN curl -sLJO ${GFARM2FS_SRC_URL}
RUN ARCH=`ls -1 gfarm2fs-*.tar.gz` && \
  tar xf ${ARCH} && \
  DIRNAME=`echo ${ARCH} | sed 's/\.tar\.gz$//g'` && \
  cd ${DIRNAME} && \
  ./configure && \
  make -j && \
  make -j install
RUN ldconfig

WORKDIR /
RUN mkdir -p /var/spool/cron/crontabs
COPY crontab.tmpl /var/spool/cron/crontabs/www-data

COPY config.sh /
COPY entrypoint0.sh /
COPY post_process.sh /
COPY backup.sh /
COPY restore.sh /
COPY supervisord.conf /
COPY do_cron.sh /

# overridable
ENV MYSQL_DATABASE=nextcloud
ENV MYSQL_USER=nextcloud
ENV MYSQL_PASSWORD_FILE=/run/secrets/db_password
ENV MYSQL_HOST=mariadb
ENV NEXTCLOUD_ADMIN_USER=admin
ENV NEXTCLOUD_ADMIN_PASSWORD_FILE=/run/secrets/admin_password
ENV NEXTCLOUD_LOG_PATH=/var/log/nextcloud.log
ENV NEXTCLOUD_BACKUP_TIME='0 3 * * *'
ENV NEXTCLOUD_TRUSTED_DOMAINS='localhost'
ENV GFARM_USER=user1
ENV GFARM_DATA_PATH=/home/user1/nextcloud-data
ENV GFARM_BACKUP_PATH=/home/user1/nextcloud-backup
ENV GFARM_ATTR_CACHE_TIMEOUT=180
ENV TZ=Asia/Tokyo
ENV FUSE_ENTRY_TIMEOUT=180
ENV FUSE_NEGATIVE_TIMEOUT=5
ENV FUSE_ATTR_TIMEOUT=180
ENV MYPROXY_PASSWORD_FILE=/run/secrets/myproxy_password
ENV GRID_PROXY_PASSWORD_FILE=/run/secrets/grid_proxy_password
ENV GRID_PROXY_HOURS=168

# Run in the following order:
#   1. /entrypoint0.sh
#   2. /entrypoint.sh (from Nextcloud official image)
#   3. /post_process.sh
#   4. supervisord: apache and cron

WORKDIR /var/www

ENV NEXTCLOUD_UPDATE=1
ENTRYPOINT ["/entrypoint0.sh"]
CMD ["/entrypoint.sh", "/post_process.sh", "supervisord", "-c", "/supervisord.conf"]
