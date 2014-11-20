<%flags>
  extends => '/nodelet.mc';
</%flags>
<%class>
  has 'borgcheck' => (isa => "Maybe[Str]");
  has 'usersettings' => (isa => "HashRef", required => 1);
  has 'drafts' => (isa => "HashRef", required => 1);
  has 'coolsleft' => (isa => "Maybe[Int]");
  has 'votesleft' => (isa => "Maybe[Int]");
 
  has 'votinginfodoc' => (isa => "HashRef", required => 1);
  has 'randomnode' => (isa => "Str", required => 1);
  has 'helplink' => (isa => "Maybe[HashRef]");

  has 'gpearned' => (isa => "Maybe[Int]");
  has 'expearned' => (isa => "Maybe[Int]");

  has 'servertime' => (isa => "Str", required => 1);
  has 'localtime' => (isa => "Maybe[Str]");

</%class>
<% $.borgcheck %>
<ul>
<li><% $.linkNode($.NODE, 'Log Out', {op => 'logout'}) %></li>
<li title="User Settings"><% $.linkNode($.usersettings,'',{ lastnode_id=>0 }) %></li>
<li title="Your profile"><% $.linkNode($.USER,0,{lastnode_id=>0}) %> <% $.linkNode($.USER,'<small>(edit)</small>',{displaytype=>'edit',lastnode_id=>0}) %></li>
<li title="Draft, format, and organize your works in progress"><% $.linkNode($.drafts,'',{ lastnode_id=>0 }) %></li>
<li title="Learn what all those numbers mean"><% $.linkNode($.{votinginfodoc},'Voting/XP System') %></li>
<li title="View a randomly selected node"><% $.randomnode %></li>
% if(defined $.helplink) {
<li title="Need help?"><% $.linkNode($.helplink) %></li>
% }
</ul>

% if(defined $.expearned) {
<p id="experience"><% $.expearned %></p>
% }
% if(defined $.gpearned) {
<p id="gp"><% $.gpearned %></p>
% }

% my @thingys = ();
% if($.coolsleft) { push @thingys, '<strong id="chingsleft">'.$.coolsleft.'</strong> C!'.($.coolsleft>1?'s':''); }
% if($.votesleft) { push @thingys, '<strong id="votesleft">'.$.votesleft.'</strong> vote'.($.votesleft>1?'s':''); }
% if (scalar(@thingys)) {
  <p id="voteschingsleft">You have <% join(' and ',@thingys) %> left today</p>
% }

<p id="servertime">
server time <br />
<% $.servertime %>
<br />
% if(defined $.localtime) {
<% $.linkNodeTitle('Advanced Settings|your time') %> <br /><% $.localtime %>
% } else {
<% $.linkNodeTitle('Advanced Settings|(set your time)') %>
% }
</p>

