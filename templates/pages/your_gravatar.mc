<h3>Your Gravatar</h3><p>The following shows your gravatar in several different sizes. If you haven't actually uploaded an avatar to gravatar.com, they have the option of generating a dynamic avatar based on your email address (don't worry, we hash it first). These dynamic avatars can be generated on one of four 4 styles: default, identicon, monsterid, or wavatar.</p><p><small>If you have an account at gravatar.com, but your avatar isn't showing up correctly below, be sure you are using the same email address on E2 that you registered with on gravatar. You can change your email address from your homenode.</small></p>

%  for(my $size = 16; $size <= 128; $size *= 2) {
<p style="text-align:center"><b><% $size %> pixels</b><br />
%    foreach my $style(undef, 'identicon', 'monsterid', 'wavatar') {
<img src="<% $REQUEST->user->gravatar_img_url($style, $size) %>" />
%    }
%  }
