#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Everything;

initEverything 'everything';
unless(!$APP->inDevEnvironment())
{
	plan skip_all => "Not in the production environment";
	exit;
}

ok(my $randomeditor = getNode('the custodian','user'));
ok(my $collaborator = getNode('Padlock','user'));
ok(my $randomadmin = getNode('mauler','user'));
ok(my $me = getNode('jaybonci','user'));
ok(my $GU = getNodeById($Everything::CONF->guest_user));

# 2070924 == jay's private draft
ok(my $private_draft = getNodeById(2070924));
foreach my $draft (2070924, $private_draft)
{
  ok($APP->canSeeDraft($me, $draft));
  ok($APP->canSeeDraft($me, $draft, 'edit'));
  ok($APP->canSeeDraft($me, $draft, 'find'));
   
  ok(!$APP->canSeeDraft($collaborator, $draft));
  ok(!$APP->canSeeDraft($collaborator, $draft, 'edit'));
  ok(!$APP->canSeeDraft($collaborator, $draft, 'find'));

  ok(!$APP->canSeeDraft($randomeditor, $draft));
  ok(!$APP->canSeeDraft($randomeditor, $draft, 'edit'));
  ok(!$APP->canSeeDraft($randomeditor, $draft, 'find'));

  ok(!$APP->canSeeDraft($randomadmin, $draft));
  ok(!$APP->canSeeDraft($randomadmin, $draft, 'edit'));
  ok(!$APP->canSeeDraft($randomadmin, $draft, 'find'));

  ok(!$APP->canSeeDraft($GU, $draft));
  ok(!$APP->canSeeDraft($GU, $draft, 'edit'));
  ok(!$APP->canSeeDraft($GU, $draft, 'find'));
}

# 2073427 == jay's public draft
ok(my $public_draft = getNodeById(2073427));
foreach my $draft (2073427, $public_draft)
{
  ok($APP->canSeeDraft($me, $draft));
  ok($APP->canSeeDraft($me, $draft, 'edit'));
  ok($APP->canSeeDraft($me, $draft, 'find'));
   
  ok($APP->canSeeDraft($collaborator, $draft));
  ok(!$APP->canSeeDraft($collaborator, $draft, 'edit'));
  ok($APP->canSeeDraft($collaborator, $draft, 'find'));

  ok($APP->canSeeDraft($randomeditor, $draft));
  ok(!$APP->canSeeDraft($randomeditor, $draft, 'edit'));
  ok($APP->canSeeDraft($randomeditor, $draft, 'find'));

  ok($APP->canSeeDraft($randomadmin, $draft));
  ok(!$APP->canSeeDraft($randomadmin, $draft, 'edit'));
  ok($APP->canSeeDraft($randomadmin, $draft, 'find'));

  ok(!$APP->canSeeDraft($GU, $draft));
  ok(!$APP->canSeeDraft($GU, $draft, 'edit'));
  ok(!$APP->canSeeDraft($GU, $draft, 'find'));
}

# 2073426 == jay's shared draft
ok(my $shared_draft = getNodeById(2073426));
foreach my $draft(2073426, $shared_draft)
{
  ok($APP->canSeeDraft($me, $draft));
  ok($APP->canSeeDraft($me, $draft, 'edit'));
  ok($APP->canSeeDraft($me, $draft, 'find'));

  ok($APP->canSeeDraft($collaborator, $draft));
  ok($APP->canSeeDraft($collaborator, $draft, 'edit'));
  ok($APP->canSeeDraft($collaborator, $draft, 'find'));

  ok(!$APP->canSeeDraft($randomeditor, $draft));
  ok(!$APP->canSeeDraft($randomeditor, $draft, 'edit'));
  ok(!$APP->canSeeDraft($randomeditor, $draft, 'find'));

  ok(!$APP->canSeeDraft($randomadmin, $draft));
  ok(!$APP->canSeeDraft($randomadmin, $draft, 'edit'));
  ok(!$APP->canSeeDraft($randomadmin, $draft, 'find'));

  ok(!$APP->canSeeDraft($GU, $draft));
  ok(!$APP->canSeeDraft($GU, $draft, 'edit'));
  ok(!$APP->canSeeDraft($GU, $draft, 'find'));
}

# 2073428 == jay's findable draft
ok(my $findable_draft = getNodeById(2073428));
foreach my $draft(2073428, $findable_draft)
{
  ok($APP->canSeeDraft($me, $draft));
  ok($APP->canSeeDraft($me, $draft, 'edit'));
  ok($APP->canSeeDraft($me, $draft, 'find'));

  ok(!$APP->canSeeDraft($collaborator, $draft));
  ok(!$APP->canSeeDraft($collaborator, $draft, 'edit'));
  ok($APP->canSeeDraft($collaborator, $draft, 'find'));

  ok(!$APP->canSeeDraft($randomeditor, $draft));
  ok(!$APP->canSeeDraft($randomeditor, $draft, 'edit'));
  ok($APP->canSeeDraft($randomeditor, $draft, 'find'));

  ok(!$APP->canSeeDraft($randomadmin, $draft));
  ok(!$APP->canSeeDraft($randomadmin, $draft, 'edit'));
  ok($APP->canSeeDraft($randomadmin, $draft, 'find'));

  ok(!$APP->canSeeDraft($GU, $draft));
  ok(!$APP->canSeeDraft($GU, $draft, 'edit'));
  ok(!$APP->canSeeDraft($GU, $draft, 'find'));
}

# 2073429 == jay's review draft
ok(my $review_draft = getNodeById(2073429));
foreach my $draft(2073429, $review_draft)
{
  ok($APP->canSeeDraft($me, $draft));
  ok($APP->canSeeDraft($me, $draft, 'edit'));
  ok($APP->canSeeDraft($me, $draft, 'find'));

  ok(!$APP->canSeeDraft($collaborator, $draft));
  ok(!$APP->canSeeDraft($collaborator, $draft, 'edit'));
  ok($APP->canSeeDraft($collaborator, $draft, 'find'));

  ok(!$APP->canSeeDraft($randomeditor, $draft));
  ok(!$APP->canSeeDraft($randomeditor, $draft, 'edit'));
  ok($APP->canSeeDraft($randomeditor, $draft, 'find'));

  ok(!$APP->canSeeDraft($randomadmin, $draft));
  ok(!$APP->canSeeDraft($randomadmin, $draft, 'edit'));
  ok($APP->canSeeDraft($randomadmin, $draft, 'find'));

  ok(!$APP->canSeeDraft($GU, $draft));
  ok(!$APP->canSeeDraft($GU, $draft, 'edit'));
  ok(!$APP->canSeeDraft($GU, $draft, 'find'));
}

done_testing();
