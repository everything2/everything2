#!/usr/bin/perl

use Getopt::Long;
use strict;
use CPAN;
use CPAN::Version;
use Data::Dumper;
use Dist::Metadata;
require local::lib;
my %opts;

GetOptions(\%opts,  'i=s','m=s', 'v=s', 't=s', 'f=s', 'l=s', 'd', 'o=s');

unless (keys %opts){
 usage();
 exit(1)
}


local::lib->import($opts{i}) if $opts{i};

if ($opts{d}){

  print join "\n", @INC;
  exit(1)

}

if ($opts{o}){
    open F, ">", $opts{o} or die $!;
    select F;
}


sub usage {
 print "chef-cpan-install.pl -i <install-base> -m <module-name> -v <version> -t <install-type> -f <cpan-flags> -o <log_file> [-d]";
 print "\n";
}


sub install_cpan_module {

  if (not defined($opts{v}))  { # not install if uptodate
      print "version required : highest\n";
      unless(CPAN::Shell->expand('Module',$opts{m})->uptodate){ 
        install($opts{m}, $opts{f});
      }else{ 
    	    print "$opts{m} -- OK is uptodate : ".(CPAN::Shell->expand('Module',$opts{m})->inst_version)."\n" 
        }
  } elsif ( $opts{v} eq '0') { # not install if any version already installed
      print "version required : any\n";
      if(my $v = CPAN::Shell->expand('Module',$opts{m})->inst_version){
        print "$opts{m} -- OK already installed ($v) \n" 
      }else{ 
        install($opts{m}, $opts{f});
     }
  } elsif ($opts{v} ne '0') { # not install if have higher or equal version
      print "version required : $opts{v}\n";
      my $inst_v = CPAN::Shell->expand("Module",$opts{m})->inst_version;
      unless ( CPAN::Version->vcmp($inst_v, $opts{v}) >= 0 ) {
        install($opts{m}, $opts{f});
      } else { 
    	print "$opts{m} -- OK have higher or equal version [$inst_v]"  
     }
  } else {
      die  "bad version : $opts{v}";
  }

}

sub install_tarball {

  my $dist = Dist::Metadata->new(file => $opts{m});
  my $dist_name = $dist->name;;
  my $cpan_dist = CPAN::Shell->expand("Distribution","/\/$dist_name-.*\.tar\.gz/");
  my $res;
  eval{ 
    for my $m ($cpan_dist->containsmods) { 
     my $cpan_mod = CPAN::Shell->expand("Module", $m);
     eval { 
        $res = CPAN::Version->vcmp($dist->version,$cpan_mod->inst_version);
     }; next if $@;
    if ($res == 0) {
      print " -- OK : exact version already installed \n"; return } 
    } 
  };
  install('.',$opts{f});
}

sub install_application {
  install('.',$opts{f});
}

sub install {
 my $thing = shift;
 my $flags = shift;
 if ($flags=~/t/){
  CPAN::Shell->test($thing) 
 }else{
  $flags=~/f/ ? CPAN::Shell->force('install',$thing) :  CPAN::Shell->install($thing);
 }
}

if ($opts{t} eq 'cpan_module'){
 install_cpan_module
}elsif($opts{t} eq 'tarball'){
 install_tarball
}elsif($opts{t} eq 'application'){
 install_application
}else{
 die "unknown install_type: $opts{t}"
}
