#!/usr/bin/perl -w

# A deleted account's tomb copy keeps no credentials, and a resurrected account has to reset its
# password (#4716).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Data::Dumper;
use Everything;
use Everything::Serialization qw(safe_deserialize_dumper);
use Everything::Page::the_node_crypt;
use Everything::API::resurrect;
use MockRequest;
use TestSeed;

initEverything('development-docker');
my $DB  = $Everything::DB;
my $APP = $Everything::APP;

my $root = $DB->getNode('root', 'user');
my $JOB  = "$FindBin::Bin/../tools/jobs/tomb_strip_credentials.pl";
my @CREDENTIALS = qw(passwd salt user_salt validationkey session_id);
my @tombed;

END {
    if ($DB) {
        for my $id (@tombed) {
            if (my $n = $DB->getNodeById($id, 'force')) { $DB->nukeNode($n, -1, 1) }
            $DB->sqlDelete('tomb', 'node_id=' . int($id));
        }
        TestSeed::cleanup($DB);
    }
}

sub member {
    my ($label) = @_;
    my $u = TestSeed::make_user($DB, $APP, label => $label, password => 'oldsecret1',
        email => "$label$$\@test.example.com", lasttime => '2011-05-06 07:08:09');
    $DB->sqlUpdate('user', { validationkey => 'akey', session_id => 42, user_salt => 7 },
        'user_id=' . int($u->{node_id}));
    push @tombed, $u->{node_id};
    return $DB->getNodeById($u->{node_id}, 'force');
}

sub tomb_copy {
    my ($id) = @_;
    my $row = $DB->sqlSelectHashref('*', 'tomb', 'node_id=' . int($id)) or return;
    return safe_deserialize_dumper('my ' . $row->{data});
}

sub user_row {
    my ($id) = @_;
    return $DB->sqlSelectHashref('*', 'user JOIN node ON node_id=user_id', 'user_id=' . int($id));
}

# The account as a tomb copy written before this change: credentials included.
sub plant_old_copy {
    my ($user, %extra) = @_;
    my %data = (
        nick => $user->{title}, email => $user->{email}, lasttime => $user->{lasttime},
        passwd => $user->{passwd}, salt => $user->{salt}, validationkey => 'akey',
        session_id => 42, user_salt => 7, %extra,
    );
    $DB->sqlInsert('tomb', {
        node_id => $user->{node_id}, type_nodetype => $user->{type_nodetype}, title => $user->{title},
        author_user => $user->{node_id}, killa_user => $root->{node_id}, createtime => $user->{createtime},
        data => Data::Dumper->Dump([\%data]),
    });
    return;
}

subtest "a deleted account's tomb copy keeps no credentials" => sub {
    my $user = member('gone');
    ok($DB->nukeNode($user, $root), 'the account is deleted');
    my $copy = tomb_copy($user->{node_id});
    ok($copy, 'and has a tomb copy');
    ok(!exists $copy->{$_}, "without $_") for @CREDENTIALS;
    is($copy->{email}, $user->{email}, 'it keeps the email address, where a reset link goes');
    is($copy->{lasttime}, '2011-05-06 07:08:09', 'and the last login time');
};

subtest 'a resurrected account has no usable password until it is reset' => sub {
    my $id   = $tombed[0];
    my $back = $DB->resurrectNode($id);
    ok($back, 'the account is resurrected');
    my $row = user_row($id);
    is($row->{passwd}, $APP->NO_PASSWORD, 'it has no password');
    ok(length($row->{salt} // ''), 'and a salt, so a reset can set one');
    is($APP->password_kind($row), 'none', 'nothing can sign in to it');
    ok(!$APP->check_password($row, 'oldsecret1'), 'the old password does not work');
    is($row->{lasttime}, '2011-05-06 07:08:09', 'its last login time is as it was');
    is($row->{email}, "gone$$\@test.example.com", 'and its email address');

    my $expiry = time() + 600;
    my $link = $APP->getTokenLinkParameters($row, 'newsecret2', 'reset', $expiry);
    ok($APP->checkToken($row, 'reset', $expiry, 'newsecret2', $link->{token}), 'a reset link works');
    ok($APP->check_password(user_row($id), 'newsecret2'), 'and the new password signs in');
};

subtest 'an account whose tomb copy still has its credentials comes back without them' => sub {
    my $user = member('older');
    $DB->nukeNode($user, $root, 1);
    plant_old_copy($user);
    ok($DB->resurrectNode($user->{node_id}), 'the account is resurrected');
    my $row = user_row($user->{node_id});
    is($row->{passwd}, $APP->NO_PASSWORD, 'it has no password');
    isnt($row->{salt}, $user->{salt}, 'and a new salt');
    ok(!$APP->check_password($row, 'oldsecret1'), 'the old password does not work');
    ok(!$row->{validationkey}, 'and no old validation key');
};

subtest 'The Node Crypt does not show credential fields' => sub {
    my $user = member('crypt');
    $DB->nukeNode($user, $root, 1);
    plant_old_copy($user);
    my $page = Everything::Page::the_node_crypt->new->_view_coffin($DB, $user->{node_id}, 0);
    my %shown = map { $_->{key} => $_->{value} } @{ $page->{fields} || [] };
    ok(%shown, 'the coffin lists fields');
    ok(!exists $shown{$_}, "not $_") for @CREDENTIALS;
    is($shown{email}, $user->{email}, 'the email address is shown');
};

subtest "Dr. Nate's Secret Lab says a resurrected account needs a password reset" => sub {
    my $api = Everything::API::resurrect->new;
    my $as_admin = sub {
        my ($id) = @_;
        my $req = MockRequest->new(node_id => $root->{node_id}, title => $root->{title}, nodedata => $root,
            is_guest_flag => 0, is_admin_flag => 1, postdata => { node_id => $id, source => 'tomb' });
        return $api->resurrect_node($req)->[1];
    };

    my $user = member('lab');
    $DB->nukeNode($user, $root);
    my $r = $as_admin->($user->{node_id});
    ok($r->{success}, 'the account is resurrected') or diag explain $r;
    ok(${ $r->{passwordResetNeeded} }, 'and the response says it needs a password reset');

    my $doc = $DB->insertNode("Tomb creds lab doc $$", 'document', $root, { doctext => 'x' });
    push @tombed, $doc;
    $DB->nukeNode($DB->getNodeById($doc, 'force'), $root);
    $r = $as_admin->($doc);
    ok($r->{success}, 'a document is resurrected');
    ok(!${ $r->{passwordResetNeeded} }, 'and needs no reset');
};

subtest 'the cleanup job strips credentials from deleted-account copies' => sub {
    my $user = member('job');
    $DB->nukeNode($user, $root, 1);
    plant_old_copy($user);
    my $id = $user->{node_id};
    my $doc = $DB->insertNode("Tomb creds doc $$", 'document', $root, { doctext => 'x' });
    push @tombed, $doc;
    $DB->nukeNode($DB->getNodeById($doc, 'force'), $root);
    my $doc_before = $DB->sqlSelect('data', 'tomb', 'node_id=' . int($doc));

    my $env = "E2_TOMB_ONLY=$id,$doc";
    my $dry = `$env perl $JOB 2>&1`;
    is($? >> 8, 0, 'the dry run succeeds') or diag $dry;
    like($dry, qr/1 deleted-account cop(?:y|ies) with credentials/, 'it counts the copy');
    like($dry, qr/dry run/i, 'and says nothing was changed');
    unlike($dry, qr/\Q$user->{passwd}\E|\Q$user->{salt}\E|akey/, 'stored values are never printed');
    ok(exists tomb_copy($id)->{passwd}, 'the copy is unchanged');

    my $apply = `$env E2_APPLY=1 perl $JOB 2>&1`;
    is($? >> 8, 0, 'applying succeeds') or diag $apply;
    my $copy = tomb_copy($id);
    ok(!exists $copy->{$_}, "the copy no longer has $_") for @CREDENTIALS;
    is($copy->{email}, $user->{email}, 'it keeps the email address');
    is($copy->{lasttime}, $user->{lasttime}, 'and everything else');
    is($DB->sqlSelect('data', 'tomb', 'node_id=' . int($doc)), $doc_before, 'other tomb copies are untouched');

    my $again = `$env E2_APPLY=1 perl $JOB 2>&1`;
    is($? >> 8, 0, 'a second run succeeds') or diag $again;
    like($again, qr/0 deleted-account copies with credentials/, 'and finds nothing to do');
};

subtest 'the cleanup job handles copies with non-ASCII text' => sub {
    my $nick = "Andr\x{e9}";        # Latin-1 only: an escape for it reads back without the UTF-8 flag
    my $realname = "\x{263a} Andr\x{e9}";
    utf8::upgrade($_) for $nick, $realname;
    # Older copies hold the characters literally; Data::Dumper writes them as \x{} escapes.
    for my $form (qw(literal escaped)) {
        my $user = member("u8$form");
        my $id   = $user->{node_id};
        $DB->nukeNode($user, $root, 1);
        my %data = (
            nick => $nick, realname => $realname, email => $user->{email}, lasttime => $user->{lasttime},
            passwd => $user->{passwd}, salt => $user->{salt}, validationkey => 'akey',
            session_id => 42, user_salt => 7,
        );
        my $text;
        if ($form eq 'literal') {
            my %bytes = %data;
            utf8::encode($bytes{$_}) for qw(nick realname);
            $text = Data::Dumper->Dump([\%bytes]);
            utf8::decode($text);
            ok($text !~ /\\x\{/ && $text =~ /\x{e9}/, 'the copy holds the characters literally');
        } else {
            $text = Data::Dumper->Dump([\%data]);
            like($text, qr/\\x\{/, 'the copy holds the characters as escapes');
        }
        $DB->sqlInsert('tomb', {
            node_id => $id, type_nodetype => $user->{type_nodetype}, title => $user->{title},
            author_user => $id, killa_user => $root->{node_id}, createtime => $user->{createtime},
            data => $text,
        });

        my $out = `E2_TOMB_ONLY=$id E2_APPLY=1 perl $JOB 2>&1`;
        is($? >> 8, 0, "$form: applying succeeds") or diag $out;
        unlike($out, qr/could not be read/, "$form: the copy is read");
        my $copy = tomb_copy($id);
        ok(!exists $copy->{$_}, "$form: the copy no longer has $_") for @CREDENTIALS;
        is($copy->{nick}, $nick, "$form: the nick is unchanged");
        is($copy->{realname}, $realname, "$form: and the real name");
        is($copy->{email}, $user->{email}, "$form: and the email address");

        my $again = `E2_TOMB_ONLY=$id E2_APPLY=1 perl $JOB 2>&1`;
        like($again, qr/0 deleted-account copies with credentials/, "$form: a second run finds nothing to do");
    }
};

done_testing();
