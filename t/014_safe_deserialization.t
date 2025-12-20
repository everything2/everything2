#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything::Serialization qw(safe_deserialize_dumper);

# Test basic hash deserialization
{
    my $data = q{$VAR1 = { 'key1' => 'value1', 'key2' => 'value2' };};
    my $result = safe_deserialize_dumper($data);

    ok($result, "Deserialized basic hash");
    is($result->{key1}, 'value1', "Key1 has correct value");
    is($result->{key2}, 'value2', "Key2 has correct value");
}

# Test with 'my' prefix
{
    my $data = q{my $VAR1 = { 'name' => 'test', 'count' => 42 };};
    my $result = safe_deserialize_dumper($data);

    ok($result, "Deserialized with 'my' prefix");
    is($result->{name}, 'test', "Name field correct");
    is($result->{count}, 42, "Count field correct");
}

# Test nested structures
{
    my $data = q{$VAR1 = { 'outer' => { 'inner' => 'value' }, 'array' => [1, 2, 3] };};
    my $result = safe_deserialize_dumper($data);

    ok($result, "Deserialized nested structure");
    is($result->{outer}->{inner}, 'value', "Nested hash access works");
    is_deeply($result->{array}, [1, 2, 3], "Array field correct");
}

# Test empty data
{
    my $result = safe_deserialize_dumper('');
    ok(!defined $result, "Empty string returns undef");
}

# Test undef
{
    my $result = safe_deserialize_dumper(undef);
    ok(!defined $result, "Undef returns undef");
}

# Test that dangerous operations are blocked
{
    my $dangerous = q{$VAR1 = { 'cmd' => `whoami` };};

    # Suppress expected warnings from Safe compartment
    local $SIG{__WARN__} = sub {};
    my $result = safe_deserialize_dumper($dangerous);

    ok(!defined $result, "Dangerous backtick operation blocked");
}

# Test that system calls are blocked
{
    my $dangerous = q{system('echo test'); $VAR1 = {};};

    # Suppress expected warnings from Safe compartment
    local $SIG{__WARN__} = sub {};
    my $result = safe_deserialize_dumper($dangerous);

    ok(!defined $result, "System call blocked");
}

# Test complex node-like data structure
{
    my $data = q{$VAR1 = {
        'node_id' => 12345,
        'title' => 'Test Node',
        'type_nodetype' => 117,
        'author_user' => 100,
        'createtime' => '2025-01-15',
        'doctext' => 'This is some content',
        'reputation' => 42
    };};

    my $result = safe_deserialize_dumper($data);

    ok($result, "Deserialized node-like structure");
    is($result->{node_id}, 12345, "Node ID correct");
    is($result->{title}, 'Test Node', "Title correct");
    is($result->{reputation}, 42, "Reputation correct");
}

done_testing;
