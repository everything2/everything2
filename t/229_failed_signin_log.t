#!/usr/bin/perl -w
#
# Failed password sign-ins are written to the security log (Security Monitor: "Failed
# sign-ins"): one row per failure, with the account tried (or none) and the client address,
# never the password or an unknown attempted name. Successful sign-ins and stale cookies
# add nothing.
#
# Runs the real PSGI app in-process. Each run sends its own X-Forwarded-For address (TEST-NET
# 203.0.113.0/24), so its rows can't be confused with other tests'.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5 /var/everything/t/lib);
use Test::More;
use Plack::Util;
use Plack::Test;
use HTTP::Request::Common;
use URI::Escape;
use JSON;
use Everything;
use Everything::SecurityLog;
use TestSeed;

chdir '/var/everything';
my $test = Plack::Test->create(Plack::Util::load_psgi('/var/everything/app.psgi'));
$test->request(GET '/api/sessions');   # boot the app

my $DB    = $Everything::DB;
my $APP   = $Everything::APP;
my $EVENT = Everything::SecurityLog::SECLOG_FAILED_SIGNIN();
my $guest = $Everything::CONF->guest_user;
ok($DB, 'app booted');

my $ip      = '203.0.113.' . ( 1 + $$ % 250 );
my $account = TestSeed::make_user($DB, $APP, label => 'signin', password => 'blah');
ok($account, 'test account exists');
END { TestSeed::cleanup($DB) }
my $name = $account->{title};

sub sign_in {
  my ($username, $password) = @_;
  return $test->request(POST '/api/sessions/create', 'X-Forwarded-For' => $ip,
    'Content-Type' => 'application/json', Content => encode_json({ username => $username, passwd => $password }));
}
my ($start) = $DB->sqlSelect('MAX(seclog_id)', 'seclog');
sub rows_since {
  my ($from) = @_;
  my $quoted = $DB->quote("$ip%");
  return @{ $DB->{dbh}->selectall_arrayref(
    "SELECT seclog_user, seclog_subject, seclog_details FROM seclog
      WHERE seclog_event = $EVENT AND seclog_id > $from AND seclog_details LIKE $quoted ORDER BY seclog_id",
    { Slice => {} }) };
}
sub mark { my ($id) = $DB->sqlSelect('MAX(seclog_id)', 'seclog'); return $id // 0 }

subtest 'a wrong password is logged once, with the account and address' => sub {
  my $from = mark();
  my $res = sign_in($name, 'not-the-password-7x');
  is($res->code, 403, 'sign-in refused');
  my @rows = rows_since($from);
  is(scalar(@rows), 1, 'one security log row');
  is($rows[0]{seclog_subject}, $account->{node_id}, 'subject: the account tried');
  is($rows[0]{seclog_user}, $guest, 'recorded as Guest User');
  is($rows[0]{seclog_details}, $ip, 'details: the client address');
  unlike(join(' ', map { $_ // '' } %{ $rows[0] }), qr/not-the-password/, 'no password anywhere in the row');
};

subtest 'an unknown username is logged without the name' => sub {
  my $from = mark();
  my $name = 'no-such-user-' . $$;
  my $res = sign_in($name, 'whatever-password');
  is($res->code, 403, 'sign-in refused');
  my @rows = rows_since($from);
  is(scalar(@rows), 1, 'one security log row');
  ok(!defined $rows[0]{seclog_subject}, 'no subject');
  is($rows[0]{seclog_details}, "$ip (no such account)", 'details: address, no such account');
  unlike($rows[0]{seclog_details}, qr/\Q$name\E|whatever-password/, 'neither the attempted name nor the password');
};

subtest 'a successful sign-in and a stale cookie add nothing' => sub {
  my $from = mark();
  is(sign_in($name, 'blah')->code, 200, 'right password signs in');
  my $stale = 'userpass=' . uri_escape("$name|not-the-current-hash");
  $test->request(GET '/api/sessions', 'X-Forwarded-For' => $ip, Cookie => $stale);
  is(scalar(rows_since($from)), 0, 'no security log rows');
};

subtest 'Security Monitor lists the new category' => sub {
  my ($entry) = grep { $_->{key} eq 'FAILED_SIGNIN' } @{ $APP->seclog_event_counts };
  ok($entry, 'FAILED_SIGNIN is in the counts');
  is($entry && $entry->{name}, 'Failed sign-ins', 'named "Failed sign-ins"');
  cmp_ok($entry ? $entry->{count} : 0, '>=', 2, 'counting the rows written above');
};

done_testing();
