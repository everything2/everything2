class cpan-config {
  package {'libyaml-perl':
    ensure => present,
  }

  file { '/etc/perl/CPAN/Config.pm' :
    source => '/config/Config.pm',
    require => Package['libyaml-perl'],
  }
}

class cpan-modules {
  define install-cpan() {
    exec{"cpan_load_${title}":
      command => "perl -MCPAN -e '\$ENV{PERL_MM_USE_DEFAULT}=1; CPAN::Shell->install(\"${name}\")'",
      cwd     => '/root',
      path    => '/usr/bin:/usr/sbin:/bin:/sbin',
      #onlyif  => "test `perl -M${title} -e 'print 1' 2>/dev/null || echo 0` == '0'",
    }
  }
  
  install-cpan {"Mail::Sender": }
  install-cpan {"Mail::Internet": }
  install-cpan {"String::Similarity": }

}

class apache2 {
  package {['apache2-mpm-prefork','libapache2-mod-perl2']:
    ensure => present,
  }

  file { '/etc/apache2/conf.d/everything' :
    source => '/config/everything',
    require => Package['libapache2-mod-perl2'],
  }
  
  file { '/etc/apache2/conf.d/everything_rewrite.conf' :
    source => '/config/mod_rewrite.conf',
    require => Package['libapache2-mod-perl2'],
  }

  file { ['/usr/','/usr/local','/usr/local/everything'] :
    mode => 0755,
    ensure => directory
    recurse => true
  }

  service {'apache2':
    ensure  => running,
    require => Package['apache2-mpm-prefork','libapache2-mod-perl2'],
  }
}

class mysqld {
  package {'mysql-server':
    ensure => present,
  }

  service {'mysqld':
    ensure  => running,
    require => Package['mysql-server'],
  }
}

class tools {
  package{ ['vim','strace','libapache-db-perl','libdevel-nytprof-perl']: 
    ensure => present
  }
}

class perl-modules {
  package { [
    'libalgorithm-diff-perl',
    'libarchive-zip-perl',
    'libcgi-pm-perl',
    'libcache-perl',
    'libcache-memcached-perl',
    'libcaptcha-recaptcha-perl',
    'libconfig-simple-perl',
    'libdbi-perl',
    'libdate-calc-perl',
    'libdatetime-perl',
    'libdatetime-format-strptime-perl',
    'libdigest-md5-perl',
    'libdigest-sha1-perl',
    'libhtml-tiny-perl',
    'libheap-perl',
    'libio-string-perl',
    'libimage-magick-perl',
    'libjson-perl',
    'libxml-generator-perl',
    'libxml-simple-perl']:
    ensure => installed
  }
}

class mercurial
{
  package { ['mercurial']:
    ensure => installed
  }
}

include apache2
include mysqld
include tools
include perl-modules
include cpan-config
include cpan-modules
include mercurial
