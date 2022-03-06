#!/bin/bash

# cd e2lib && docker build . -t everything2/e2lib && cd ..
cd e2base && docker build . -t everything2/e2base && cd ..
cd e2db && docker build . -t everything2/e2db && cd ..
cd e2app && docker build . -t everything2/e2app && cd ..

docker network create e2-dev-net

docker run -d --publish 9306:3306 --env E2DOCKER=development --name=e2devdb --net=e2-dev-net everything2/e2db
docker run -d --publish 9080:80 --publish 443:9443 --env E2DOCKER=development --name=e2devapp --net=e2-dev-net everything2/e2app
