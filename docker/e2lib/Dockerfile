FROM ubuntu:20.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y git wget curl vim build-essential libexpat1-dev libmysqlclient-dev pkg-config libxml2-dev dnsutils
RUN mkdir -p /var/libraries /var/dlcache /var/buildcache
RUN cd /var && git clone https://github.com/everything2/everything2.git everything

RUN perl /var/everything/tools/createdeps.pl --depfile=/var/everything/serverless/deplists/app.json --installdir=/var/libraries --skipverify=Alien::Libxml --builddir=/var/buildcache --dldir=/var/dlcache --skipverify=Alien::Libxml2

RUN rm -rf /var/everything
