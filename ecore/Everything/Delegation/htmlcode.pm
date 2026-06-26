package Everything::Delegation::htmlcode;
use Everything::SecurityLog qw(:events);

# We have to assume that this module is subservient to Everything::HTML
#  and that the symbols are always available

use strict;
use warnings;

## Until all of the evals are dead, this is a strict necessity
## no critic (ProhibitStringyEval)

BEGIN {
  *getNode = *Everything::HTML::getNode;
  *getNodeById = *Everything::HTML::getNodeById;
  *getVars = *Everything::HTML::getVars;
  *getId = *Everything::HTML::getId;
  *urlGen = *Everything::HTML::urlGen;
  *linkNode = *Everything::HTML::linkNode;
  *htmlcode = *Everything::HTML::htmlcode;
  *parseLinks = *Everything::HTML::parseLinks;
  *isNodetype = *Everything::HTML::isNodetype;
  *isGod = *Everything::HTML::isGod;
  *getRef = *Everything::HTML::getRef;
  *getType = *Everything::HTML::getType;
  *updateNode = *Everything::HTML::updateNode;
  *setVars = *Everything::HTML::setVars;
  *getNodeWhere = *Everything::HTML::getNodeWhere;
  *insertIntoNodegroup = *Everything::HTML::insertIntoNodegroup;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *removeFromNodegroup = *Everything::HTML::removeFromNodegroup;
  # *canUpdateNode alias removed with publishwriteup, its only user in this file (#4354)
  *updateLinks = *Everything::HTML::updateLinks;
  *canReadNode = *Everything::HTML::canReadNode;
  *canDeleteNode = *Everything::HTML::canDeleteNode;
}

# Used by parsetime, parsetimestamp, timesince, giftshop_buyching 
use Time::Local;

# Used by shownewexp, publishwriteup, hasAchieved, showNewGP, sendPrivateMessage
use JSON;

# Used by hasAchieved for achievement delegation
use Everything::Delegation::achievement;

# Used by Application::getRenderedNotifications for notification rendering
use Everything::Delegation::notification;

# Used by retrieveCorpse for safe deserialization
use Everything::Serialization qw(safe_deserialize_dumper);

# Used by publishwriteup,isSpecialDate
use DateTime;

# Used by publishwriteup
use DateTime::Format::Strptime;

# Used by uploaduserimage, giftshop_buyching
use POSIX qw(strftime ceil floor);
use File::Copy;
use Image::Magick;


# Used by create_short_url;
use POSIX;

# publishwriteup REMOVED - the legacy form-post publish flow is retired (#4354).
# Writeups are now published by converting a draft in
# Everything::API::drafts::publish_draft (a node-type sqlUpdate that skips
# maintenance). The writeup_create maintenance hook no longer calls this; it now
# only guards against out-of-band writeup creation.
# nodepack/htmlcode/publishwriteup.xml deleted; prod node 2036500 nuked.

# weblog htmlcode REMOVED - orphaned legacy weblog display (rendered op=removeweblog remove-links); htmlcode('weblog') invoked nowhere, node 458113 unreferenced. Modern path: Controller/usergroup + React + API::weblog. #4310. Jun 2026.

# verifyRequestHash + verifyRequest REMOVED - they were the nonce generator +
# checker for the legacy gotoNode node-update-via-URL form (rendered by the now-
# dead `openform`). That form + its only other callers (the_old_hooked_pole,
# everything_s_most_wanted) are gone, and the gotoNode update block was removed,
# so both are caller-free. #4198

# sendPrivateMessage REMOVED - this ~796-line htmlcode was the last duplicate of
# Everything::Application::sendPrivateMessage, which already owned the real
# implementation (cool/costumes/giftshop/admin/users/easter_eggs/tokenator + the
# API layer all call $APP->sendPrivateMessage). The final two callers (the debate-
# comment reply notify + the new-discussion announce in Delegation::maintenance)
# were repointed to $APP->sendPrivateMessage; the usergroup announce from the
# Virgil bot uses the new sendUsergroupMessage bypass_membership option (legacy
# gated group sends on the acting user, who was always a member there).
# nodepack/htmlcode/sendprivatemessage.xml deleted too. #4349

# screens notelet text
# reads "raw" and writes "screened"
#
# screenNotelet REMOVED - migrated to Everything::Application::screen_notelet
# ($APP->screen_notelet($USER, $VARS)); notelet_editor + Application.pm repointed.
# nodepack/htmlcode/screennotelet.xml deleted. #4358

#
# possibly forms a link to external web site
# URL must start with the protocol, http:// or https://
#
# externalLinkDisplay REMOVED - Dead code, external links now handled in React. Jan 2026.

# softlock htmlcode - REMOVED January 2026: No callers found

# atomiseNode REMOVED - migrated to Everything::Application::atomise_node; the
# atom-feed pages were repointed. nodepack/htmlcode/atomisenode.xml deleted. #4358

# userAtomFeed REMOVED - migrated to Everything::Application::user_atom_feed; the
# atom-feed pages were repointed. nodepack/htmlcode/useratomfeed.xml deleted. #4358

# show_node_forward REMOVED - Dead code, node forward display migrated to React. Jan 2026.

# achievementsByType REMOVED - Dead code, achievements display migrated to React. Jan 2026.
# editor_homenode_tools REMOVED - Dead code, editor tools migrated to React. Jan 2026.

# coolcount REMOVED - factored into Everything::Application->coolcount (unit-tested). Jun 2026.

# epicenterZen REMOVED - Dead code, epicenter data now provided via Application.pm to React. Jan 2026.

# addNotification REMOVED - was a pass-through to Everything::Application::add_notification;
# the maintenance callers now call $APP->add_notification directly.
# nodepack/htmlcode/addnotification.xml deleted. #4358

# isInfected REMOVED - Dead code, old infection game feature. Jan 2026.

# ip_lookup_tools REMOVED - Migrated to React UserToolsModal. Jan 2026.

# blacklistIP REMOVED - migrated to Everything::API::admin::_blacklist_ip. Its
# only caller, the_old_hooked_pole, now drives the mass cleanup through
# POST /api/admin/users/cleanup. #4198
# lock_user_account REMOVED - migrated to Everything::API::admin::_do_lock_account
# (shared by lock_user + the cleanup endpoint). #4198

# decode_short_string REMOVED - Dead code, replaced by Everything::Page::short_url_lookup. Jan 2026.
# create_short_url REMOVED - Dead code, replaced by Everything::Application::create_short_url. Jan 2026.

# urlToNode REMOVED - dead (its last caller was the gutted writeup_create, #4354).
# nodepack/htmlcode/urltonode.xml deleted. #4358

# weblogform htmlcode - REMOVED January 2026: React AddToWeblogModal + /api/weblog handles this
# categoryform htmlcode - REMOVED January 2026: React AddToCategoryModal + /api/category handles this
# widget REMOVED - Dead code, widget UI migrated to React. Jan 2026.

# nopublishreason REMOVED - the publish-permission gate for the dead form-post
# flow (#4354). The live publish path (Everything::API::drafts::publish_draft)
# enforces its own ownership / duplicate / lock checks.
# nodepack/htmlcode/nopublishreason.xml deleted; prod node 2036363 nuked.

# canpublishas REMOVED - migrated to Everything::Application::publishas_accounts
# and ::can_publish_as, surfaced by the React publish-as picker through
# Everything::API::drafts (publishas_options + publish_draft's publish_as) (#4354).
# nodepack/htmlcode/canpublishas.xml deleted; prod node 2055136 nuked.

# addNodenote REMOVED - now Everything::Application::add_nodenote
# ($APP->add_nodenote); its maintenance callers (node_forward_create,
# draft_update) were repointed. #4354

# unpublishwriteup REMOVED - now Everything::Application::unpublish_writeup
# ($APP->unpublish_writeup($USER, $wu, $reason)); the writeup-lifecycle
# maintenance hooks (writeup_update / e2node_delete / writeup_delete) were
# repointed. #4354

# blacklistedIPs REMOVED - Dead code, IP blacklist display migrated to React Page class. Jan 2026.

# resurrectNode REMOVED - orphaned by the resurrect opcode removal (API uses $DB->resurrectNode). Jun 2026.

# reinsertCorpse REMOVED - orphaned by the resurrect opcode removal. Jun 2026.

1;
