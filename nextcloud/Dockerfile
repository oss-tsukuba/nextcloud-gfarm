ARG NEXTCLOUD_VERSION
FROM nextcloud:${NEXTCLOUD_VERSION}

ARG GFARM_SRC_URL
ARG GFARM_SRC_GIT_URL
ARG GFARM_SRC_GIT_BRANCH
ARG GFARM2FS_SRC_URL
ARG GFARM2FS_SRC_GIT_URL
ARG GFARM2FS_SRC_GIT_BRANCH
ARG JWT_AGENT_SRC_GIT_URL
ARG JWT_AGENT_SRC_GIT_BRANCH
ARG JWT_LOGON_SRC_GIT_URL
ARG JWT_LOGON_SRC_GIT_BRANCH
ARG SCITOKENS_CPP_SRC_GIT_URL
ARG SCITOKENS_CPP_SRC_GIT_BRANCH
ARG SASL_XOAUTH2_SRC_GIT_URL
ARG SASL_XOAUTH2_SRC_GIT_BRANCH

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
  smbclient \
  iproute2 \
  pbzip2 \
  # for SASL authentication
  && apt-get -y install sasl2-bin libsasl2-modules-db libsasl2-dev \
 libsasl2-modules libsasl2-modules-gssapi-mit \
  \
  # Gfarm \
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
  && make -j 4 \
  && make install \
  \
  # jwt-parse
  && apt-get -y install jq \
  && install -t /usr/local/bin -m 755 util/jwt-parse/jwt-parse  \
  \
  # gfarm2fs \
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
  && make -j 4 \
  && make install \
  && ldconfig \
  \
  # jwt-agent \
  && cd ${WORKDIR} \
  && if [ -n "${JWT_AGENT_SRC_GIT_URL}" ]; then \
       GO_TAR=go1.20.linux-amd64.tar.gz \
       && curl -sLJO https://go.dev/dl/${GO_TAR} \
       && tar -C /usr/local -xzf ${GO_TAR} \
       && ln -s /usr/local/go/bin/go /usr/local/bin \
       && DIRNAME=jwt-agent \
       && git clone -b ${JWT_AGENT_SRC_GIT_BRANCH} --depth 1 ${JWT_AGENT_SRC_GIT_URL} ${DIRNAME} \
       && cd ${DIRNAME} \
       && make \
       && make PREFIX=/usr/local install \
   ; fi \
  \
  # jwt-logon \
  && cd ${WORKDIR} \
  && if [ -n "${JWT_LOGON_SRC_GIT_URL}" ]; then \
       DIRNAME=jwt-logon \
       && git clone -b ${JWT_LOGON_SRC_GIT_BRANCH} --depth 1 ${JWT_LOGON_SRC_GIT_URL} ${DIRNAME} \
       && cd ${DIRNAME} \
       && make PREFIX=/usr/local install \
   ; fi \
  \
  # scitokens-cpp \
  && cd ${WORKDIR} \
  && if [ -n "${SCITOKENS_CPP_SRC_GIT_URL}" ]; then \
       DIRNAME=scitokens-cpp \
       && apt-get -y install g++ cmake libsqlite3-dev \
       libcurl4-openssl-dev uuid-dev \
       && git clone -b ${SCITOKENS_CPP_SRC_GIT_BRANCH} --depth 1 ${SCITOKENS_CPP_SRC_GIT_URL} ${DIRNAME} \
       && cd ${DIRNAME} \
       && mkdir -p build \
       && cd build \
       && cmake -DCMAKE_INSTALL_PREFIX=/usr .. \
       && make -j 4 \
       && make install \
   ; fi \
  \
  # cyrus-sasl-xoauth2-idp
  && cd ${WORKDIR} \
  && if [ -n "${SASL_XOAUTH2_SRC_GIT_URL}" ]; then \
       DIRNAME=cyrus-sasl-xoauth2-idp \
       && git clone -b ${SASL_XOAUTH2_SRC_GIT_BRANCH} --depth 1 ${SASL_XOAUTH2_SRC_GIT_URL} ${DIRNAME} \
       && cd ${DIRNAME} \
       && ./autogen.sh \
       && sasl_libdir=$(pkg-config --variable=libdir libsasl2) \
       && ./configure --libdir="${sasl_libdir}" \
       && make install \
   ; fi \
  \
  && mkdir -p /var/spool/cron/crontabs \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

### for debug
# RUN apt-get update \
#   && apt-get install -y \
#   lsb-release \
#   && CODENAME=$(lsb_release -cs) \
#   && LIST="/etc/apt/sources.list.d/debug.list" \
#   && echo "deb http://debug.mirrors.debian.org/debian-debug/ ${CODENAME}-debug main" >> ${LIST} \
#   && echo "deb http://debug.mirrors.debian.org/debian-debug/ ${CODENAME}-backports-debug main" >> ${LIST} \
#   && echo "deb http://debug.mirrors.debian.org/debian-debug/ ${CODENAME}-proposed-updates-debug main" >> ${LIST} \
#   && apt-get update \
#   && apt-get install -y \
#   valgrind \
#   libc6-dbg \
#   libfuse2-dbgsym \
#   valgrind-dbg

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
