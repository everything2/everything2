<%class>
  has 'error' => (isa => 'Maybe[Str]');
  has 'for_user' => (isa => 'Maybe[Everything::Node::user]', required => 1);

  has 'ignoring_messages_from' => (isa => 'ArrayRef[Everything::Node::user]', lazy => 1, builder => '_build_ignoring');
  has 'messages_ignored_by' => (isa => 'ArrayRef[Everything::Node::user]', lazy => 1, builder => '_build_ignored_by');

  sub _build_ignoring
  {
    my ($self) = @_;
    $self->for_user->ignoring_messages_from;
  }

  sub _build_ignored_by
  {
    my ($self) = @_;
    $self->for_user->messages_ignored_by;
  }

</%class>

% if ($REQUEST->user->is_admin or $REQUEST->user->is_chanop) {
<p>Check on user: <& username_selector , node => $.node &>
%   if(defined($.error)) {
<em><% $.error %></em>
%   }
% }

<p>
% if($.for_user->id == $REQUEST->user->id) {
You are ignoring
% } else {
<& 'linknode', node => $.for_user &> is ignoring
% }
:</p>

% if(scalar(@{$.ignoring_messages_from}) == 0) {
<em>no one</em>
% } else {
<ol>
%   foreach my $n (@{$.ignoring_messages_from}) {
<li><& 'linknode', node => $n &>
%   }
</ol>
% }


<p>
% if($.for_user->id == $REQUEST->user->id) {
You are being ignored by
% } else {
<& 'linknode', node => $.for_user &> is ignored by
% }
:</p>

% if(scalar(@{$.messages_ignored_by}) == 0) {
<em>no one</em>
% } else {
<ol>
%   foreach my $n (@{$.messages_ignored_by}) {
<li><& 'linknode', node => $n &>
%   }
</ol>
% }

<p><small>You can ignore people more thoroughly at the <& 'linknodetitle', node => 'Pit of Abomination' &></small></p>
