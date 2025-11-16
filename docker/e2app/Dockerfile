FROM ubuntu:24.04

ARG ARCH=x64
ARG CODEBUILD_RESOLVED_SOURCE_VERSION

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y git wget curl vim build-essential libexpat1-dev libmysqlclient-dev pkg-config libxml2-dev dnsutils tzdata perl apache2 libapache2-mod-perl2 mysql-client ruby ruby-dev xz-utils cpanminus perlmagick psmisc cmake && rm -rf /var/lib/apt/lists/*
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# Ruby
RUN gem install aws-sdk-s3 aws-sdk-ecs aws-sdk-elasticloadbalancingv2 aws-sdk-cloudwatchlogs

# Core Directories and Apache
RUN mkdir -p /var/libraries /etc/everything /var/mason /var/log/everything /etc/apache2/logs /var/everything /var/bootstrap/cache
RUN rm -f /etc/apache2/mods-enabled/mpm_event.*
RUN rm -rf /etc/apache2/sites-enabled /etc/apache2/sites-available /etc/apache2/ports.conf /etc/apache2/conf.d /etc/apache2/conf-enabled /etc/apache2/conf-available
RUN for i in deflate rewrite authz_core proxy proxy_http ssl perl mpm_prefork socache_shmcb status; do ln -sf ../mods-available/$i.load /etc/apache2/mods-enabled/$i.load; done
RUN chown root:root /etc/everything
RUN chown www-data:www-data /var/mason /var/log/everything /etc/apache2/logs
RUN chmod 0755 /var/mason

# Perl
COPY ./vendor/cache/ /var/bootstrap/cache/
COPY ./cpanfile /var/bootstrap
RUN cpanm -L /var/libraries --from "/var/bootstrap/cache" --installdeps --notest --cpanfile=/var/bootstrap/cpanfile .

# NodeJS / React
RUN curl -L "https://nodejs.org/download/release/v20.19.2/node-v20.19.2-linux-$ARCH.tar.xz" | xz -cd | tar xv --strip-components=1 -C /usr
RUN /usr/bin/npm install -g npm@latest

COPY ./tools/generate-self-signed-cert.rb /var/bootstrap
COPY ./etc/templates/* /var/bootstrap/etc/
RUN ruby /var/bootstrap/generate-self-signed-cert.rb

COPY docker/e2app/apache2_wrapper.rb /etc/everything
RUN chmod +x /etc/everything/apache2_wrapper.rb

# Install Node dependencies (separate layer for better caching)
WORKDIR /var/everything
COPY package.json package-lock.json ./
RUN /usr/bin/npm install

# Copy application code
COPY ./ /var/everything
RUN rm -rf /var/everything/local

# Build assets (done in buildspec.yml for CodeBuild, or here for local builds)
RUN /usr/bin/npx webpack --config etc/webpack.config.js --mode=development || true

RUN if [ -n "$CODEBUILD_RESOLVED_SOURCE_VERSION" ]; then echo "$CODEBUILD_RESOLVED_SOURCE_VERSION"; else git -C /var/everything rev-parse HEAD; fi > /etc/everything/last_commit

EXPOSE 80
EXPOSE 443

CMD ["/etc/everything/apache2_wrapper.rb"]
