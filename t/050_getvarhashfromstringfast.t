#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Test::Deep;
use Everything;

initEverything 'everything';

unless($APP->inDevEnvironment())
{
  plan skip_all => "Not in the development environment";
  exit;
}

# Test 1: Normal well-formed var string
{
  my %result = $APP->getVarHashFromStringFast('key1=value1&key2=value2');
  cmp_deeply(\%result, {
    key1 => 'value1',
    key2 => 'value2'
  }, "Normal well-formed var string");
}

# Test 2: Empty value (key=&key2=value)
{
  my %result = $APP->getVarHashFromStringFast('key1=&key2=value2');
  cmp_deeply(\%result, {
    key1 => '',
    key2 => 'value2'
  }, "Empty value handled correctly");
}

# Test 3: Multiple empty values
# Note: Perl's split() doesn't include trailing empty fields by default
# So 'var3=' becomes ['var1','','var2','1','var3'] (5 elements, odd)
# The orphan 'var3' is discarded
{
  my %result = $APP->getVarHashFromStringFast('var1=&var2=1&var3=');
  cmp_deeply(\%result, {
    var1 => '',
    var2 => '1'
  }, "Multiple empty values handled correctly (trailing = creates orphan)");
}

# Test 4: Odd number of elements (malformed - missing value at end)
{
  my %result = $APP->getVarHashFromStringFast('key1=value1&key2');
  cmp_deeply(\%result, {
    key1 => 'value1'
  }, "Malformed string with orphan key discarded");
}

# Test 5: Undefined var string
{
  my %result = $APP->getVarHashFromStringFast(undef);
  cmp_deeply(\%result, {}, "Undefined var string returns empty hash");
}

# Test 6: Empty string
{
  my %result = $APP->getVarHashFromStringFast('');
  cmp_deeply(\%result, {}, "Empty string returns empty hash");
}

# Test 7: URL-encoded values
{
  my %result = $APP->getVarHashFromStringFast('key1=hello%20world&key2=test%2Fpath');
  cmp_deeply(\%result, {
    key1 => 'hello world',
    key2 => 'test/path'
  }, "URL-encoded values decoded correctly");
}

# Test 8: Plus signs converted to spaces
{
  my %result = $APP->getVarHashFromStringFast('key1=hello+world&key2=foo+bar+baz');
  cmp_deeply(\%result, {
    key1 => 'hello world',
    key2 => 'foo bar baz'
  }, "Plus signs converted to spaces");
}

# Test 9: Single space value becomes empty string
{
  my %result = $APP->getVarHashFromStringFast('key1=+&key2=value');
  cmp_deeply(\%result, {
    key1 => '',
    key2 => 'value'
  }, "Single space converted to empty string");
}

# Test 10: Leading & creates odd elements (discards last element)
# '&key1=value1&key2=value2' -> ['','key1','value1','key2','value2'] (5 elements, odd)
# Discards 'value2', leaving {'' => 'key1', 'value1' => 'key2'}
{
  my %result = $APP->getVarHashFromStringFast('&key1=value1&key2=value2');
  # This creates malformed hash due to odd elements - expect empty key
  ok(exists $result{''}, "Leading & creates empty key");
  is($result{''}, 'key1', "Empty key has 'key1' as value");
  ok(exists $result{'value1'}, "Has 'value1' key");
  is($result{'value1'}, 'key2', "'value1' key has 'key2' as value");
}

# Test 11: Trailing &
{
  my %result = $APP->getVarHashFromStringFast('key1=value1&key2=value2&');
  # Trailing & creates orphan empty key that should be discarded
  cmp_deeply(\%result, {
    key1 => 'value1',
    key2 => 'value2'
  }, "Trailing & discarded (creates orphan empty key)");
}

# Test 12: Complex real-world example
{
  my %result = $APP->getVarHashFromStringFast('nodelets=263%2C1916651&theme=default&favorite_limit=15');
  cmp_deeply(\%result, {
    nodelets => '263,1916651',
    theme => 'default',
    favorite_limit => '15'
  }, "Complex real-world var string");
}

done_testing();
