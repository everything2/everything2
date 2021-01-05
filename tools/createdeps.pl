#!./install/bin/perl

use strict;
use JSON::PP;
use Getopt::Long;
use Config;

my $depfile;
my $installdir;
my $skipverify = [];
my $builddir;
my $dldir;

GetOptions(
  "depfile=s" => \$depfile,
  "installdir=s" => \$installdir,
  "builddir=s" => \$builddir,
  "dldir=s" => \$dldir,
  "skipverify=s" => $skipverify
);

$dldir = `pwd`."3rd" if not defined $dldir;
$builddir = `pwd`."build" if not defined $builddir;
my $relocatable_install;

if(not defined $installdir)
{
  $relocatable_install=1;
  $installdir = $^X;
  $installdir =~ s/bin\/perl//;
}

my $dyld = "DYLD_LIBRARY_PATH=$installdir/lib";
$depfile = '' if not defined($depfile);

unless(-e $depfile)
{
  print "Could not open dependences file: $depfile";
  exit 1;
}

my $filedata;
if(open(my $fh, "<", $depfile))
{
  local $/ = undef;
  $filedata = <$fh>;
  close $fh;
}

my $dependencies = JSON::PP->new->utf8->decode($filedata);

sub test_module
{
  my ($module) = @_;

  my $incdir = "-I$installdir/lib/perl5";
  if($relocatable_install)
  {
    $incdir=""
  }
  print "Testing module $module...";
  my $command = "$dyld $^X $incdir -e 'use $module' 2>&1";
  my $output = `$command`;
  chomp $output;

  if($output eq '')
  {
    print "passed\n";
  }else{
    print "failed!\n";
    print "Command output: $output";
    return 0;
  }
  return 1;
}


foreach my $dep (@$dependencies)
{
  if($dep->{skip})
  {
    next;
  }

  print "Building '$dep->{module}'\n";

  if($dep->{removecore})
  {
    print "Cannot do initial test for '$dep->{module}' as we have to remove the core first\n";
  }elsif(test_module($dep->{module}) and !$dep->{skiptest})
  {
    print "Module '$dep->{module}' already working, skipping\n\n";
    next;
  }

  my ($destfile) = $dep->{file} =~ /\/([^\/]+)$/;
  my $inc = $dep->{inc} || "";
  $inc =~ s/\$INSTALL/$installdir/g;
  $inc = "INC=\"$inc\"" if $inc ne "";

  my $extra = $dep->{extra} || "";

  if($dep->{removecore})
  {
    print "Removing core modules: $$dep{module}.pm\n";
    my $modpath = $$dep{module};
    $modpath =~ s/::/\//g;
    my $command = "find $installdir/lib/perl5 -path '*/$modpath.pm' -type f -exec rm -f {} \\; 2>&1";
    print "Running command: '$command'\n";
    print `$command`;
  }

  if(-e "$dldir/$destfile")
  {
    print "File '$destfile' already downloaded, skipping\n";
  } else {
    print "Downloading '$destfile'\n";
    `cd $dldir && wget $dep->{file}`;
  }

  my $regex = qr/^(.+)\.(tar\.|tgz)/;
  $regex = $dep->{dirname} if exists $dep->{dirname};
  my ($untardir) = $destfile =~ $regex;

  if(-d "$builddir/$untardir")
  {
    print "Build directory already created, skipping\n";
  }else{
    `cd $builddir && tar xzvf $dldir/$destfile` 
  }

  my $command = "";

  my $prefix=$installdir;
  my $installdirs="site";
  my $destdir=$installdir;
  my $mm_installargs = "INSTALL_BASE=$installdir";
  my $mb_installargs = "--install_base=$installdir";
  my $mm_destdircmd = "";
  my $includedir = "-I$installdir/lib/perl5";

  if($relocatable_install)
  {
    $prefix="/";
    $installdirs="vendor";
    $mm_installargs="PREFIX=$prefix INSTALLDIRS=$installdirs";
    $mb_installargs="--prefix=$prefix --installdirs=$installdirs --destdir=$destdir";
    $mm_destdircmd="DESTDIR=$destdir";
    $includedir="";
  }

  if(-e "$builddir/$untardir/Makefile.PL")
  {
    print "Using MakeMaker for '$dep->{module}'\n";
    $command = "cd $builddir/$untardir/ && $dyld PERL_MM_USE_DEFAULT=1 NO_NETWORK_TESTING=1 $^X $includedir Makefile.PL $mm_installargs $inc $extra && make && make install $mm_destdircmd";
  }elsif(-e "$builddir/$untardir/Build.PL")
  {
    print "Using Module::Build for '$dep->{module}'\n";
    $command = "cd $builddir/$untardir/ && NO_NETWORK_TESTING=1 $^X $includedir Build.PL $mb_installargs && $^X $includedir ./Build && $^X $includedir ./Build install";
  }else{
    print "Could not find builder in: '$builddir/$untardir/'\n";
    exit 1;
  }
  print "Running '$command'\n";
  print `$command`;


  next if $dep->{skiptest};
  next if grep(/^$dep->{module}$/, @$skipverify);
  exit 1 unless(test_module($dep->{module}));

  print "\n";
}
