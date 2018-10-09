FROM ubuntu:18.04
MAINTAINER Dennis Uhlemann <dennis.uhlemann@agenterp.com>

RUN apt-get update

ENV  TERM="xterm" DEBIAN_FRONTEND="noninteractive" PSQL_VERSION="9.6" \
    ODOO_SERVER_BRANCH="master" ODOO_ESSENTIALS_BRANCH="8.0"

COPY scripts/* /usr/share/docker-internal/
RUN bash /usr/share/docker-internal/build-image.sh