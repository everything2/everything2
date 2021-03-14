#!/usr/bin/perl -w

use strict;
use warnings;
use Everything;
use Net::Amazon::S3;
package Everything::S3;

sub new
{
	my ($class, $s3type) = @_;
	
	return if not defined $s3type;
	my $this = {};
	if(exists($Everything::CONF->s3->{$s3type}))
	{
		foreach my $value (qw/bucket access_key_id secret_access_key use_iam_role/)
		{
			if(defined($Everything::CONF->s3->{$s3type}->$value))
			{
				$this->{$value} = $Everything::CONF->s3->{$s3type}->$value;
			}
		}
	}else{
		return;
	}

	my $s3host = $Everything::CONF->s3->{$s3type}->host || $Everything::CONF->s3host || 's3.amazonaws.com';
	if($this->{use_iam_role})
	{
		$this->{s3} = Net::Amazon::S3->new(
		{
			use_iam_role => 1,
			retry => 1,
			host => $s3host
		});
	}else{
		$this->{s3} = Net::Amazon::S3->new(
		{
			aws_access_key_id     => $this->{access_key_id},
			aws_secret_access_key => $this->{secret_access_key},
			retry                 => 1,
			host                  => $s3host
		});
	}

	return unless defined($this->{s3});
	$this->{bucket} = $this->{s3}->bucket($this->{bucket});

	return bless $this,$class;
}

sub upload_data
{
	my ($this, $name, $data, $properties) = @_;
	return $this->{bucket}->add_key($name, $data, $properties);
}

sub upload_file
{
	my ($this, $name, $filename, $properties) = @_;
	return $this->{bucket}->add_key_filename($name, $filename, $properties);
}

sub delete_key
{
	my ($this, $name) = @_;
	return $this->{bucket}->delete_key($name);
}

sub get_key
{
	my ($this, $key) = @_;
	return $this->{bucket}->get_key($key);
}

sub errstr
{
	my ($this) = @_;
	return $this->{bucket}->err .": ".$this->{bucket}->errstr;
}
1;
