DESCRIPTION
===========

[cpan](http://search.cpan.org/perldoc?CPAN) modules resource provider
  
PREREQUISITES
=============
  I assume you have a [cpan](http://search.cpan.org/perldoc?CPAN) client installed on your system. 
  Run recipe cpan_client::bootstrap to ensure this:
  
    include_recipe 'cpan_client::bootstrap'

## ATTRIBUTES used in bootstrap recipe

* `cpan.minimal_version` - minimal required version of cpan client 
* `cpan.download_url` - url to download fresh cpan client 

BASIC USAGE
===========
    include_recipe 'cpan'
    cpan_client 'CGI' do
        action 'install'
        install_type 'cpan_module'
        user 'root'
        group 'root'
    end

RESOURCE ACTIONS
================

* `install` - install module or application 
* `test` - test module, don't install it
* `reload_cpan_index` - reload cpan client indexes

RESOURCE ATTRIBUTES
===================

* `install_type` - whether to install as cpan module or as application : cpan_module, application; default - application
* `user` - a user name that we should change to before installing
* `group` - a group name that we should change to before installing
* `version` - a version of module, if 0 then install only if module does not exist, default nil
* `install_base` - install base for your installation 
* `install_path` - install path, array of install pathes
* `dry_run` - whether to run installation process in dryrun mode or not, default - false 
* `force` - whether to run installation process in force mode, default - false
* `from_cookbook` - whether to look up distributive in [cookbook file](http://wiki.opscode.com/display/chef/Resources#Resources-CookbookFile)
* `environment` - hash which holds environment vars exporting to installation process
* `cwd` - sets the current working directory before running installation process

EXAMPLES OF USAGE
=================

fake install
------------
    cpan_client 'CGI' do
        action 'install'
        install_type 'cpan_module'
        user 'root'
        group 'root'
        dry_run true 
    end



do not install, only run tests
------------------------------
    cpan_client 'CGI' do
        action 'test'
        install_type 'cpan_module'
        user 'root'
        group 'root'
    end



force install
-------------

    cpan_client 'CGI' do
        action 'install'
        install_type 'cpan_module'
        user 'root'
        group 'root'
        force true 
    end



install by version or higher
----------------------------

    cpan_client 'CGI' do
        action 'install'
        install_type 'cpan_module'
        user 'root'
        group 'root'
        version '3.55' 
    end


install only if module not exists
---------------------------------

    cpan_client 'CGI' do
        action 'install'
        install_type 'cpan_module'
        user 'root'
        group 'root'
        version '0' 
    end


install from tarball stored in cookbook
---------------------------------------

    cpan_client 'Moose-1.24.tar.gz' do
        action 'install'
        install_type 'cpan_module'
        user 'root'
        group 'root'
        from_cookbook  'moose'
    end

install into given install_base
-------------------------------

    cpan_client 'CGI' do
        action 'install'
        install_type 'cpan_module'
        user 'root'
        group 'root'
        install_base '/some/where/else'
    end


install into given install_base + cwd
-------------------------------------

    # would install into '/home/alex/mydir'
    cpan_client 'CGI' do
        action 'install'
        install_type 'cpan_module'
        user 'root'
        group 'root'
        install_base 'mydir'
        cwd '/home/alex/'
    end



install with given install_path
-------------------------------

    cpan_client 'Module' do
        action 'install'
        install_type 'cpan_module'
        user 'root'
        group 'root'
        install_path ["htdocs=#{ENV['PWD']}/htdocs/"]
    end

install application from current working directory
--------------------------------------------------

    cpan_client 'my application' do
        action 'install'
        user 'root'
        group 'root'
        install_type 'application'
    end

install under not privileged user
---------------------------------

    # would install into $PWD/cpanlib directory
    cpan_client 'my application' do
        action 'install'
        install_type 'application'
        user 'user'
        group 'users'
        install_base 'cpanlib'  
    end

reload cpan indexes
-------------------

    cpan_client 'reload cpan index' do
        action 'reload_cpan_index'
        user 'user'
        group 'users'
    end

