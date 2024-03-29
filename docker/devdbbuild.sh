
#!/bin/bash


SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

docker network inspect e2-dev-net >/dev/null 2>&1 || docker network create e2-dev-net

$SCRIPT_DIR/devbuild.sh

docker container stop e2devdb
docker rm e2devdb
docker image rm everything2/e2db
docker build -t everything2/e2db -f docker/e2db/Dockerfile .
docker run -d --publish 9306:3306 --env E2_DOCKER=development --env E2_DBSERV=localhost --name=e2devdb --net=e2-dev-net everything2/e2db

