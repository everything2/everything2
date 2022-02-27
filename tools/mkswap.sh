#!/bin/bash

if [ ! -e /swapfile ]
then
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

fi
