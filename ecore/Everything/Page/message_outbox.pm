package Everything::Page::message_outbox;

use Moose;
extends 'Everything::Page::message_inbox';

# Message Outbox now uses the same unified interface as Message Inbox
# The React component shows both Inbox and Outbox tabs
# This Page class exists so users going to "Message Outbox" get the unified view

__PACKAGE__->meta->make_immutable;
1;
