# Developing inside of ecore

## Structure of the repository:

 * [cf](https://github.com/everything2/everything2/tree/master/cf) - CloudFormation templates
 * [cron](https://github.com/everything2/everything2/tree/master/cron) - Cron jobs, run in ECS, but can be simulated manually
 * [docker](https://github.com/everything2/everything2/tree/master/docker) - Docker images for production and development build
 * [docs](https://github.com/everything2/everything2/tree/master/docs) - Documentation
 * [ecore](https://github.com/everything2/everything2/tree/master/ecore) - Core Everything libraries
 * [ecoretool](https://github.com/everything2/everything2/tree/master/ecoretool) - Tool for importing and exporting database nodes
 * [etc](https://github.com/everything2/everything2/tree/master/etc) - Configuration items
 * [jobs](https://github.com/everything2/everything2/tree/master/jobs) - Manual processes run by operations on the server
 * [lambda](https://github.com/everything2/everything2/tree/master/lambda) - AWS Lambda functions for server glue
 * [nodepack](https://github.com/everything2/everything2/tree/master/nodepack) - Infrastructure nodes, exported to XML
 * [ops](https://github.com/everything2/everything2/tree/master/ops) - Scripts used in the operation of E2, not server utilities. Typically cloud
 * [serverless](https://github.com/everything2/everything2/tree/master/serverless) - E2 Perl Layer dependencies, previously lambda support
 * [templates](https://github.com/everything2/everything2/tree/master/templates) - Mason2 templates used for display purposes
 * [tools](https://github.com/everything2/everything2/tree/master/tools) - Some of the tools that keep the site glued together
 * [www](https://github.com/everything2/everything2/tree/master/www) - Basic web properties, icons and index.pl

# To start to develop for e2

 * Install Docker Desktop
 * From the main directory (re-)run ./docker/devbuild.sh
 * Visit http://localhost:9080

Make changes to the source directory and re-run ./docker/devbuild.sh to relaunch the container. The database won't be touched unless you explicitly run the corresponding devclean.sh script.

