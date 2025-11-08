#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

docker network inspect e2-dev-net >/dev/null 2>&1 || docker network create e2-dev-net

docker container stop e2devapp
docker rm e2devapp
docker image rm everything2/e2app
docker build -t everything2/e2app -f docker/e2app/Dockerfile .
docker run -d --publish 9080:80 --publish 443:9443 --env E2_DOCKER=development --env E2_DBSERV=e2devdb --name=e2devapp --net=e2-dev-net everything2/e2app

if [ "$1" = "full" ]; then
  $SCRIPT_DIR/devdbbuild.sh
fi

# Wait for container to be ready
echo ""
echo "Waiting for container to be ready..."
sleep 3

# Run tests
echo ""
echo "========================================="
echo "Running test suite..."
echo "========================================="
$SCRIPT_DIR/run-tests.sh

echo ""
echo "========================================="
echo "Build complete!"
echo "Application available at: http://localhost:9080"
echo "========================================="
