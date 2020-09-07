# Developing inside of ecore

## Structure of the repository:

 * [cf](https://github.com/everything2/everything2/tree/master/cf) - CloudFormation templates
 * [ecore](https://github.com/everything2/everything2/tree/master/ecore) - Core Everything libraries
 * [ecoretool](https://github.com/everything2/everything2/tree/master/ecoretool) - Tool for importing and exporting database nodes
 * [nodepack](https://github.com/everything2/everything2/tree/master/nodepack) - Infrastructure nodes, exported to XML
 * [ops](https://github.com/everything2/everything2/tree/master/ops) - Scripts used in the operation of E2, not server utilities. Typically cloud
 * [serverless](https://github.com/everything2/everything2/tree/master/serverless) - E2 Perl Layer for AWS Lambda
 * [tools](https://github.com/everything2/everything2/tree/master/tools) - Some of the tools that keep the site glued together
 * [vagrant](https://github.com/everything2/everything2/tree/master/vagrant) - Vagrant virtual machine setup, see below
 * [www](https://github.com/everything2/everything2/tree/master/www) - Basic web properties, icons and index.pl

## Bringing up your vagrant VM
To bring up the vagrant VM, you'll need a few things prepared to start off with:

 * Download and install [VirtualBox](https://www.virtualbox.org/)
 * Make sure you have a working ruby / gem setup
 * Running: `gem install vagrant`

Once that is up and running, you can boot up the vagrant virtual machine with
`vagrant up`

It will download the base box one time, and instantiate a test version of the virtual machine to help develop on. The box will create itself the same way every time, so if you mess it up, you can destroy it with `vagrant destroy`. If you wish to stop it, you can do so with `vagrant halt`

