FROM ubuntu:20.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y git wget curl vim build-essential libexpat1-dev libmysqlclient-dev pkg-config libxml2-dev dnsutils tzdata perl apache2 libapache2-mod-perl2 perlmagick mysql-client ruby xz-utils && rm -rf /var/lib/apt/lists/*
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# Ruby
RUN gem install aws-sdk-rds aws-sdk-elasticloadbalancingv2 aws-sdk-iam aws-sdk-secretsmanager aws-sdk-ses aws-sdk-opsworks aws-sdk-ec2 aws-sdk-lambda aws-sdk-s3

# Core Directories and Apache
RUN mkdir -p /var/libraries /var/dlcache /var/buildcache /etc/everything /var/mason /var/log/everything /etc/apache2/logs /var/everything /var/bootstrap/etc
RUN rm -f /etc/apache2/mods-enabled/mpm_event.*
RUN rm -rf /etc/apache2/sites-enabled /etc/apache2/sites-available /etc/apache2/ports.conf /etc/apache2/conf.d /etc/apache2/conf-enabled /etc/apache2/conf-available
RUN for i in deflate rewrite authz_core proxy proxy_http ssl perl mpm_prefork socache_shmcb; do ln -sf ../mods-available/$i.load /etc/apache2/mods-enabled/$i.load; done
RUN chown root:root /etc/everything
RUN chown www-data:www-data /var/mason /var/log/everything /etc/apache2/logs
RUN chmod 0755 /var/mason

# Perl
COPY ./tools/createdeps.pl /var/bootstrap
COPY ./serverless/deplists/app.json /var/bootstrap
RUN perl /var/bootstrap/createdeps.pl --depfile=/var/bootstrap/app.json --installdir=/var/libraries --skipverify=Alien::Libxml --builddir=/var/buildcache --dldir=/var/dlcache --skipverify=Alien::Libxml2
RUN rm -rf /var/dlcache/* /var/buildcache/*

# NodeJS / React
RUN curl -L https://nodejs.org/dist/v16.15.1/node-v16.15.1-linux-x64.tar.xz | xz -cd | tar xv --strip-components=1 -C /usr
RUN npm install -g npm@latest


COPY ./tools/write_apache_config.rb /var/bootstrap
COPY ./tools/generate-self-signed-cert.rb /var/bootstrap
COPY ./etc/templates/* /var/bootstrap/etc/
RUN ruby /var/bootstrap/write_apache_config.rb
RUN ruby /var/bootstrap/generate-self-signed-cert.rb

COPY docker/e2app/apache2_wrapper.rb /etc/everything
RUN chmod +x /etc/everything/apache2_wrapper.rb

COPY ./ /var/everything
WORKDIR /var/everything
RUN npm install
RUN npx webpack --config etc/webpack.config.js --mode=development

RUN git -C /var/everything rev-parse HEAD > /etc/everything/last_commit

EXPOSE 80
EXPOSE 443

CMD ["/etc/everything/apache2_wrapper.rb"]
