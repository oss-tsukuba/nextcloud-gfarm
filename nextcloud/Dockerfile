ARG NEXTCLOUD_VERSION=latest
FROM nextcloud:${NEXTCLOUD_VERSION}

ENV MYSQL_DATABASE=nextcloud
ENV MYSQL_USER=nextcloud
ENV MYSQL_PASSWORD_FILE=/run/secrets/db_password
ENV MYSQL_HOST=mariadb
ENV NEXTCLOUD_ADMIN_USER=admin
ENV NEXTCLOUD_ADMIN_PASSWORD_FILE=/run/secrets/admin_password
ENV NEXTCLOUD_UPDATE=1
ENV NEXTCLOUD_LOG_PATH=/var/log/nextcloud.log
ENV GFARM_USER=user1
ENV GFARM_DATA_PATH=/home/user1/nextcloud-data
ENV GFARM_BACKUP_PATH=/home/user1/nextcloud-backup

ARG GFARM_SRC_URL
ARG GFARM2FS_SRC_URL

RUN apt-get update && apt-get install -y \
 sudo \
 libssl-dev \
 libldap2-dev \
 libpq-dev \
 libglobus-gssapi-gsi-dev \
 pkg-config \
 postgresql \
 postgresql-client \
 libfuse-dev \
 libacl1-dev \
 fuse \
 mariadb-client \
 unzip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /root
RUN curl -sLJO ${GFARM_SRC_URL}
RUN ARCH=`ls -1 | grep gfarm | grep zip` && \
 unzip ${ARCH} && \
 DIRNAME=`echo ${ARCH} | sed 's/\.zip$//g'` && \
 cd ${DIRNAME} && \
 ./configure && \
 make && \
 make install
RUN curl -sLJO ${GFARM2FS_SRC_URL}
RUN ARCH=`ls -1 | grep gfarm2fs | grep zip` && \
 unzip ${ARCH} && \
 DIRNAME=`echo ${ARCH} | sed 's/\.zip$//g'` && \
 cd ${DIRNAME} && \
 ./configure && \
 make && \
 make install
RUN ldconfig

WORKDIR /

COPY config.sh /
COPY docker_entrypoint.sh /
COPY post_process.sh /
COPY backup.sh /
COPY restore.sh /

ENTRYPOINT ["/docker_entrypoint.sh"]
CMD ["/entrypoint.sh", "/post_process.sh", "apache2-foreground"]
