ARG NEXTCLOUD_VERSION
FROM nextcloud:${NEXTCLOUD_VERSION}

ARG GFARM_SRC_URL
ARG GFARM_SRC_GIT_URL
ARG GFARM_SRC_GIT_BRANCH
ARG GFARM2FS_SRC_URL
ARG GFARM2FS_SRC_GIT_URL
ARG GFARM2FS_SRC_GIT_BRANCH

RUN echo ${NEXTCLOUD_VERSION} \
  && apt-get update && apt-get install -y \
  sudo \
  netbase \
  rsyslog \
  bind9-dnsutils \
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
  git \
  vim \
  less \
  libmagickcore-*-extra \
  iproute2 \
  pbzip2 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  \
  && WORKDIR=/root \
  && cd ${WORKDIR} \
  && if [ -n "${GFARM_SRC_URL}" ]; then \
       curl -sLJO ${GFARM_SRC_URL} \
       && ARCH=`ls -1 gfarm-*.tar.gz` \
       && tar xf ${ARCH} \
       && DIRNAME=`echo ${ARCH} | sed 's/\.tar\.gz$//g'` \
     ; else \
       DIRNAME=gfarm \
       && git clone -b ${GFARM_SRC_GIT_BRANCH} --depth 1 ${GFARM_SRC_GIT_URL} ${DIRNAME} \
     ; fi \
  && echo DIRNAME=${DIRNAME} \
  && cd ${DIRNAME} \
  && ./configure --with-globus --without-openldap --without-postgresql \
  && make -j \
  && make -j install \
  && cd ${WORKDIR} \
  && if [ -n "${GFARM2FS_SRC_URL}" ]; then \
       curl -sLJO ${GFARM2FS_SRC_URL} \
       && ARCH=`ls -1 gfarm2fs-*.tar.gz` \
       && tar xf ${ARCH} \
       && DIRNAME=`echo ${ARCH} | sed 's/\.tar\.gz$//g'` \
     ; else \
       DIRNAME=gfarm2fs \
       && git clone -b ${GFARM2FS_SRC_GIT_BRANCH} --depth 1 ${GFARM2FS_SRC_GIT_URL} ${DIRNAME} \
     ; fi \
  && cd ${DIRNAME} \
  && ./configure \
  && make -j \
  && make -j install \
  && ldconfig \
  && mkdir -p /var/spool/cron/crontabs

COPY . /nc-gfarm

# Run in the following order:
#   1. /entrypoint0.sh
#   2. /entrypoint.sh (from Nextcloud official image)
#   3. /post_process.sh
#   4. supervisord: apache and cron

STOPSIGNAL 15
WORKDIR /var/www
ENTRYPOINT ["/nc-gfarm/entrypoint0.sh"]
CMD ["/entrypoint.sh", "/nc-gfarm/post_process.sh", "supervisord", "-c", "/nc-gfarm/supervisord.conf"]
