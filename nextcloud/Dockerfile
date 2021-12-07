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
COPY common-lib.sh /
COPY copy_gfarm_shared_key.sh /

# Run in the following order:
#   1. /entrypoint0.sh
#   2. /entrypoint.sh (from Nextcloud official image)
#   3. /post_process.sh
#   4. supervisord: apache and cron

WORKDIR /var/www

ENTRYPOINT ["/entrypoint0.sh"]
CMD ["/entrypoint.sh", "/post_process.sh", "supervisord", "-c", "/supervisord.conf"]
