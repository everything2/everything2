#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BUILDDIR=/usr/local/build
HTTPDVER=2.4.57
DEBIANPATCH=apache2_2.4.52-1ubuntu4.4.debian.tar.xz
NEWPKGVER="$HTTPDVER-1"
ARCH=`dpkg-architecture -qDEB_HOST_ARCH`

apt-get update && apt-get install -y bison jdupes libapr1-dev libaprutil1-dev libbrotli-dev liblua5.3-dev libnghttp2-dev libpcre3-dev lsb-release libcurl4-openssl-dev debhelper-compat libjansson-dev
rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"
ls -al $SCRIPT_DIR
cp $SCRIPT_DIR/*.patch "$BUILDDIR"
cd "$BUILDDIR" && wget "https://archive.apache.org/dist/httpd/httpd-$HTTPDVER.tar.gz"
tar xzf "httpd-$HTTPDVER.tar.gz"
mv "httpd-$HTTPDVER" "apache2-$HTTPDVER"
wget "http://archive.ubuntu.com/ubuntu/pool/main/a/apache2/$DEBIANPATCH"
cd "apache2-$HTTPDVER"
cat "../$DEBIANPATCH" | xz -d | tar x | patch -p1
cat ../*.patch | patch -p0
dpkg-buildpackage -b
cd ..
dpkg -i apache2-bin_2.4.57-1_$ARCH.deb apache2-data_2.4.57-1_all.deb apache2-utils_2.4.57-1_$ARCH.deb apache2_2.4.57-1_$ARCH.deb
