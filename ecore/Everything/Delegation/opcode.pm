package Everything::Delegation::opcode;
use Everything::SecurityLog qw(:events);

# We have to assume that this module is subservient to Everything::HTML
#  and that the symbols are always available

use strict;
use warnings;

## no critic (ProhibitBuiltinHomonyms)

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
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *removeFromNodegroup = *Everything::HTML::removeFromNodegroup;
  *canUpdateNode = *Everything::HTML::canUpdateNode;
  *updateLinks = *Everything::HTML::updateLinks;
  *canReadNode = *Everything::HTML::canReadNode;
  *canDeleteNode = *Everything::HTML::canDeleteNode;
  *getPageForType = *Everything::HTML::getPageForType;
  *opLogin = *Everything::HTML::opLogin;
  *replaceNodegroup = *Everything::HTML::replaceNodegroup; 
} 

# Used by bookmark, cool, weblog, socialBookmark
use JSON;

# publishdraft opcode REMOVED - superseded by Everything::API::drafts::publish_draft (POST /api/drafts/:id/publish), brought to full publishwriteup-finisher parity in #4314 (favorite/newbie notifications, writeup achievements, lastnoded, lede/Webster ordering). op= dispatch was already dead. #4320. Jun 2026.

# bookmark opcode REMOVED - superseded by Everything::API::cool (toggle_bookmark, BookmarkButton, React-wired), brought to notification parity in #4292; op= dispatch is dead. Jun 2026.

# vote opcode REMOVED - superseded by Everything::API::vote (cast_vote); op= dispatch is dead. Jun 2026.

# bless opcode REMOVED - superseded by Everything::API::superbless (AdminBestowTool, React-wired); op= dispatch is dead. Jun 2026.

# curse opcode REMOVED - superseded by Everything::API::superbless (AdminBestowTool, React-wired); op= dispatch is dead. Jun 2026.

# bestow opcode REMOVED - superseded by Everything::API::superbless (AdminBestowTool, React-wired); op= dispatch is dead. Jun 2026.

# message opcode REMOVED - full parity: all /commands live in Everything::Application::processMessageCommand; deletemsg_/archive_/unarchive_ -> Everything::API::messages (:id/action/*); plain chatter -> Everything::API::chatter (create). The unverified-email gate was dead code (no such sustype; signup never suspends). op= dispatch was already dead. #4332. Jun 2026.

# message_outbox opcode REMOVED - orphaned; outbox delete is Everything::API::messages::delete_outbox (React-wired, MessageInbox.js), outbox archive/unarchive had no UI. op= dispatch was already dead. #4198. Jun 2026.


# cool opcode REMOVED - superseded by Everything::API::cool (award_cool); op= dispatch is dead. Jun 2026.

# weblog opcode REMOVED - superseded by Everything::API::weblog (add_entry/remove_entry, AddToWeblogModal, React-wired); op= dispatch is dead. Jun 2026.

# removeweblog opcode REMOVED - its only dispatcher (the dead weblog htmlcode) is orphaned; weblog-entry removal is Everything::API::weblog::remove_entry (React-wired). #4310. Jun 2026.

# There are still references to this in the javascript that need to get cleaned out
#
# massacre opcode REMOVED - dead stub (0 op= dispatch); no longer a securityLog token (caller uses SECLOG_MASSACRE). #4299. Jun 2026.

# lockroom opcode REMOVED - toggled a room.criteria field that Everything::Application::canEnterRoom never reads (the live lock is room.roomlocked); its emitter htmlcode was orphaned. Room locking is now POST /api/chatroom/lock_room (Room.js). #4332. Jun 2026.

# resurrect opcode REMOVED - superseded by Everything::API::resurrect; op= dispatch is dead. Jun 2026.

# NOTE: bucketop and addbucket opcodes removed 2025-11-30
# The nodebucket VARS key is deprecated - see docs/user-vars-reference.md

# linktrim opcode REMOVED - superseded by Everything::API::e2node (remove_firmlink/manage_softlinks, E2NodeToolsModal). #4303. Jun 2026.

# firmlink opcode REMOVED - superseded by Everything::API::e2node (create_firmlink, E2NodeToolsModal). #4303. Jun 2026.

# insure opcode REMOVED - superseded by Everything::API::admin (insure_writeup, UserToolsModal/AdminModal). #4303. Jun 2026.

# nodenote opcode REMOVED - superseded by Everything::API::nodenotes (React-wired); op= dispatch is dead. Jun 2026.

# lockaccount opcode REMOVED - superseded by Everything::API::admin (lock_user, UserToolsModal). #4303. Jun 2026.

# unlockaccount opcode REMOVED - superseded by Everything::API::admin (unlock_user, UserToolsModal). #4303. Jun 2026.

# hidewriteup opcode REMOVED - superseded by Everything::API::hidewriteups (React-wired); op= dispatch is dead. Jun 2026.

# unhidewriteup opcode REMOVED - superseded by Everything::API::hidewriteups (React-wired); op= dispatch is dead. Jun 2026.

# changewucount opcode REMOVED - superseded by Everything::API::preferences (nw_nojunk + nodelet settings, Settings.js). #4303. Jun 2026.

# repair_e2node opcode REMOVED - superseded by Everything::API::e2node (repair_node, E2NodeToolsModal). #4303. Jun 2026.

# borg opcode REMOVED - superseded by Everything::API::admin user borg (UserToolsModal). #4303. Jun 2026.

# flushcbox opcode REMOVED - superseded by Everything::API::chatter (clear, scope=room) via
# the /flushchatter command (Chatterbox.js). The chanop room-scoped flush + SECLOG_CATBOX_FLUSH
# audit now live in Everything::Application::flushChatter. op= dispatch was already orphaned
# (no React UI reached it). #4327. Jun 2026.

# repair_e2node_noreorder opcode REMOVED - superseded by Everything::API::e2node (repair_node no-reorder). #4303. Jun 2026.

# orderlock opcode REMOVED - superseded by Everything::API::e2node (toggle_orderlock, E2NodeToolsModal). #4303. Jun 2026.

# pollvote opcode REMOVED - superseded by Everything::API::poll submit_vote (CurrentUserPoll, React-wired); op= dispatch is dead. Jun 2026.

# softlock opcode REMOVED - superseded by Everything::API::e2node (node_lock). #4303. Jun 2026.

# weblogify opcode REMOVED - superseded by Everything::API::usergroups (weblogify action, Usergroup.js, React-wired); op= dispatch is dead. Jun 2026.

# leadusergroup opcode REMOVED - superseded by Everything::API::usergroups (transfer_ownership action, UsergroupEditor.js/Usergroup.js, React-wired). #4299. Jun 2026.

# ilikeit opcode REMOVED - superseded by Everything::API::ilikeit (React-wired); op= dispatch is dead. Jun 2026.

# changeusergroup opcode REMOVED - was a one-line user-pref write ($VARS->{nodeletusergroup}); now POST /api/preferences/set {nodeletusergroup}. op= dispatch is dead. #4312. Jun 2026.

# favorite opcode REMOVED - superseded by Everything::API::favorites (React-wired); op= dispatch is dead. Jun 2026.

# unfavorite opcode REMOVED - superseded by Everything::API::favorites (React-wired); op= dispatch is dead. Jun 2026.

# category opcode REMOVED - superseded by Everything::API::category (add_member/remove_member, AddToCategoryModal, React-wired); op= dispatch is dead. Jun 2026.

# socialBookmark opcode REMOVED - dead external-site bookmark notifier (del.icio.us/Digg-era Cool Man Eddie messages); zero op= dispatch. Its notification handler + nosocialbookmark* prefs were removed with it. #4332. Jun 2026.

# sanctify opcode REMOVED - superseded by Everything::API::sanctify; op= dispatch is dead. Jun 2026.

# cure_infection opcode REMOVED - superseded by Everything::API::user (cure_infection, POST /api/user/cure). Infection FEATURE stays live; only the dead opcode removed. #4303. Jun 2026.

# publishdrafttodocument opcode REMOVED - orphaned ~2011 admin draft->document tool; no UI dispatcher ever existed (git pickaxe clean), no modern API/React equivalent. Retired alongside publishdraft. #4320. Jun 2026.

# approve_draft opcode REMOVED - the editor draft-review flow is status-based now (review->private via Everything::API::drafts::mark_reviewed, React-wired in Draft.js); its legacy parent_node links.food approval flag is unconsumed (For Review keys on status+nodenotes). op= dispatch was already dead. #4322. Jun 2026.

# parameter opcode REMOVED - superseded by Everything::API::node_parameter (NodeParameterEditor, React-wired); op= dispatch is dead. Jun 2026.

# remove opcode REMOVED - migrated to Everything::API::admin (remove_writeup single + remove_writeups bulk; AltarOfSacrifice rewired to the API). #4306. Jun 2026.

1;
