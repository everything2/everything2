<%flags>
  extends => '/nodelet.mc';
</%flags>
<%class>
  has 'other_users' => (isa => "ArrayRef");
  has 'changeroom_widget' => (isa => "Str");

  has 'user_in_room' => (isa => "Int");
  has 'user_is_root' => (isa => "Bool");
  has 'user_is_editor' => (isa => "Bool");
  has 'user_is_chanop' => (isa => "Bool");
  has 'user_is_developer' => (isa => "Bool");

  has 'showuseractions' => (isa => "Bool");

  has 'staffdoc' => (isa => "HashRef");

  has 'rooms' => (isa => "HashRef");

</%class>
<%method newuserdays ($createtime)>
% return unless defined($createtime) and $createtime > 0;
% my $accountage = time() - $createtime;
% if($accountage < 24*60*60*30)
% {
%   return sprintf("%d",$accountage / (24*60*60));
% }
</%method>
<%method roomheader ($room_id)>
% my $room_title = 'Outside';
% if(defined($.rooms->{$room_id}))
% {
%   $room_title = $.rooms->{$room_id};
% } else {
%   $room_title = "Unknown Room";
% }
<div><% $room_title %></div><ul>
</%method>
<% $.changeroom_widget %>
<h4>Your fellow users (<% scalar(@{$.other_users}) %>):</h4>
<ul>
% my $current_display_room = $.other_users->[0]->{room_id};
% foreach my $U (sort {($b->{room_id} == $.user_in_room) <=> ($a->{room_id} == $.user_in_room)
%   || $b->{room_id} <=> $a->{room_id}
%   || $b->{lastnodetime} <=> $a->{lastnodetime}
%   || $b->{createtime} <=> $b->{createtime}
%  } @{$.other_users}) {

%  if($current_display_room != $U->{room_id})
%  {
</ul>
%    $.roomheader($U->{room_id});
%    $current_display_room = $U->{room_id}
%  }
<li>

% my $flags = [];
% # TODO: Remove inline CSS
% push @$flags, $.linkNode($.staffdoc, "\@", {"-style" => "text-decoration: none"}) if $U->{is_admin};
% push @$flags, "\$" if $U->{is_editor};
% push @$flags, "\%" if $U->{is_developer} && $.user_is_developer;
% # TODO: Maybe reimplement tilde flag for room link; might just remove it in a rewrite
% if($.newuserdays($U->{createtime}))
% {
%   push @$flags, $.newuserdays($U->{createtime});
% }
% if(@$flags) {
% $flags = "[".join("",@$flags)."]";
% } else {
% $flags = "";
% }

% if($U->{is_me}){
<strong>
% }

<% $.linkNode($U->{user}) %> 

% if($U->{is_me}){
</strong>
% }
<% $flags %>

</li>
% }
</ul>
