#!/bin/bash

docker container stop e2devapp
docker container stop e2devdb

docker rm e2devdb
docker rm e2devapp

docker image rm everything2/e2db
docker image rm everything2/e2app
docker image rm everything2/e2base
# docker image rm everything2/e2lib

docker builder prune --all --force
