# Developing inside of ecore

** Note: It is important that you clone the repository with --recursive so that you get the submodules, otherwise you will not be able to instantiate a vagrant VM**

## Structure of the repository:

 * [ecore](https://github.com/everything2/everything2/tree/master/ecore) - Core Everything libraries
 * [nodepack](https://github.com/everything2/everything2/tree/master/nodepack) - Infrastructure nodes, exported to XML
 * [qa](https://github.com/everything2/everything2/tree/master/qa) - WebDriver based qa test suite, very empty
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

## Everything2's submodules
E2 submodules a few pieces of its project out so that it can be used in the sister project, perlmonks:

 * [cookbooks](https://github.com/everything2/cookbooks) - The cookbook files used by [chef](http://www.opscode.com/chef/)
 * [ecoretool](https://github.com/everything2/ecoretool) - The node to xml management utility
