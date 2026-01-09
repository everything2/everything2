#!/usr/bin/perl -w

use strict;
use warnings;
use Everything;
use Paws;
package Everything::S3;

sub new
{
	my ($class, $s3type) = @_;

	return if not defined $s3type;
	my $this = {};
	if(exists($Everything::CONF->s3->{$s3type}))
	{
		foreach my $value (qw/bucket/)
		{
			if(defined($Everything::CONF->s3->{$s3type}->$value))
			{
				$this->{$value} = $Everything::CONF->s3->{$s3type}->$value;
			}
		}
	}else{
		return;
	}

	# Suppress DIE handler for Paws calls - internal eval errors shouldn't trigger global handler
	local $SIG{__DIE__} = sub { };
	$this->{s3} = eval { Paws->service('S3', region => $Everything::CONF->current_region) };
	return unless defined($this->{s3});

	return bless $this,$class;
}

sub upload_data
{
	my ($this, $name, $data, $properties) = @_;

	my @ct = ();
	if(exists($properties->{content_type}))
	{
          @ct = (ContentType => $properties->{content_type});
	}
	# Suppress DIE handler for Paws calls
	local $SIG{__DIE__} = sub { };
	return eval { $this->{s3}->PutObject(Bucket => $this->{bucket}, Key => $name, Body => $data, @ct) };
}

sub upload_file
{
	my ($this, $name, $filename, $properties) = @_;

        my ($filedata, $filehandle) = (undef, undef);
        if(open($filehandle, "<", $filename))
	{
          local $/ = undef;
	  $filedata = <$filehandle>;
	  close $filehandle;
	}else{
          return;
        }
	return $this->upload_data($name, $filedata, $properties);
}

sub delete_key
{
	my ($this, $name) = @_;
	# Suppress DIE handler for Paws calls
	local $SIG{__DIE__} = sub { };
	return eval { $this->{s3}->DeleteObject(Bucket => $this->{bucket}, Key => $name) };
}

sub get_key
{
	my ($this, $key) = @_;
	# Suppress DIE handler for Paws calls
	local $SIG{__DIE__} = sub { };
	if(my $get_object_output = eval { $this->{s3}->GetObject(Bucket => $this->{bucket}, Key => $key) })
	{
          return $get_object_output->Body;
	}
}

1;
