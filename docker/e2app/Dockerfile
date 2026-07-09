# Stage 1: Dependencies (cached separately)
FROM ubuntu:26.04 AS deps

ARG ARCH=x64

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y git wget curl vim build-essential libcrypt-dev libssl-dev zlib1g-dev libbrotli-dev libzstd-dev libexpat1-dev libmysqlclient-dev pkg-config libxml2-dev dnsutils tzdata perl apache2 libapache2-mod-perl2 libapache2-mod-evasive mysql-client ruby ruby-dev xz-utils cpanminus perlmagick psmisc cmake unzip && rm -rf /var/lib/apt/lists/*
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# Ruby
RUN gem install aws-sdk-s3 aws-sdk-ecs aws-sdk-elasticloadbalancingv2 aws-sdk-cloudwatchlogs

# AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "/tmp/awscliv2.zip" && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/awscliv2.zip /tmp/aws

# Core Directories and Apache
RUN mkdir -p /var/libraries /etc/everything /var/mason /var/log/everything /etc/apache2/logs /var/everything /var/bootstrap/cache
RUN rm -rf /etc/apache2/sites-enabled /etc/apache2/sites-available /etc/apache2/ports.conf /etc/apache2/conf.d /etc/apache2/conf-enabled /etc/apache2/conf-available
# PSGI: Apache is a pure reverse proxy -- no mod_perl, so no `perl` module and
# mpm_event (the base-image default) instead of mpm_prefork. prefork was only
# mandated by mod_perl's lack of thread-safety; event handles proxy connections
# with threads at far lower per-connection cost. (#4234, full PSGI commit)
RUN for i in deflate brotli rewrite authz_core proxy proxy_http mpm_event status evasive remoteip; do ln -sf ../mods-available/$i.load /etc/apache2/mods-enabled/$i.load; done
RUN chown root:root /etc/everything
RUN chown www-data:www-data /var/mason /var/log/everything /etc/apache2/logs
RUN chmod 0755 /var/mason

# Perl dependencies (only changes when cpanfile or vendor/cache changes)
COPY ./vendor/cache/ /var/bootstrap/cache/
COPY ./cpanfile /var/bootstrap
RUN cpanm -L /var/libraries --from "/var/bootstrap/cache" --installdeps --notest --cpanfile=/var/bootstrap/cpanfile .

# NodeJS / React
RUN curl -L "https://nodejs.org/download/release/v20.19.2/node-v20.19.2-linux-$ARCH.tar.xz" | xz -cd | tar xv --strip-components=1 -C /usr
# Pin npm to 11 (newest major compatible with the pinned node 20.19.2). npm@latest
# floated to 12.x (node-22+ only) and EBADENGINE-rejects node 20; bump in lockstep with node.
RUN /usr/bin/npm install -g npm@11

# Node dependencies (only changes when package.json/package-lock.json changes)
WORKDIR /var/everything
COPY package.json package-lock.json ./
RUN /usr/bin/npm install

# Stage 2: Final image with application code
FROM deps AS final

ARG CODEBUILD_RESOLVED_SOURCE_VERSION

# mod_perl is enabled by default in the base image (libapache2-mod-perl2); under
# PSGI Apache runs no Perl handlers, so unload it -- no redundant interpreter and
# no thread-safety concern under mpm_event. (#4234)
RUN rm -f /etc/apache2/mods-enabled/perl.load /etc/apache2/mods-enabled/perl.conf

COPY ./etc/templates/* /var/bootstrap/etc/

COPY docker/e2app/apache2_wrapper.rb /etc/everything
RUN chmod +x /etc/everything/apache2_wrapper.rb

# Copy application code
COPY ./ /var/everything
RUN rm -rf /var/everything/local

# Build assets (done in buildspec.yml for CodeBuild, or here for local builds)
RUN /usr/bin/npx webpack --config etc/webpack.config.js --mode=development || true

RUN if [ -n "$CODEBUILD_RESOLVED_SOURCE_VERSION" ]; then echo "$CODEBUILD_RESOLVED_SOURCE_VERSION"; else git -C /var/everything rev-parse HEAD; fi > /etc/everything/last_commit

EXPOSE 80

CMD ["/etc/everything/apache2_wrapper.rb"]
