#!/bin/bash

docker network inspect e2-dev-net >/dev/null 2>&1 || docker network create e2-dev-net

docker container stop e2devapp
docker rm e2devapp
docker image rm everything2/e2app
docker build -t everything2/e2app -f docker/e2app/Dockerfile .
docker run -d --publish 9080:80 --publish 443:9443 --env E2DOCKER=development --name=e2devapp --net=e2-dev-net everything2/e2app

if [ "$1" = "full" ]; then
  docker container stop e2devdb
  docker rm e2devdb
  docker image rm everything2/e2db
  docker build -t everything2/e2db -f docker/e2db/Dockerfile .
  docker run -d --publish 9306:3306 --env E2DOCKER=development --name=e2devdb --net=e2-dev-net everything2/e2db
fi
