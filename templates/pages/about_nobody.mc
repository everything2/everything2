<%class>
  has 'needs_link_parse' => (default => 1);
  has 'verbs' => (default => sub {[
    'talks about',
    'broke',
    'walked',
    'saw you do',
    'cares about',
    'drew on',
    'can breathe under',
    'remembers',
    'cleaned up',
    'does',
    'fell on',
    'thinks badly of',
    'picks up',
    'eats'
    ]});

  has 'dirobjects' => (default => sub {[
    'questions',
    'you',
    'the vase',
    'the dog',
    'the walls',
    'water',
    'last year',
    'the yard',
    'Algebra',
    'the sidewalk',
    'you',
    'the slack'
  ]});

</%class>
<br><br><p><center><table width="40%"><tr><td><i>About Nobody</i><p>
% for(0..20) {
<% "Nobody " . $.verbs->[rand(scalar @{$.verbs})] . ' ' .  $.dirobjects->[rand(scalar @{$.dirobjects})] %>.<br>
% }
</td></table><br>and on and on [about Nobody].<p align=right>Andrew Lang/[nate|Nate Oostendorp]
