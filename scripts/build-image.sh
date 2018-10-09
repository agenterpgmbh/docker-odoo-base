#!/usr/bin/env bash

# Exit inmediately if a command fails
set -e

. /usr/share/docker-internal/library.sh
. /etc/lsb-release

# Let's set some defaults here
ARCH="$( dpkg --print-architecture )"
BIONIC_REPO="deb http://archive.ubuntu.com/ubuntu/ bionic main universe multiverse"
BIONIC_UPDATES_REPO="deb http://archive.ubuntu.com/ubuntu/ bionic-updates main universe multiverse"
BIONIC_SECURITY_REPO="deb http://archive.ubuntu.com/ubuntu/ bionic-security main universe multiverse"
PSQL_UPSTREAM_REPO="deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main"
PSQL_UPSTREAM_KEY="https://www.postgresql.org/media/keys/ACCC4CF8.asc"
DPKG_PRE_DEPENDS="gnupg wget ca-certificates curl"
DPKG_DEPENDS="bzr \
              git \
              mercurial \
              bash-completion \
              apt-transport-https \
              curl \
              wget \
              htop \
              locate \
              lsof \
              multitail \
              tmux \
              unzip \
              vim \
              vim-nox \
              w3m \
              openssl \
              openssh-client \
              python \
              python-setuptools \
              nodejs \
              phantomjs \
              antiword \
              python-dev \
              poppler-utils \
              xmlstarlet \
              xsltproc \
              xz-utils \
              swig \
              geoip-database-contrib \
              libpq-dev \
              libldap2-dev \
              libsasl2-dev \
              build-essential \
              gfortran \
              libfreetype6-dev \
              zlib1g-dev \
              libjpeg-dev \
              libblas-dev \
              liblapack-dev \
              libxml2-dev \
              libxslt1-dev \
              libgeoip-dev \
              libssl-dev \
              cython \
              fontconfig \
              ghostscript \
              cloc \
              postgresql-common \
              postgresql-${PSQL_VERSION} \
              postgresql-client-${PSQL_VERSION} \
              postgresql-contrib-${PSQL_VERSION} \
              postgresql-server-dev-${PSQL_VERSION} \
              pgbadger \
              python-cups \
              wkhtmltopdf"

PIP_OPTS="--upgrade \
          --no-cache-dir -r"

NPM_OPTS="-g"
NPM_DEPENDS="less \
             less-plugin-clean-css \
             jshint"


# Dpkg, please always install configurations from upstream, be fast
# and no questions asked.
{
    echo 'force-confmiss'
    echo 'force-confnew'
    echo 'force-overwrite'
    echo 'force-unsafe-io'
} | tee /etc/dpkg/dpkg.cfg.d/100-agenterp-dpkg > /dev/null

# Apt, don't give me translations, assume always a positive answer,
# don't fill my image with recommended stuff i didn't told you to install,
# be permissive with packages without visa.
{
    echo 'Acquire::Languages "none";'
    echo 'Apt::Get::Assume-Yes "true";'
    echo 'Apt::Install-Recommends "false";'
    echo 'Apt::Get::AllowUnauthenticated "true";'
    echo 'Dpkg::Post-Invoke { "/usr/share/docker-internal/clean-image.sh"; }; '
} | tee /etc/apt/apt.conf.d/100-agenterp-apt > /dev/null

# Configure apt sources so we can use multiverse section from repo
conf_aptsources "${BIONIC_REPO}" "${BIONIC_UPDATES_REPO}" "${BIONIC_SECURITY_REPO}"

# Upgrade system and install some pre-dependencies
apt-get update
apt-get upgrade
apt-get install ${DPKG_PRE_DEPENDS}

curl -sL https://deb.nodesource.com/setup_8.x | bash -

# This will put postgres's upstream repo for us to install a newer
# postgres because our image is so old
add_custom_aptsource "${PSQL_UPSTREAM_REPO}" "${PSQL_UPSTREAM_KEY}"

# Release the apt monster!
apt-get update
apt-get upgrade
apt-get install ${DPKG_DEPENDS} ${PIP_DPKG_BUILD_DEPENDS}

# Install node dependencies
npm install ${NPM_OPTS} ${NPM_DEPENDS}

# Get pip from upstream because is lighter
py_download_execute https://bootstrap.pypa.io/get-pip.py


# Let's keep this version ultil the bugs get fixed
pip install --upgrade pip

# Install python dependencies
pip install ${PIP_OPTS} /usr/share/docker-internal/odoo_base_requirements.txt
pip install ${PIP_OPTS} /usr/share/docker-internal/test_requirements.txt


# Configure the path for the postgres logs
echo "Configure the path for the postgres logs"
mkdir -p /var/log/pg_log
chmod 0757 /var/log/pg_log/
echo -e "export PG_LOG_PATH=/var/log/pg_log/postgresql.log\n" | tee -a /etc/bash.bashrc

cat >> /etc/postgresql-common/common-agenterp.conf << EOF
listen_addresses = '*'
temp_buffers = 16MB
work_mem = 16MB
max_stack_depth = 7680kB
bgwriter_delay = 500ms
fsync=off
full_page_writes=off
checkpoint_timeout=45min
synchronous_commit=off
autovacuum = off
max_connections = 200
max_pred_locks_per_transaction = 100
logging_collector=on
log_destination='stderr'
log_directory='/var/log/pg_log'
log_filename='postgresql.log'
log_rotation_age=0
log_checkpoints=on
log_hostname=on
log_line_prefix='%t [%p]: [%l-1] db=%d,user=%u'
EOF

# Final cleaning
find /tmp -type f -print0 | xargs -0r rm -rf
find /var/tmp -type f -print0 | xargs -0r rm -rf
find /var/log -type f -print0 | xargs -0r rm -rf
find /var/lib/apt/lists -type f -print0 | xargs -0r rm -rf

/etc/init.d/postgresql stop
echo "include = '/etc/postgresql-common/common-agenterp.conf'" >> /etc/postgresql/${PSQL_VERSION}/main/postgresql.conf
echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/$PSQL_VERSION/main/pg_hba.con
/etc/init.d/postgresql start
psql_create_role "odoo" "12wqeads34wrefsdv"