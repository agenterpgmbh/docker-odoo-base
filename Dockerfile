FROM ubuntu:18.04
MAINTAINER Dennis Uhlemann <dennis.uhlemann@agenterp.com>

RUN apt-get update

ENV  TERM="xterm" DEBIAN_FRONTEND="noninteractive" PSQL_VERSION="9.6"

COPY scripts/* /usr/share/docker-internal/
RUN bash /usr/share/docker-internal/build-image.sh
