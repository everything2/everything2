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

# Real Data::Dumper output (as tombstoneNode writes it) reads back exactly
{
    use Data::Dumper;
    local $Data::Dumper::Sortkeys = 1;
    my $shared = { 'id' => 7 };
    my %node = (
        doctext   => "Line one\n'quoted' and \"double\" \\ backslash \$VAR1 sub { 1 } \x{e9}t\x{e9} \x{1F600}",
        negative  => -12, float => 3.25, nothing => undef, empty_h => {}, empty_a => [],
        group     => [ 1, 2, [ 3, { deep => 'yes' } ] ],
        first     => $shared, second => $shared,    # Dumper writes $VAR1->{...} for the repeat
        obj       => bless({ k => 'v' }, 'Some::Class'),
    );
    my $dump = Data::Dumper->Dump([\%node]);
    like($dump, qr/\$VAR1->/, 'fixture includes a back-reference');
    my $back = safe_deserialize_dumper('my ' . $dump);
    is_deeply({ %$back, first => undef, second => undef }, { %node, first => undef, second => undef },
        'every value reads back the same');
    is_deeply($back->{first}, { id => 7 }, 'the first copy of a repeated reference reads back');
    isa_ok($back->{obj}, 'Some::Class', 'a blessed value');
}

# Dumper's terse form (a bare structure, no "$VAR1 =")
{
    my $terse = "{\n  'totalvotes' => '',\n  'createdby_user' => 7392,\n  'e2node_id' => 2186552\n}\n";
    is_deeply(safe_deserialize_dumper('my ' . $terse), { totalvotes => '', createdby_user => 7392, e2node_id => 2186552 },
        'a terse copy reads back');
    is_deeply(safe_deserialize_dumper('[ 1, 2 ]'), [ 1, 2 ], 'a terse array reads back');
}

# Dumper writes code references as a placeholder; it reads back as undef
{
    my $dump = q{$VAR1 = { 'code' => 'return 1;', 'compiledCode' => sub { "DUMMY" }, 'z' => 1 };};
    my $back = safe_deserialize_dumper('my ' . $dump);
    ok($back, 'a copy with the placeholder reads back');
    ok(exists $back->{compiledCode} && !defined $back->{compiledCode}, 'the placeholder is undef');
    is($back->{code}, 'return 1;', 'other fields are intact');
    my $text = safe_deserialize_dumper(q{my $VAR1 = { 'doctext' => 'Dumper prints sub { "DUMMY" } for code' };});
    is($text->{doctext}, 'Dumper prints sub { "DUMMY" } for code', 'the same words inside a string are left alone');
}

# Only plain data is read: anything else comes back undef
{
    local $SIG{__WARN__} = sub { };
    my %not_data = (
        'reading a file'   => q{$VAR1 = { 'x' => do { open(my $fh, '<', '/dev/null'); 1 } };},
        'a file operation' => q{$VAR1 = { 'x' => unlink('/nonexistent/e2-test-path') };},
        'a signal'         => q{$VAR1 = { 'x' => kill(0, $$) };},
        'a sub'            => q{$VAR1 = { 'x' => sub { 1 } };},
        'calling a sub'    => q{$VAR1 = { 'x' => main::thing() };},
        'a method call'    => q{$VAR1 = { 'x' => Some::Class->new };},
        'a loop'           => q{$VAR1 = { 'x' => do { my $i = 0; $i++ while $i < 3; $i } };},
        'a pattern match'  => q{$VAR1 = { 'x' => ('abc' =~ /b/) };},
        'string eval'      => q{$VAR1 = { 'x' => eval '1' };},
        'loading a module' => q{$VAR1 = { 'x' => do { require POSIX; 1 } };},
    );
    for my $what (sort keys %not_data) {
        ok(!defined safe_deserialize_dumper($not_data{$what}), "not plain data: $what");
    }
}

done_testing;
