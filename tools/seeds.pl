#!/usr/bin/perl -w

use strict;
use utf8;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use Everything::HTML;
use POSIX;

initEverything;

if($Everything::CONF->environment ne "development")
{
	print STDERR "Not in the 'development' environment. Exiting\n";
	exit;
}

$Everything::HTML::USER = getNode("root","user");
my $APP = $Everything::APP;

my $months = [qw|January February March April May June July August September October November December|];
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

my $realyear = $year+1900;
my $rootlog = "root log: $months->[$mon] $realyear";
my $daylog = "$months->[$mon] $mday, $realyear";

foreach my $user (1..30,"user with space","genericeditor","genericdev","genericchanop","genericdocs")
{
  if($user =~ /^\d/)
  {
    # Insert a user like "normaluser1"
    $user = "normaluser$user";
  }

  my $author = getNode($user,"user");
  if (!$author) {
    print STDERR "Inserting user: $user\n";
    my $now = POSIX::strftime('%Y-%m-%d %H:%M:%S', gmtime());
    $DB->insertNode($user,"user",-1,{"lasttime" => $now});
    $author = getNode($user,"user");
  } else {
    print STDERR "User already exists: $user (updating)\n";
  }

  $author->{author_user} = $author->{node_id};
  my ($pwhash, $salt) = $APP->saltNewPassword("blah");
  $author->{passwd} = $pwhash;
  $author->{salt} = $salt;
  $author->{doctext} = "Homenode text for $user";
  $author->{votesleft} = 50;
  $DB->updateNode($author, -1);

  # Add browser and IP data to normaluser pool for testing admin tools
  if ($user =~ /^normaluser\d+$/) {
    my $uservars = getVars($author);
    $uservars->{browser} = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
    $uservars->{ipaddy} = "8.8.8.8";
    setVars($author, $uservars);
    $DB->updateNode($author, -1);
  }
}

print STDERR "Setting normaluser20 to opt out of GP system\n";
my $normaluser20 = $DB->getNode("normaluser20", "user");
if ($normaluser20) {
  my $nu20vars = getVars($normaluser20);
  $nu20vars->{GPoptout} = 1;
  setVars($normaluser20, $nu20vars);
  $DB->updateNode($normaluser20, -1);
}

print STDERR "Promoting genericeditor to be a content editor\n";
my $ce = $DB->getNode("Content Editors","usergroup");
my $genericed = $DB->getNode("genericeditor","user");
my $already_ce = $DB->sqlSelect('COUNT(*)', 'nodegroup',
  "nodegroup_id=$ce->{node_id} AND node_id=$genericed->{node_id}");
if (!$already_ce) {
  $DB->insertIntoNodegroup($ce, $DB->getNode("root","user"), $genericed);
  $DB->updateNode($ce,-1);
}
$genericed->{vars} ||= "";
my $genericedv = getVars($genericed);
$genericedv->{nodelets} = "1687135,262,2044453,170070,91,263,1157024,165437,1689202,1930708";
$genericedv->{settings} = '{"notifications":{"2045486":1}}';
setVars($genericed,$genericedv);
$DB->updateNode($genericed, -1);

print STDERR "Promoting genericdev to be a developer\n";
my $dev = $DB->getNode("edev","usergroup");
my $genericdev = getNode("genericdev","user");
my $already_dev = $DB->sqlSelect('COUNT(*)', 'nodegroup',
  "nodegroup_id=$dev->{node_id} AND node_id=$genericdev->{node_id}");
if (!$already_dev) {
  $DB->insertIntoNodegroup($dev, $DB->getNode("root","user"),$genericdev);
  $DB->updateNode($dev, -1);
}
my $genericdevv = getVars($genericdev);
$genericdevv->{nodelets} = "1687135,262,2044453,170070,91,263,1157024,165437,1689202,1930708,836984";
$genericdevv->{settings} = '{"notifications":{"2045486":1}}';
setVars($genericdev,$genericdevv);
$DB->updateNode($genericdev, -1);

print STDERR "Promoting genericdocs to e2docs group\n";
my $e2docs = $DB->getNode("E2Docs","usergroup");
my $genericdocs = getNode("genericdocs","user");
my $already_docs = $DB->sqlSelect('COUNT(*)', 'nodegroup',
  "nodegroup_id=$e2docs->{node_id} AND node_id=$genericdocs->{node_id}");
if (!$already_docs) {
  $DB->insertIntoNodegroup($e2docs, $DB->getNode("root","user"), $genericdocs);
  $DB->updateNode($e2docs, -1);
}
my $genericdocsv = getVars($genericdocs);
$genericdocsv->{nodelets} = "1687135,262,2044453,170070,91,263,1157024,165437,1689202,1930708";
$genericdocsv->{settings} = '{"notifications":{"2045486":1}}';
setVars($genericdocs, $genericdocsv);
$DB->updateNode($genericdocs, -1);

print STDERR "Promoting genericchanop to be a channel operator\n";
my $chanops = $DB->getNode("chanops","usergroup");
my $genericchanop = getNode("genericchanop","user");
my $already_chanop = $DB->sqlSelect('COUNT(*)', 'nodegroup',
  "nodegroup_id=$chanops->{node_id} AND node_id=$genericchanop->{node_id}");
if (!$already_chanop) {
  $DB->insertIntoNodegroup($chanops, $DB->getNode("root","user"), $genericchanop);
  $DB->updateNode($chanops, -1);
}
my $genericchanopv = getVars($genericchanop);
$genericchanopv->{nodelets} = "1687135,262,2044453,170070,91,263,1157024,165437,1689202,1930708";
$genericchanopv->{settings} = '{"notifications":{"2045486":1}}';
setVars($genericchanop, $genericchanopv);
$DB->updateNode($genericchanop, -1);

print STDERR "Creating c_e user with message forward to Content Editors\n";
my $now = POSIX::strftime('%Y-%m-%d %H:%M:%S', gmtime());
my $content_editors = $DB->getNode("Content Editors","usergroup");
my $c_e_user = getNode("c_e","user");
if (!$c_e_user) {
  $DB->insertNode("c_e","user",-1,{
    "lasttime" => $now,
    "message_forward_to" => $content_editors->{node_id}
  });
  $c_e_user = getNode("c_e","user");
} else {
  print STDERR "c_e user already exists (updating)\n";
}
$c_e_user->{author_user} = $c_e_user->{node_id};
$c_e_user->{passwd} = "blah";
$c_e_user->{message_forward_to} = $content_editors->{node_id};
$DB->updateNode($c_e_user, -1);

print STDERR "Adding root user to gods and e2gods usergroups for testing\n";
my $gods = $DB->getNode("gods","usergroup");
my $e2gods = $DB->getNode("e2gods","usergroup");
my $root_user = $DB->getNode("root","user");

# Check if root is already in gods (idempotent operation)
my $existing_gods = $DB->sqlSelect('COUNT(*)', 'nodegroup',
  "nodegroup_id=$gods->{node_id} AND node_id=$root_user->{node_id}");
if (!$existing_gods) {
  # Find next available rank in gods
  my $max_rank = $DB->sqlSelect('MAX(nodegroup_rank)', 'nodegroup',
    "nodegroup_id=$gods->{node_id}");
  $max_rank = defined($max_rank) ? $max_rank : -1;
  $DB->sqlInsert("nodegroup", {
    nodegroup_id => $gods->{node_id},
    node_id => $root_user->{node_id},
    nodegroup_rank => $max_rank + 1,
    orderby => 0
  });
}

# Check if root is already in e2gods (idempotent operation)
my $existing_e2gods = $DB->sqlSelect('COUNT(*)', 'nodegroup',
  "nodegroup_id=$e2gods->{node_id} AND node_id=$root_user->{node_id}");
if (!$existing_e2gods) {
  # Find next available rank in e2gods
  my $max_rank = $DB->sqlSelect('MAX(nodegroup_rank)', 'nodegroup',
    "nodegroup_id=$e2gods->{node_id}");
  $max_rank = defined($max_rank) ? $max_rank : -1;
  $DB->sqlInsert("nodegroup", {
    nodegroup_id => $e2gods->{node_id},
    node_id => $root_user->{node_id},
    nodegroup_rank => $max_rank + 1,
    orderby => 0
  });
}

print STDERR "Creating E2E test users\n";
$now = POSIX::strftime('%Y-%m-%d %H:%M:%S', gmtime());

# Helper function to add user to group with next available rank
sub add_to_group {
  my ($user, $group, $orderby) = @_;
  my $already_member = $DB->sqlSelect('COUNT(*)', 'nodegroup',
    "nodegroup_id=$group->{node_id} AND node_id=$user->{node_id}");
  if (!$already_member) {
    my $max_rank = $DB->sqlSelect('MAX(nodegroup_rank)', 'nodegroup',
      "nodegroup_id=$group->{node_id}");
    $max_rank = defined($max_rank) ? $max_rank : -1;
    $DB->sqlInsert("nodegroup", {
      nodegroup_id => $group->{node_id},
      node_id => $user->{node_id},
      nodegroup_rank => $max_rank + 1,
      orderby => $orderby || 0
    });
  }
}

# E2E Admin user (in gods)
print STDERR "  - e2e_admin (admin via gods)\n";
my $e2e_admin = getNode("e2e_admin","user");
if (!$e2e_admin) {
  $DB->insertNode("e2e_admin","user",-1,{"lasttime" => $now});
  $e2e_admin = getNode("e2e_admin","user");
  $e2e_admin->{author_user} = $e2e_admin->{node_id};
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_admin->{passwd} = $pwhash;
  $e2e_admin->{salt} = $salt;
  $e2e_admin->{GP} = 500;
  $DB->updateNode($e2e_admin, -1);
} else {
  # Update password if user already exists
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_admin->{passwd} = $pwhash;
  $e2e_admin->{salt} = $salt;
  $DB->updateNode($e2e_admin, -1);
}
add_to_group($e2e_admin, $gods, 1);

# E2E Editor user (in Content Editors)
print STDERR "  - e2e_editor (content editor)\n";
my $e2e_editor = getNode("e2e_editor","user");
if (!$e2e_editor) {
  $DB->insertNode("e2e_editor","user",-1,{"lasttime" => $now});
  $e2e_editor = getNode("e2e_editor","user");
  $e2e_editor->{author_user} = $e2e_editor->{node_id};
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_editor->{passwd} = $pwhash;
  $e2e_editor->{salt} = $salt;
  $e2e_editor->{GP} = 300;
  $DB->updateNode($e2e_editor, -1);
} else {
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_editor->{passwd} = $pwhash;
  $e2e_editor->{salt} = $salt;
  $DB->updateNode($e2e_editor, -1);
}
my $content_editors_group = $DB->getNode("Content Editors","usergroup");
add_to_group($e2e_editor, $content_editors_group, 2);

# E2E Developer user (in edev)
print STDERR "  - e2e_developer (developer)\n";
my $e2e_developer = getNode("e2e_developer","user");
if (!$e2e_developer) {
  $DB->insertNode("e2e_developer","user",-1,{"lasttime" => $now});
  $e2e_developer = getNode("e2e_developer","user");
  $e2e_developer->{author_user} = $e2e_developer->{node_id};
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_developer->{passwd} = $pwhash;
  $e2e_developer->{salt} = $salt;
  $e2e_developer->{GP} = 200;
  $DB->updateNode($e2e_developer, -1);
} else {
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_developer->{passwd} = $pwhash;
  $e2e_developer->{salt} = $salt;
  $DB->updateNode($e2e_developer, -1);
}
my $edev_group = $DB->getNode("edev","usergroup");
add_to_group($e2e_developer, $edev_group, 0);

# E2E Chanop user (in chanops)
print STDERR "  - e2e_chanop (channel operator)\n";
my $e2e_chanop = getNode("e2e_chanop","user");
if (!$e2e_chanop) {
  $DB->insertNode("e2e_chanop","user",-1,{"lasttime" => $now});
  $e2e_chanop = getNode("e2e_chanop","user");
  $e2e_chanop->{author_user} = $e2e_chanop->{node_id};
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_chanop->{passwd} = $pwhash;
  $e2e_chanop->{salt} = $salt;
  $e2e_chanop->{GP} = 150;
  $DB->updateNode($e2e_chanop, -1);
} else {
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_chanop->{passwd} = $pwhash;
  $e2e_chanop->{salt} = $salt;
  $DB->updateNode($e2e_chanop, -1);
}
my $chanops_group = $DB->getNode("chanops","usergroup");
add_to_group($e2e_chanop, $chanops_group, 0);

# E2E Regular user (no special permissions)
print STDERR "  - e2e_user (regular user)\n";
my $e2e_user = getNode("e2e_user","user");
if (!$e2e_user) {
  $DB->insertNode("e2e_user","user",-1,{"lasttime" => $now});
  $e2e_user = getNode("e2e_user","user");
  $e2e_user->{author_user} = $e2e_user->{node_id};
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_user->{passwd} = $pwhash;
  $e2e_user->{salt} = $salt;
  $e2e_user->{GP} = 100;
  $DB->updateNode($e2e_user, -1);
} else {
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_user->{passwd} = $pwhash;
  $e2e_user->{salt} = $salt;
  $DB->updateNode($e2e_user, -1);
}
# Configure nodelets for e2e_user (required for t/031_settings_api.t)
my $e2e_userv = getVars($e2e_user);
$e2e_userv->{nodelets} = "1687135,262,2044453,170070,91,263,1157024,165437,1689202,1930708";
setVars($e2e_user, $e2e_userv);
$DB->updateNode($e2e_user, -1);

# E2E User with space in username
print STDERR "  - e2e user space (user with space in name)\n";
my $e2e_user_space = getNode("e2e user space","user");
if (!$e2e_user_space) {
  $DB->insertNode("e2e user space","user",-1,{"lasttime" => $now});
  $e2e_user_space = getNode("e2e user space","user");
  $e2e_user_space->{author_user} = $e2e_user_space->{node_id};
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_user_space->{passwd} = $pwhash;
  $e2e_user_space->{salt} = $salt;
  $e2e_user_space->{GP} = 75;
  $DB->updateNode($e2e_user_space, -1);
} else {
  my ($pwhash, $salt) = $APP->saltNewPassword("test123");
  $e2e_user_space->{passwd} = $pwhash;
  $e2e_user_space->{salt} = $salt;
  $DB->updateNode($e2e_user_space, -1);
}

my $types = 
{
  "e2node" => getNode("e2node","nodetype"),
  "writeup" => getNode("writeup","nodetype")
};

my $writeuptypes =
{
  "idea" => getNode("idea","writeuptype"),
};

my $datanodes = {
  "writeup" => {
    "normaluser1" => [
      ["Quick brown fox", "thing", "The quick brown fox jumped over the [lazy dog]"],
      ["lazy dog","idea","The lazy dog kind of just sat there while the [quick brown fox] jumped over him"],
      ["regular brown fox","person","Not very [quick], but still [admirable]. What does [he|the fox] say?"],
      ["Why are foxes lazy?","essay","<em>Are they really lazy?</em><strong>Here is my manifesto</strong>"],
      ["Dogs are a man's best friend","idea","I want to [hug all the dogs]. HUG them. [Hug them long]. [Hug them huge]"],
      ["hug all the dogs","thing","Break out the pug hugs"],
      ["writeup with ' single quote","thing","Sometimes you just have to be quoted"],
      ["writeup with \" double quote","thing","Sometimes you just have to be quoted twice"],
      [$daylog, "log", "Sometimes you just gotta daylog, and trigger is_log!"],
      # UTF-8 and emoji content for testing
      ["café ☕", "thing", "A lovely place to have coffee ☕ and croissants 🥐"],
      ["日本語 Japanese", "idea", "Testing Unicode: 日本語、中文、한国어、Русский, العربية"],
      ["emoji test 😀", "thing", "Various emojis: 😀 😃 😄 🎉 🎊 ✨ 💖 🌟"],
      ["math symbols ∑∫", "thing", "Math notation: ∑∫∂∇∆√∞≈≠≤≥±×÷"],
      ["currency test €£¥", "idea", "Different currencies: €100 £50 ¥1000 ₹500 ₿0.01"],
      ["diacritics àéîöü", "thing", "Letters with marks: àáâãäå èéêë ìíîï òóôõö ùúûü ñ ç"],
      ["arrows ↑→↓←", "idea", "Directional arrows: ↑ ↓ ← → ↔ ↕ ⇄ ⇅ ⇆"],
      ["music notes ♪♫", "thing", "Musical symbols: ♩ ♪ ♫ ♬ ♭ ♮ ♯ 𝄞"],
      ['quotes "test"', "idea", 'Different quote styles: "English" „German" «French» 『Japanese』'],
      ["unicode spaces", "thing", "Various whitespace: em\u2003space, en\u2002space, thin\u2009space"],
      # AdSense dirty word filtering test data
      # Titles with dirty words (should be filtered from Findings for guests)
      ["sexual content test", "thing", "<p>This is a clean writeup about content moderation and internet safety.</p>"],
      ["drug policy reform", "thing", "<p>A discussion of policy changes and reform efforts in modern society.</p>"],
      ["fuck censorship debates", "essay", "<p>An essay about free speech and censorship in modern society.</p>"],
      # Clean titles but dirty words in excerpt (should skip excerpt but show in Findings list)
      ["internet safety guidelines", "thing", "<p>This writeup discusses sex education and adult content filters for parents.</p>"],
      ["medical terminology primer", "thing", "<p>The breast examination procedure is an important part of medical screening.</p>"],
      ["historical prohibition era", "essay", "<p>During prohibition, cocaine was ironically legal while alcohol was banned.</p>"],
      # Clean nodes that should always show excerpts
      ["quantum computing basics", "thing", "<p>Quantum computers use qubits to perform calculations exponentially faster than classical computers.</p>"],
      ["coffee brewing methods", "essay", "<p>Pour over, French press, and espresso are popular brewing methods for coffee enthusiasts.</p>"],
    ],
    "normaluser2" => [
      ["tomato", "idea", "A red [vegetable]. A fruit, actually"],
      ["tomatoe", "how-to","A poorly-spelled way to say [tomato]"],
      ["swedish tomatoë", "essay","Swedish tomatoes"],
      ["potato", "essay","Boil em, mash em, put em in a [stew]."],
      ["Writeups+plusses, a lesson in love","essay","All of the love for the [plus|+] sign"],
      ["weather symbols ☀☁", "thing", "Weather: ☀ ☁ ☂ ☃ ⛄ ❄ ⚡"],
      ["zodiac signs ♈♉", "idea", "Zodiac: ♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓"],
      ["hearts and flowers ❤🌸", "thing", "Love and nature: ❤ 💕 💖 🌸 🌹 🌺 🌻 🌼"],
      ["animals 🐕🐈", "idea", "Creatures: 🐕 🐈 🐁 🐘 🐧 🦁 🦊 🐝"],
    ],
    "normaluser3" => [
      ["hidden writeup here", "idea","This writeup was hidden from [New Writeups]"],
      ["Writeup w/ slash", "thing", "This writeup contains a slash"],
      ["Writeups & ampersands", "thing", "This writeup contains an ampersand"],
      ["Writeup; semicolon", "essay", "Dramatic and parser-breaking"],
      ["Writeups can have questions?", "idea", "Sometimes inquisitive is good!"],
      ["cyrillic Привет", "thing", "Russian text: Привет мир! Как дела?"],
      ["greek Ελληνικά", "idea", "Greek letters: Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ"],
      ["hebrew עברית", "thing", "Right-to-left: עברית שלום"],
    ],
    "user with space" => [
      ["bad poetry", "idea", "Kind of bad poetry here"],
      ["good poetry", "poetry", "Solid work here"],
      ["tomato", "definition", "What is a tomato, really?"],
      ["really bad writeup", "poetry", "This is [super bad]"],
      ["food emojis 🍕", "thing", "Delicious: 🍕 🍔 🍟 🌮 🍰 🍦 🍿"],
    ],
    "genericdev" => [
      ["boring dev announcement 1", "log", "Really, pretty boring stuff"],
      ["boring dev announcement 2", "idea", "Only interesting if you're a [developer]"],
      ["interesting dev announcement", "lede", "Don't bury the lede. Understand this!"],
      ["lukewarm dev announcement", "thing", "Not bad work. Not bad at all"],
      [$rootlog, "log", "This triggers is_log!"],
      ["tech symbols ⚙️💻", "thing", "Technology: ⚙️ 💻 📱 ⌨️ 🖥️ 🖱️ ⚡"],
      # Multi-author e2node
      ["programming languages", "log", "Today I learned [Haskell] and my brain hurts"],
    ],
    "Virgil" => [
      ["An Introduction to Everything2", "place", "Stub content for a site help doc here"],
    ],
    "user with space" => [
      ["bad poetry", "idea", "Kind of bad poetry here"],
      ["good poetry", "poetry", "Solid work here"],
      ["tomato", "definition", "What is a tomato, really?"],
      ["really bad writeup", "poetry", "This is [super bad]"],
      ["food emojis 🍕", "thing", "Delicious: 🍕 🍔 🍟 🌮 🍰 🍦 🍿"],
    ],
    # Additional authors to populate nodeshells
    "normaluser4" => [
      ["artificial intelligence", "idea", "The future of [machine learning] and [neural networks] in modern computing"],
      ["quantum computing", "thing", "Understanding [quantum mechanics] and computational theory"],
      ["blockchain technology", "essay", "Decentralized systems and their impact on society"],
      ["climate change", "idea", "Environmental challenges and [renewable energy] solutions"],
      ["existentialism", "thing", "Being and nothingness in modern philosophy"],
      # Multi-author e2nodes - also written by normaluser5 and normaluser6
      ["programming languages", "idea", "Different approaches to [software development] from C to [Python]"],
      ["coffee", "thing", "The best beverage for [developers] and night owls"],
      ["databases", "essay", "From relational to NoSQL: choosing the right [database] for your needs"],
    ],
    "normaluser5" => [
      ["machine learning", "definition", "Algorithms that learn from data without explicit programming"],
      ["renewable energy", "essay", "Solar, wind, and sustainable power sources for the future"],
      ["jazz improvisation", "thing", "The art of spontaneous musical creation"],
      ["dystopian fiction", "idea", "Imagining dark futures in literature and film"],
      # Multi-author e2nodes - also written by normaluser4 and normaluser6
      ["programming languages", "definition", "The syntax and semantics of [programming] paradigms"],
      ["coffee", "essay", "A cultural history of [coffee] from Ethiopia to Seattle"],
      ["databases", "thing", "PostgreSQL vs MySQL: the eternal [database] debate"],
    ],
    "normaluser6" => [
      ["cybersecurity", "thing", "Protecting systems from digital attacks and threats"],
      ["neural networks", "idea", "Computational models inspired by biological neurons"],
      ["cognitive dissonance", "definition", "Mental discomfort from holding contradictory beliefs"],
      ["fermi paradox", "essay", "Where are all the aliens? The great silence of the universe"],
      # Multi-author e2nodes - also written by normaluser4 and normaluser5
      ["programming languages", "thing", "Why [Rust] is the future and [JavaScript] is everywhere"],
      ["coffee", "definition", "Arabica, Robusta, and the science of [caffeine]"],
      ["databases", "idea", "Graph databases and the power of [relationships] in data"],
    ],
    "normaluser7" => [
      ["morning brew rituals", "essay", "<p>Every morning starts with the same routine. The kettle whistles at precisely 6:47 AM, and I begin the careful process of preparing my daily cup of liquid motivation. The beans, <strong>freshly roasted</strong> from a small shop in [Portland], release their earthy aroma as I grind them to a medium-coarse consistency.</p><p>This isn't just about [caffeine] - it's about the <em>ritual</em>, the meditation, the moment of peace before the chaos of the day begins. I've been perfecting this routine for fifteen years, and I've learned that the quality of your morning beverage directly correlates with the quality of your entire day.</p><p>The [water temperature] matters - too hot and you'll extract bitter compounds, too cool and you won't get proper extraction. I aim for 200 degrees Fahrenheit, measured with a thermometer I keep by the kettle. The ratio is equally important: 1:16, meaning one gram of grounds for every sixteen grams of water. Some people think this is excessive precision, but those people have never truly tasted perfection.</p><p>The bloom phase is critical - that first pour where the grounds release carbon dioxide and expand like a small volcano. I wait thirty seconds, watching the transformation, before continuing with a slow, circular pour. The entire process takes about four minutes from start to finish, and in those four minutes, the world doesn't exist. No emails, no meetings, no obligations. Just me, the steam rising from the cup, and the promise of consciousness gradually returning to my foggy morning brain.</p><p>I've tried every [brewing method] imaginable - French press, AeroPress, pour-over, cold brew, espresso machines that cost more than my first car. Each has its merits, but I keep returning to the simple pour-over method. There's something honest about it, something that requires attention and care. You can't rush it, you can't multitask during it. It demands your presence.</p><p>My partner thinks I'm slightly obsessed, but she doesn't complain when she gets her perfectly crafted cappuccino every Saturday morning. I've even started keeping a journal of different beans I've tried, noting the origin, roast date, flavor profiles, and brewing parameters. Some might call it excessive. I call it <strong>dedication to craft</strong>.</p>"],
      ["espresso extraction science", "thing", "<p>The physics of <strong>espresso extraction</strong> is far more complex than most people realize. When [water] at approximately 200 degrees Fahrenheit is forced through finely ground beans at nine bars of pressure for 25-30 seconds, a remarkable transformation occurs.</p><p>The water acts as a solvent, extracting hundreds of [flavor compounds] from the cellular structure of the roasted beans. But this isn't a simple dissolution process - it's a carefully orchestrated dance of [chemistry], [physics], and time.</p><p>The grind size is <em>absolutely critical</em>. Too coarse and the water flows through too quickly, resulting in under-extraction and sour, weak shots. Too fine and the water can't flow properly, leading to over-extraction and bitter, astringent flavors. We're talking about differences measured in micrometers here.</p><p>Professional baristas adjust their [grinders] multiple times throughout the day as humidity and temperature affect the beans. The pressure curve matters too. Most machines maintain constant pressure, but some high-end equipment varies the pressure throughout the extraction, starting with a pre-infusion phase at lower pressure to wet the grounds evenly.</p><p>Temperature stability is another crucial factor. The water temperature needs to remain consistent throughout the extraction, which is why professional espresso machines have PID controllers and massive copper boilers that maintain temperature within one degree.</p><p>I've spent hundreds of hours studying extraction theory, watching videos of transparent portafilters showing water flow patterns, and analyzing shots with a <strong>refractometer</strong> that measures total dissolved solids. Yes, a refractometer - a scientific instrument that tells you the extraction percentage. Optimal extraction is typically between 18-22% TDS, though this varies by preference and bean origin.</p><p>Some people think this level of analysis ruins the enjoyment. I think it <em>enhances</em> it. When you understand the [science], every variable becomes an opportunity for optimization, every shot becomes an experiment, and the pursuit of perfection becomes infinitely fascinating.</p>"],
      ["third wave movement", "idea", "The specialty beverage revolution, often called the third wave movement, represents a fundamental shift in how we think about our daily cup. The first wave was about availability - instant products and canned grounds made the drink accessible to everyone. The second wave brought us café culture and familiar chain stores where you could get a consistent latte anywhere in the world. But the third wave is about quality, transparency, and treating this agricultural product with the same respect we give to wine or craft beer. This movement emphasizes direct trade relationships between roasters and farmers, single-origin beans with complete traceability, lighter roasts that preserve the bean's natural flavors rather than masking them with char, and brewing methods that highlight the unique characteristics of each origin. When you visit a third wave café, you'll find baristas who can tell you not just which country the beans come from, but which specific farm, what processing method was used, when they were harvested, and what flavor notes to expect. The menu board might list beans from Ethiopia with tasting notes of blueberry and jasmine, or beans from Colombia with notes of caramel and nuts. This isn't pretentious marketing speak - these flavors actually exist in the beans when they're properly grown, processed, and roasted. The movement has also brought attention to sustainability and fair compensation for farmers. Direct trade means roasters work directly with producers, often paying significantly above fair trade minimums, and investing in long-term relationships that improve quality and support farming communities. There's transparency about pricing - some cafés even post what they paid farmers per pound. Light roasting has become the norm in third wave shops because it preserves the bean's origin characteristics. Dark roasting, while not inherently bad, tends to make all beans taste similar - dominated by roast flavors rather than origin flavors. Light roasts require higher quality beans because there's nowhere to hide defects. The brewing methods have evolved too. You'll see pour-overs prepared with precise timing and ratios, espresso machines that cost $20,000, and baristas who compete in championships judged on technical skill and flavor. Some criticize the movement as elitist or pretentious. Critics point to $5 single-origin pour-overs and suggest the emperor has no clothes. But I've tasted the difference. I've had perfectly prepared Ethiopian Yirgacheffe that genuinely tastes like blueberries, and I've had Kenyan beans so bright and acidic they rival grapefruit. These experiences aren't available at your average diner. The third wave has also sparked a home brewing revolution. Enthusiasts invest in grinders, scales, gooseneck kettles, and learn techniques once reserved for professionals. Online communities share tips, recipes, and reviews. It's transformed from a commodity into a craft, from a wake-up drug into an experience worth savoring."],
    ],
    "normaluser8" => [
      ["café culture in Europe", "essay", "Walking through the streets of Vienna, Prague, or Paris, you'll notice something distinctly different from American café culture. The pace is slower, the experience more central to daily life, and the relationship between patron and establishment runs deeper than mere transaction. In Europe, cafés aren't just places to grab a quick drink - they're institutions, social hubs, and sometimes historic landmarks that have hosted famous intellectuals, artists, and revolutionaries. Take Café Central in Vienna, where Trotsky once played chess, or Les Deux Magots in Paris, where Sartre and de Beauvoir held court. These aren't museum pieces - they're living establishments where locals still gather daily. Europeans have perfected the art of lingering. You can order a single espresso and occupy a table for hours without anyone rushing you or giving you disapproving looks. This is expected behavior. The café serves as an extension of your living room, a place to read, work, socialize, or simply watch the world pass by. The architecture of European cafés reflects this different philosophy. You'll find comfortable seating, often facing outward toward the street rather than inward. The furniture is meant for sitting, not for quick turnover. The décor tends toward the elegant - marble tables, bentwood chairs, ornate moldings, and large windows that blur the line between inside and outside. The menu differs significantly too. An espresso is simply an espresso - a single or double shot served in a small cup with perhaps a glass of water. The elaborate milk-based drinks that dominate American menus are less common. You order a cappuccino (only before 11 AM in Italy), a macchiato, or perhaps a café crème. The focus is on the pure beverage rather than endless customization options. The ritual of ordering and payment varies by country. In Vienna's traditional coffehouses, you'll be served a drink on a silver tray with a glass of water and a small piece of chocolate. You don't pay until you're ready to leave, sometimes hours later. In Italy, you might pay first at the register, then present your receipt to the barista. In France, you sit down and a waiter takes your order - standing at the bar is cheaper but less common. The social function of these establishments cannot be overstated. They're where deals are made, relationships begin, ideas are debated, and community happens. During my year living in Prague, I watched the same groups gather at the same tables every day - elderly men playing cards, students studying for exams, freelancers typing on laptops, couples having quiet conversations. The barista knew everyone's regular order without asking. This level of community integration seems increasingly rare in our fast-paced, efficiency-oriented world. The economics work differently too. European cafés charge more per drink but expect longer stays. The profit comes from steady patronage rather than high turnover. A successful café has regulars who come daily, not crowds who rush through. Some establishments have been run by the same family for generations, with recipes and techniques passed down like heirlooms. American coffee culture has its strengths - innovation, variety, convenience. But European café culture offers something we've perhaps lost: a place to simply be, without pressure or hurry, where the experience matters more than the efficiency."],
      ["roasting profiles and chemistry", "thing", "<p>The transformation of green seeds into the aromatic brown beans we recognize involves one of the most complex chemical processes in <strong>food science</strong>. During roasting, over 1,000 [chemical compounds] are created, destroyed, and transformed through a series of reactions that would require a textbook of [organic chemistry] to fully explain.</p><p>The basic process involves applying <em>heat</em> to green beans until they reach internal temperatures between 400-450 degrees Fahrenheit, but the path to get there determines everything about the final flavor.</p><p>The first stage is the drying phase, where the beans, which start at about 10-12% moisture content, begin releasing water. The beans turn from green to yellow, and you can smell something like hay or grass. This phase typically lasts 4-8 minutes depending on batch size and desired profile.</p><p>The [Maillard reaction] begins around 300 degrees Fahrenheit. This is the same reaction that browns meat and creates the crust on bread. Amino acids and reducing sugars combine to create hundreds of new flavor compounds - melanoidins that contribute to body and color, and various aromatic compounds that create complexity.</p><p>Around 385 degrees, you hear the <strong>first crack</strong> - a popping sound like popcorn as the beans release steam and carbon dioxide, their cellular structure fracturing from internal pressure. This is an exothermic reaction, meaning the beans themselves generate heat.</p><p>Most specialty roasters stop somewhere between first crack and second crack, preserving the bean's origin characteristics. If you continue roasting, caramelization intensifies - the sugars in the beans break down further, creating sweeter, more caramelized flavors while simultaneously destroying some of the more delicate aromatic compounds.</p><p>Professional roasters profile their roasts obsessively, logging every variable - charge temperature, gas pressure adjustments, drum speed, development time ratio, rate of rise. They're not just following recipes but responding to the [beans] themselves, which vary by origin, processing method, moisture content, and even the weather on roasting day.</p>"],
      ["sustainable farming practices", "idea", "The path from cherry to cup involves hundreds of decisions that affect not just flavor but the livelihoods of millions of farming families and the health of tropical ecosystems. Sustainable farming practices in the coffee industry address environmental, economic, and social challenges simultaneously, though success stories remain frustratingly rare in a industry still dominated by commodity pricing and exploitation. Traditional coffee cultivation, particularly sun-grown monoculture, has devastating environmental impacts. Forests are cleared to plant row after row of a single crop, eliminating biodiversity and requiring heavy use of fertilizers and pesticides to maintain productivity. Soil degradation occurs rapidly without the natural ecosystem support. Water resources become polluted. And economically, farmers who grow commodity-grade product receive prices barely above production costs, keeping families in perpetual poverty. Shade-grown coffee represents one alternative approach. By cultivating coffee beneath a canopy of taller trees - often fruit trees, nitrogen-fixing species, and native forest species - farmers create polyculture systems that mimic natural forest structures. These systems support biodiversity, providing habitat for migratory birds and other wildlife. The shade protects the soil, reduces water needs, and actually improves cup quality by slowing cherry ripening and concentrating sugars. The diverse crops provide additional income streams - bananas, citrus, avocados, spices - reducing farmer dependence on a single commodity. I visited a shade-grown farm in Guatemala where the farmer grew fifteen different crops alongside his coffee plants. He explained how the bird populations control pests naturally, how the tree leaf litter enriches the soil, how the forest microclimate reduces temperature extremes. His operating costs were lower than conventional farms, his yields comparable, and his premium prices from specialty buyers made his small operation profitable. Processing methods also impact sustainability. Traditional washed processing, while producing clean cup profiles, uses enormous amounts of water and creates polluted wastewater that damages rivers and streams. Newer eco-pulping technology reduces water use by 80% or more. Natural and honey processing methods, which dry cherries with some or all of the fruit intact, use almost no water but require careful management to prevent mold. Some innovative producers are experimenting with closed-loop water systems and anaerobic fermentation methods that improve flavor while eliminating pollution. The economic sustainability challenge is perhaps the most difficult. Coffee prices are set by commodity markets that fluctuate wildly and often fall below production costs. Farmers have no price security, making planning impossible. Fair trade certification attempts to address this with price minimums, but critics note that fair trade prices are still quite low and certification costs burden small farmers. Direct trade relationships between roasters and farmers, bypassing multiple middlemen, can dramatically increase farmer income while still costing roasters less than conventional supply chains. Social sustainability involves education, healthcare, gender equality, and breaking cycles of poverty. Some progressive farms provide housing, schools, and healthcare for workers. Others implement profit-sharing or cooperative ownership models. Women, who perform much of the harvesting labor, are increasingly being included in decision-making and training programs. The challenges are immense and solutions incomplete, but the specialty coffee movement has at least made these issues visible and created market incentives for improvement."],
    ],
    "normaluser9" => [
      ["bean processing methods", "essay", "After cherries are harvested, they must be processed to remove the fruit and extract the seed we call a bean. This processing step profoundly affects the final cup flavor - potentially more than roasting or brewing - yet it remains poorly understood by most consumers. The three primary methods - washed, natural, and honey - create distinctly different flavor profiles from identical cherries. Washed processing, also called wet processing, involves removing all the fruit before drying. Cherries are depulped mechanically, leaving the seeds coated in a sticky layer of mucilage. These mucilage-coated seeds are fermented in tanks for 12-72 hours, where naturally occurring bacteria and yeasts break down the sugars and pectin. Then the beans are washed clean and dried to proper moisture content. Washed processing creates clean, bright cups that clearly express the bean's inherent characteristics - the terroir, varietal, and growing conditions come through without interference from fruit flavors. This is the dominant processing method for specialty grade beans, particularly in Central and South America and East Africa. The process requires significant water resources - up to 100 liters per kilogram of green coffee - and creates wastewater that can pollute water sources if not properly managed. Natural processing is the oldest method, requiring only sun and time. Whole cherries are spread on raised beds or patios and dried intact for 3-4 weeks, turned regularly to prevent mold and ensure even drying. As the fruit dehydrates, the seeds inside continue to interact with the fermenting sugars and compounds in the fruit. Once dried, the hard, dark cherry shell is mechanically removed to extract the beans. Naturals develop bold, fruit-forward flavors - often described as berry-like, wine-like, or fermented. Ethiopian natural process beans can taste remarkably like blueberries. Brazilian naturals often have chocolate and berry notes. The process requires no water, making it popular in regions with water scarcity, but it requires more space, more labor for turning, and careful management to avoid over-fermentation or mold. Honey processing, despite the name having nothing to do with actual honey, is a hybrid method. Cherries are depulped but the beans aren't washed - varying amounts of mucilage remain on the bean during drying. The name comes from the sticky, honey-like texture of mucilage-coated beans. Different levels of mucilage removal create subcategories - white honey (most removed), yellow honey, red honey, black honey (almost none removed). More mucilage means more fruit sugars in contact with the bean during drying, creating sweeter, fuller-bodied cups than washed processing but cleaner than naturals. This method has become popular in Costa Rica and other Central American origins. These aren't the only methods - innovative producers experiment with anaerobic fermentation, carbonic maceration borrowed from winemaking, extended fermentations, and various hybrid approaches. Some ferment in sealed tanks with added yeast strains or bacteria cultures, creating unusual flavor profiles that judges either love or hate. I've tasted experimental lots that taste like bourbon barrel-aged beer or tropical fruit salads - dramatically different from anything traditional. The processing method interacts with everything else - origin characteristics, varietal, roast level, brewing method. Understanding processing helps you select beans that match your preferences and appreciate the remarkable diversity this agricultural product offers."],
      ["pour-over technique mastery", "thing", "The pour-over method appears deceptively simple - ground coffee in a filter, hot water poured over it, extracted liquid in a cup below. But achieving consistently excellent results requires attention to numerous variables and the development of specific physical skills that take months or years to master. The equipment matters more than you might expect. The cone geometry affects flow rate and turbulence - V60 cones with their large opening and spiral ribs create different extraction than Kalita Wave's flat-bottom design with three small holes. The filter material matters too - paper filters trap oils and fines, producing cleaner cups, while metal filters allow more sediment and oils through, creating fuller body but sometimes muddy flavors. The thickness and processing of paper filters varies by brand, affecting flow rate and taste. Some baristas rinse filters not just to remove paper taste but to preheat the brewer and adjust filter properties. Water quality deserves serious attention despite being often overlooked. Tap water with high mineral content, chlorine, or off flavors will produce unpleasant coffee regardless of technique. Bottled spring water or filtered water with balanced mineral content (calcium and magnesium contribute to extraction while bicarbonate buffers acidity) produces the best results. Some enthusiasts create custom water blends using distilled water and added minerals. Grind size and consistency dramatically affect extraction. For pour-over, medium-fine grind works best - too coarse and water flows through too quickly, under-extracting; too fine and you risk over-extraction and channeling. But consistency matters more than exact size. A quality burr grinder produces particles of uniform size, while cheap blade grinders create everything from powder to chunks. Those fine particles over-extract while large particles under-extract, making the cup simultaneously too bitter and too weak. The pouring technique itself takes practice to master. Most methods begin with a bloom phase - adding twice the weight of water as grounds (e.g., 60g water for 30g grounds) and waiting 30-45 seconds. This allows grounds to degas, releasing carbon dioxide that would otherwise interfere with extraction. Watch for the grounds to expand and bubble. The main pour requires a steady circular motion, maintaining consistent flow rate, avoiding the center and edges where flow is least uniform. Some baristas pulse pour - multiple small additions - while others prefer continuous pouring. Each approach affects turbulence, temperature, and extraction. Temperature control is critical throughout the process. Water should be 200-205°F for most light and medium roasts, perhaps cooler for dark roasts to avoid over-extraction. But the temperature drops as soon as water leaves the kettle, and the slurry temperature can be 10-15 degrees cooler than your kettle temperature. The brewing vessel itself absorbs heat. Pouring too slowly allows excessive heat loss. Professional baristas monitor slurry temperature with thermometers during the process. Timing and ratio work together - standard starting points are 1:15 to 1:17 ratio (1g coffee to 15-17g water) with total brew time around 3:00-3:30 minutes. But these are guidelines, not rules. Different beans, roast levels, and grind sizes require adjustment. I keep detailed notes in a brewing journal - beans used, roast date, grind setting, water temp, ratio, brew time, and taste notes. Over hundreds of brews, patterns emerge that guide future attempts. The goal is repeatability - being able to produce the same cup on demand, then intentionally varying single variables to improve it."],
    ],
    "normaluser10" => [
      ["origin terroir characteristics", "idea", "Wine enthusiasts have long celebrated terroir - the unique combination of soil, climate, altitude, and growing conditions that make wines from different regions taste distinctly different even when made from the same grape variety. Coffee exhibits equally dramatic terroir effects, with beans from different origins having characteristic flavor profiles that experienced tasters can identify blind. Ethiopian beans, particularly from the Yirgacheffe region, are renowned for floral and fruity notes - jasmine, bergamot, blueberry, and lemon are common descriptors. The high altitudes (1,800-2,200 meters), volcanic soil, and traditional processing methods combine to create these delicate, tea-like coffees that bear little resemblance to the dark, bitter stereotype many people associate with the beverage. Some Ethiopian beans taste more like fruit tea than anything traditionally associated with coffee. These origins pioneered natural processing, and the wild, fermented fruit flavors that result have become highly prized. Colombian beans typically offer balanced, approachable profiles with medium body and bright acidity. Chocolate, caramel, and nut flavors predominate, with pleasant sweetness and clean finish. The diverse microclimates across Colombian growing regions create variation - some areas produce more fruit-forward beans while others lean toward cocoa and almond notes. Colombian coffee's reputation for consistency and quality makes it a reliable choice for blends and single-origin offerings. Brazilian beans, often grown at lower altitudes and typically natural processed, develop heavy body with low acidity. The flavor profile tends toward chocolate, nuts, and sweet spices, sometimes with a creamy texture that makes them popular for espresso. Brazilian coffee can taste almost dessert-like - rich, sweet, and smooth. Critics argue they lack the complexity and brightness of East African origins, but advocates appreciate their approachable sweetness and substantial body. Central American origins - Guatemala, Costa Rica, Panama, Honduras - share some characteristics while each maintains distinct personality. Guatemalan beans often have spicy, cocoa notes with full body and balanced acidity. Costa Rican beans typically show bright citrus acidity with honey sweetness. Panamanian Geisha, a varietal that has broken auction records, produces extraordinarily floral, delicate cups that taste like jasmine tea and tropical fruits. These differences aren't marketing fabrications or imagination - they're measurable chemical differences resulting from terroir factors. Altitude affects density and sugar development - higher altitude beans grow slower, developing more complex sugars and aromatic compounds. Soil composition influences what minerals and nutrients plants access. Climate affects ripening speed and consistency. Processing method dramatically impacts final flavor by determining how long beans remain in contact with fruit sugars during fermentation and drying. I've conducted informal tasting flights comparing beans from different origins, using identical roast levels and brewing methods. The differences are remarkable and consistent. Ethiopian naturals taste like blueberry pie. Kenyan beans have grapefruit and black currant acidity so bright it's almost aggressive. Indonesian beans develop earthy, herbal, sometimes almost savory characteristics. Understanding these regional characteristics helps you select beans matching your preferences. If you love bright, fruity flavors, explore East African origins. If you prefer chocolate and caramel notes, look toward Central and South American beans. If full body and low acidity appeal, try Indonesian or Brazilian origins. The diversity available in this single agricultural product rivals wine in its complexity."],
      ["home barista equipment guide", "essay", "Transitioning from casual consumer to serious home barista requires navigating a bewildering landscape of equipment options ranging from fifty dollar starter setups to multi-thousand dollar prosumer machines that rival commercial café gear. Understanding what actually matters versus what's merely nice to have can save you money and frustration while dramatically improving your daily cup. The grinder deserves the largest portion of your budget, possibly more than you spend on the brewing device itself. A quality burr grinder capable of producing consistent particle size distribution will improve your coffee more than any other single purchase. Blade grinders create uneven particles - some powder, some chunks - that simultaneously over-extract and under-extract, producing muddy, bitter, weak coffee. Decent burr grinders start around 200 dollars for manual models or 300 dollars for electric. Commercial-grade grinders like Baratza or Fellow models in the 300-500 dollar range offer stepless adjustment, consistent particle size, and minimal retention. If you plan to make espresso, grinders matter even more because the narrow optimal grind window demands fine adjustment capabilities. Many recommend spending as much on the grinder as the espresso machine, if not more. Brewing devices range from simple to complex, cheap to expensive, with quality results achievable across the spectrum. Pour-over devices like the V60, Chemex, or Kalita Wave cost 20-40 dollars and can produce exceptional coffee with proper technique. French press offers full immersion brewing for similar cost with different flavor profile - more body and texture but some sediment. The AeroPress, around 30 dollars, combines pressure and immersion with remarkable versatility. For espresso, the investment jumps significantly. Entry-level machines like the Breville Bambino start around 300 dollars, offering adequate pressure and temperature control. Mid-range machines in the 700-1500 dollar range add PID temperature control, better build quality, and more consistent results. High-end home machines from brands like Rocket, Profitec, or Decent cost 2000-4000 dollars, offering features like pressure profiling, pre-infusion, dual boilers for simultaneous brewing and steaming. At the top end, you find boutique machines costing 5000-10000 dollars that replicate commercial equipment. A quality kettle matters more than you'd think, particularly for pour-over brewing. A gooseneck spout provides precise pouring control essential for good extraction. Temperature control features let you dial in optimal temp for different beans. Electric kettles with built-in temperature control and hold functions like the Fellow Stagg EKG or Bonavita variable temp models cost 100-200 dollars. You can get by with cheaper options, but temperature control and pour control significantly impact consistency. A scale that measures to 0.1 gram accuracy is essential for repeatable results. Brewing by volume produces inconsistent results because grind changes density. The Hario V60 scale or Acaia Pearl scales, costing 30-100 dollars, allow you to weigh beans and water while timing your brew. Some fancy scales connect to smartphone apps that log your brews and guide your technique. Water matters enough that some enthusiasts invest in filtration systems or create custom water from distilled water and added minerals. A simple carbon filter pitcher (30 dollars) removes chlorine and off flavors. More elaborate systems can cost hundreds. Temperature measurement tools - thermometers for monitoring kettle temp or slurry temp during brewing - cost 10-30 dollars and provide useful data for troubleshooting and consistency. Some digital thermometers offer quick read times and waterproof construction. Don't neglect storage solutions. An airtight container that protects beans from oxygen, light, and moisture preserves freshness. Vacuum sealed canisters or one-way valve bags work well. You'll also need filters, cleaning supplies, and probably a dedicated space for your setup."],
    ],
    "normaluser11" => [
      ["milk steaming science", "thing", "The transformation of cold milk into silky microfoam involves precise temperature control and introduction of tiny air bubbles that create a velvety texture fundamentally different from the coarse, soapy foam produced by poor technique. Understanding the science of milk steaming separates average home espresso from café-quality cappuccinos and lattes. Milk contains proteins, fats, and sugars that each behave differently when heated and aerated. The proteins, primarily casein and whey, unfold when heated and form a stabilizing network around air bubbles. This is what creates stable foam rather than large bubbles that quickly separate. The fats contribute to mouthfeel and flavor, carrying aromatic compounds. The lactose sugars caramelize slightly when heated, creating sweetness that balances espresso bitterness. The steaming process has two distinct phases that require different techniques. The stretching phase, when you introduce air into the milk, should occur only in the first few seconds. The steam wand tip should sit just below the milk surface, creating a paper-tearing or hissing sound as air is sucked into the milk. This creates volume - the milk level rises in the pitcher as you incorporate air. The amount of air determines whether you're making latte foam (minimal air, ratio around 1:2 foam to liquid), cappuccino (more air, roughly 1:1), or dry cappuccino (even more air with stiff peaks). Most baristas aim for microfoam that's somewhere between liquid and foam - no distinct separation, just velvety textured milk. Once you've incorporated enough air, the texturizing phase begins. Plunge the steam wand deeper into the milk to create a whirlpool or rolling motion that breaks large bubbles into tiny ones and distributes them evenly. This phase should be silent or produce a gentle rumbling sound, not screeching or loud hissing. The whirlpool action creates the paint-like consistency that allows latte art - when you pour properly steamed milk into espresso, it should flow smoothly with visible white on top. Temperature management is critical and requires attention. Milk proteins begin denaturing around 140°F, reaching optimal foam stability at 150-155°F. Above 160-165°F, the proteins break down, the foam becomes less stable, and scalded flavors develop. Most baristas aim for finishing temperature around 140-150°F, knowing that temperature continues rising a few degrees after steaming stops. You can monitor temperature by touch (the pitcher becomes uncomfortable to hold around 140°F) or use a thermometer. Some high-end home machines include automatic temperature sensors. Milk type affects steaming behavior and final taste. Whole milk with 3-4% fat creates the richest, creamiest foam with best mouthfeel. Lower fat milk steams more easily (less fat to interfere with protein networks) but produces less flavorful results. Skim milk creates voluminous, stiff foam that's easier to stretch but lacks richness. Alternative milks pose challenges - most lack the protein and fat composition of dairy milk. Barista-specific formulations like Oatly Barista or specialty soy milks include added protein and fat to improve steaming performance. Oat milk has become popular for its neutral flavor and decent steaming properties, though it doesn't create quite the same microfoam as dairy. Almond milk is notoriously difficult to steam, often separating or curdling. Fresh milk matters more than you'd expect. Cold, fresh milk around 40°F steams best. Previously heated milk won't foam well because proteins have already denatured. Milk that's been open for a week doesn't steam as well as fresh milk. The pitcher shape and size matter too. A stainless steel pitcher with proper proportions (neither too narrow nor too wide) and a pointed spout for pouring allows better control of the whirlpool and easier latte art. Most baristas use 12-20oz pitchers depending on drink size. The steam wand itself matters - commercial machines have powerful boilers producing dry steam at high pressure, while home machines often have weaker steamers. More powerful steam allows faster heating with better texture. Practicing steaming technique takes time - hundreds of pitchers of milk to develop the muscle memory for proper wand angle, depth, and timing."],
      ["cold brew extraction differences", "idea", "Cold brew coffee, despite the name suggesting it's simply iced regular coffee, is actually a completely different beverage created through fundamentally different extraction chemistry. By using time and cold water instead of heat and speed, cold brewing extracts different compounds in different proportions, producing a concentrate with distinct flavor profile and chemical composition from hot-brewed coffee that's been chilled. The basic process involves steeping coarse-ground coffee in room temperature or cold water for 12-24 hours, then filtering out the grounds to leave a smooth concentrate. The extended contact time compensates for cold water's reduced extraction efficiency - hot water is a better solvent, pulling compounds from grounds more quickly and completely. Cold water extracts slowly and selectively, pulling certain compounds while leaving others behind. The chemistry of cold extraction creates the characteristic smooth, sweet, low-acid profile that makes cold brew popular. Hot water quickly extracts acidic compounds that contribute to brightness and acidity in hot-brewed coffee. Cold water extracts these acids much more slowly, resulting in significantly less acidity - pH tests show cold brew can be up to 70% less acidic than hot-brewed coffee. This makes it appealing to people with sensitive stomachs or acid reflux. The lower acidity also makes the inherent sweetness of the beans more apparent. Hot brewing also extracts bitter compounds quickly - particularly at higher temperatures. Cold brewing extracts these more slowly and selectively, producing smoother taste with less bitterness. The result can seem sweeter even though cold brew and hot brew have similar sugar content. The different bitterness perception changes the entire flavor balance. Oxidation occurs more slowly at cold temperatures, which is why cold brew stays fresh longer than hot-brewed coffee. Properly stored in the refrigerator, cold brew concentrate remains good for 7-10 days while hot-brewed coffee goes stale within hours. This makes cold brew practical for batch preparation - you can make a large batch and dilute portions as needed throughout the week. The concentrate format is another advantage. Most cold brew recipes use a 1:4 to 1:8 coffee to water ratio, producing concentrate that's diluted before drinking. A typical dilution is 1:1 or 1:2 concentrate to water or milk. This concentrate flexibility allows customization - want it strong? Less dilution. Prefer milder? More dilution. Making it hot? Just dilute with hot water instead of cold. The grind size for cold brew should be coarse - similar to French press. Finer grinds can create over-extraction and muddy flavors even with cold water, plus they make filtering difficult. Coarse grounds allow water to circulate and prevent clogging when you filter. Brewing vessel matters less than with hot methods. You can use a French press, a dedicated cold brew maker, or just a large jar or pitcher. Some people brew in a large container and strain through cheesecloth or paper filters. Others use specialized devices with built-in filters. As long as grounds stay fully immersed and you can filter them out afterward, the vessel is less critical. Brewing time allows for customization. Twelve hours produces lighter, more delicate concentrate. Twenty-four hours creates stronger, more full-bodied concentrate. Some people even go 36 hours for maximum extraction. Experimentation helps you find your preference. Temperature during brewing also varies - room temperature extracts faster than refrigerator temperature. Some people start at room temp then move to the fridge. The flavor profile differs from hot brewing in distinct ways. Cold brew emphasizes chocolate, caramel, and nutty notes while minimizing acidity, brightness, and some of the more delicate floral or fruity notes that heat brings out. This makes cold brew ideal for certain origins (like Brazilian or Indonesian beans) while potentially wasting the delicate characteristics of others (like Ethiopian beans). It's a different drink requiring different bean selection."],
    ],
    "normaluser12" => [
      ["historical origins of the beverage", "essay", "The story of how coffee conquered the world begins in the Ethiopian highlands, according to most legends, though separating myth from history at this distance is nearly impossible. The most famous tale involves a goat herder named Kaldi who noticed his goats became energetic after eating berries from a particular tree. He tried the berries himself, experienced their stimulating effects, and brought them to a local monastery where monks experimented with different preparations. Whether Kaldi actually existed is unknowable, but coffee certainly originated in Ethiopia, where wild coffee forests still grow and genetic diversity remains highest. From Ethiopia, coffee spread to Yemen, probably through trade connections across the Red Sea, sometime before the 15th century. Yemeni Sufi monasteries cultivated coffee and used the beverage to stay awake during night prayers and religious observances. The drink spread throughout the Islamic world - Egypt, Persia, Turkey - becoming a fixture of social and religious life. Coffee houses, called qahveh khaneh, opened throughout the Middle East, serving as social gathering places where people met to converse, listen to music, play games, and discuss news. These establishments became so important to social life that rulers occasionally tries to ban them, fearing they fostered political dissent. European travelers to the Ottoman Empire in the 16th and 17th centuries encountered coffee and brought it back to their home countries, though initial reception was mixed. Some religious authorities in Europe considered it a Muslim drink and therefore suspicious. Pope Clement VIII supposedly tasted coffee and enjoyed it so much he declared it acceptable for Christians, though this story might be apocryphal. Regardless, coffee houses spread across Europe - first in Venice, then throughout Italy, to Vienna, Paris, London, and elsewhere. These European coffee houses became crucial institutions of the Enlightenment, places where intellectuals, merchants, and ordinary citizens gathered to discuss ideas, conduct business, and share information. Lloyd's of London, the insurance market, began as a coffee house where merchants gathered to arrange maritime insurance. The London Stock Exchange similarly traces its roots to coffee house meetings. Coffee cultivation spread beyond Yemen as European powers sought to break the monopoly and establish their own sources. The Dutch successfully smuggled seedlings out of Yemen in the 1600s and established plantations in their colonies - first in Ceylon, then Java and Sumatra. The French obtained seedlings and planted them in Caribbean colonies. The Portuguese brought coffee to Brazil in the 1720s, beginning that nation's journey to becoming the world's largest coffee producer. This colonial expansion of coffee agriculture was intertwined with slavery and exploitation - Caribbean and Brazilian coffee plantations relied on enslaved African labor for centuries. The coffee industry's dark history of exploitation continues affecting producing regions today. North American coffee culture began in the colonial period, though tea remained more popular until the Boston Tea Party and American Revolution made coffee the patriotic choice. Coffee consumption in America increased dramatically through the 19th and 20th centuries. The Civil War required massive coffee supplies for Union armies - soldiers received regular rations and developed fierce loyalty to the drink. Soldiers returning home maintained their coffee habits, spreading consumption throughout the population. The 20th century brought industrialization and instant coffee - first Nescafé in 1938, then freeze-dried instant coffee in the 1960s. The Vietnam War saw instant coffee in soldier rations. Convenience and affordability trumped quality for most consumers. Then came Starbucks and the second wave in the 1990s, bringing espresso drinks and café culture to suburban America. Most recently, the third wave movement emphasizes quality, origin, and craft, bringing us full circle toward appreciation of coffee as an agricultural product with terroir and complexity rather than a mere caffeine delivery system. This centuries-long journey from Ethiopian forests to global commodity to artisanal craft beverage reflects changing social values, technological advances, colonial history, and our endless human desire for both stimulation and social connection."],
      ["cupping protocols and evaluation", "thing", "Professional quality assessment through cupping follows standardized protocols developed by the Specialty Coffee Association to ensure consistency across evaluators, regions, and sessions. The cupping process allows trained tasters to objectively evaluate green beans, compare roast profiles, and identify defects or exceptional qualities using a shared vocabulary and scoring system. Understanding cupping methodology reveals how professionals distinguish exceptional beans from merely good ones and how pricing structures emerge in the specialty market. The standard cupping protocol begins with roasting samples to a specific light roast profile - typically achieving first crack but not progressing far into development. This light roast preserves origin characteristics that darker roasting would obscure. Samples are roasted within 8-24 hours before cupping and allowed to rest. Each coffee is ground immediately before cupping at a specific coarseness, then placed in cups at a precise ratio - typically 8.25 grams of ground coffee per 150ml of water. The water temperature must be 200°F, and it's poured directly onto the grounds, saturating them completely. A crust forms on the surface as the grounds float and release aromatics. After exactly four minutes of steeping, the breaking ritual begins. The cupper leans close to each cup and uses a spoon to break through the crust, pushing grounds aside while inhaling deeply to evaluate the aromatic compounds released. This breaking moment provides crucial information about the coffee's fragrance and quality. Three breaks per cup allow the cupper to evaluate aroma intensity and character. After breaking, the cupper skims floating grounds from the surface using two spoons, removing foam and particles to leave clean liquid for tasting. The cups cool to approximately 160°F before tasting begins. The cupping spoon, a deep-bowled spoon designed for this purpose, is used to slurp coffee with force - the aggressive slurping aerosolizes the liquid, spreading it across the entire palate and nasal cavity to evaluate all flavor and aroma compounds simultaneously. This slurping technique, while sounding undignified, provides far more information than simply sipping would allow. Professional cuppers evaluate specific attributes using standardized scoring sheets. Fragrance and aroma are assessed first, noting intensity and character. Flavor receives careful attention - the specific taste characteristics and their quality. Aftertaste is evaluated separately from flavor, noting how long pleasant flavors linger and whether any unpleasant characteristics emerge after swallowing. Acidity is assessed not just for intensity but for quality - bright, sparkling acidity scores higher than sour or vinegary acidity. Body or mouthfeel describes the physical sensation - weight, texture, viscosity. Balance evaluates how well all components work together. Sweetness indicates the presence of pleasant sugar-like flavors. Clean cup assesses whether any off-flavors or defects interrupt the experience. Uniformity tracks consistency across multiple cups of the same sample. Overall impression captures the cupper's holistic assessment. Each attribute receives a score, typically on a scale where 6 represents good, 7 very good, 8 excellent, 9 outstanding, and 10 represents the absolute pinnacle rarely achieved. The scores combine to produce a total - specialty grade coffee must score 80 or above on the 100-point scale. Scores above 85 indicate excellent quality commanding premium prices. Scores above 90 are rare and indicate exceptional coffee worth significant investment. Cuppers train extensively to calibrate their palates with other professionals. Calibration sessions involve cupping the same samples and discussing scores to ensure everyone applies standards consistently. Experienced cuppers can detect subtle differences and identify specific defects - ferment, phenolic off-flavors from processing, baggy or musty flavors from poor storage, and contamination. The controlled cupping environment eliminates variables that complicate other tasting methods. No milk or sugar interferes with evaluation. The specific ratio, temperature, and timing ensure reproducibility. Multiple cups of each sample guard against individual cup variation. The process allows direct comparison of multiple origins, processing methods, or roast profiles side by side. While cupping differs dramatically from how consumers actually drink coffee - no one slurps from small cups at specific temperatures in daily life - it provides essential quality control and assessment methodology that benefits the entire supply chain from farmer to consumer."],
    ],
    "normaluser13" => [
      ["grinder burr geometry comparison", "idea", "The physical shape and material composition of burrs inside your grinder affect particle size distribution, grind consistency, and ultimately extraction quality more than most home enthusiasts realize. Conical burrs and flat burrs represent two fundamentally different approaches to grinding, each with distinct advantages, limitations, and resulting particle profiles that suit different brewing methods and taste preferences. Conical burrs feature a cone-shaped burr sitting inside a ring burr, with coffee beans fed from above and gradually crushed between the burrs as they spiral downward. Gravity assists the grinding process - beans move through the burr set efficiently without requiring aggressive feeding. This design generates less heat during grinding because the beans spend less time in the grinding chamber and conical burrs typically rotate at slower speeds than flat burrs. Lower heat generation better preserves volatile aromatic compounds that contribute to coffee flavor. Conical burrs tend to produce bimodal particle distribution - a concentration of particles at the target size plus a secondary population of very fine particles or fines. These fines can contribute to body and sweetness in the cup, though excessive fines can cause over-extraction and muddy flavors. The bimodal distribution makes conical burrs particularly well-suited for espresso, where some fines help create the viscosity and body expected in the final shot. Many high-end espresso grinders use conical burr designs precisely for this reason. Flat burrs position two parallel discs with matching grinding surfaces facing each other. Coffee beans are fed into the center and gradually worked outward toward the edges as the burrs rotate, with grinding occurring along the entire surface area. Flat burrs require more aggressive feeding mechanisms and typically rotate faster than conical burrs, generating more heat during extended grinding sessions. However, flat burrs produce more uniform particle distribution with fewer fines - a tighter peak around the target grind size. This uniformity often translates to better clarity and sweetness in the cup for filter brewing methods like pour-over or drip. Many specialty coffee professionals prefer flat burrs for filter coffee specifically because of this clarity. The particle shape also differs between burr types. Conical burrs tend to produce irregularly shaped particles with more surface area variation, while flat burrs create more uniform particle shapes. These shape differences affect extraction - irregular particles have more surface area exposed to water but may create more resistance to flow. Burr material matters as well - ceramic burrs stay sharp longer and generate less heat but can shatter if foreign objects enter the grinder. Steel burrs, either stainless or hardened tool steel, are more durable against impacts but require sharpening or replacement as they wear. Higher-end grinders use specialized coatings or treatments to extend burr life and improve performance. Burr size influences consistency and grinding speed. Larger burrs - measured in diameter for flat burrs or base diameter for conical burrs - can process beans more quickly while maintaining consistency because each bean requires fewer fracturing events to reach target size. Professional grinders feature burrs of 64mm, 75mm, or even 83mm, while home grinders typically range from 38mm to 64mm. Some ultra-premium home grinders now offer burr sizes previously reserved for commercial equipment. The gap between burrs determines grind size and is adjusted via the grinder's adjustment mechanism. Stepless adjustments allow infinite positioning within the range, while stepped adjustments lock into predetermined positions. Stepless provides more flexibility for dialing in espresso but can be harder to replicate a specific setting. Stepped adjustments offer repeatability but may not provide fine enough adjustment for espresso optimization. Alignment is a crucial but often overlooked factor - even expensive grinders can suffer from misaligned burrs where the gap isn't uniform around the circumference. Misalignment leads to inconsistent particle sizes despite high-quality burrs. Enthusiasts sometimes perform alignment modifications on home grinders, shimming burrs to achieve better concentricity and dramatically improving grind consistency. Different burr geometries exist even within conical and flat categories - various tooth patterns, angles, and cutting surface designs all affect how beans fracture and what particle distribution results. Manufacturers develop proprietary burr designs and often tout specific geometries as advantages. SSP burrs, Mazzer burrs, and other aftermarket options allow enthusiasts to modify grinder performance by replacing stock burrs with different designs optimized for specific brewing methods or flavor profiles."],
      ["varietal differences in the plant", "essay", "Coffee as a plant species exhibits remarkable diversity, with different varietals producing beans of distinctly different sizes, shapes, chemical compositions, and flavor profiles. Understanding varietal differences helps explain why two coffees from the same region, grown by neighboring farmers, can taste completely different and command vastly different prices in the specialty market. All commercial coffee belongs to two main species - Coffea arabica and Coffea canephora, commonly called robusta. Arabica represents roughly 60-70% of global production and includes all specialty grade coffee due to its superior flavor complexity. Robusta, while hardier and more disease-resistant, produces harsher, more bitter coffee typically used in instant coffee and low-grade commercial blends. Within arabica alone, dozens of varietals exist, each with distinct characteristics. The most common traditional varietals are Typica and Bourbon, which serve as genetic foundations for many other cultivars. Typica, one of the oldest varietals, produces excellent cup quality with complex flavors but suffers from low yields and high susceptibility to leaf rust disease. The plants are tall with wider spacing between branches, making harvesting more labor-intensive. Despite these challenges, Typica genetics underlie many prized coffees, and some farmers maintain Typica plantings specifically for quality even when economics favor other choices. Bourbon, another foundational varietal, offers slightly better yields than Typica with similarly excellent cup quality. Bourbon plants are more compact with closer branch spacing and produce more cherries per tree. The cherries ripen to various colors depending on sub-varietal - red, yellow, or pink Bourbon all exist. Many specialty coffees, particularly from Latin America and East Africa, trace their lineage to Bourbon genetics. The cup profile often includes sweetness, balanced acidity, and complexity that make Bourbon a benchmark for quality. Geisha, sometimes spelled Gesha after its Ethiopian origins, has become legendary in specialty coffee circles for its extraordinary floral and tea-like cup profile. Geisha plants are tall and delicate with lower yields, making them expensive to cultivate. However, the remarkable flavor - often described as jasmine, bergamot, tropical fruits, and delicate florals - commands record-breaking prices at auction. Panama Geisha holds particular prestige after Hacienda La Esmeralda's Geisha lots began winning competitions and selling for hundreds of dollars per pound. The Geisha phenomenon sparked varietal consciousness in the industry, proving that genetic factors could justify dramatic price premiums. Caturra, a natural mutation of Bourbon discovered in Brazil, offers higher yields through a dwarf growth habit. The shorter plants with compact spacing allow higher density plantings, increasing productivity per hectare. Caturra maintains much of Bourbon's cup quality while improving farm economics, making it popular throughout Latin America. Various regional Caturra strains have developed different characteristics based on terroir and selection. SL28 and SL34, varietals developed by Scott Laboratories in Kenya during the 1930s, are renowned for the distinctively bright, complex, and fruit-forward profiles characteristic of Kenyan coffee. These varietals show excellent cup quality with the winey acidity and blackcurrant notes that make Kenyan coffee recognizable to trained tasters. However, both varietals suffer from susceptibility to coffee berry disease and leaf rust, requiring careful management. Hybrid varietals bred for disease resistance and climate resilience include Catimor and Sarchimor, which cross arabica with robusta genetics to capture robusta's hardiness. Unfortunately, these hybrids often sacrifice cup quality - the robusta genetics can introduce harsh, bitter flavors. Newer breeding programs attempt to develop varieties that maintain arabica quality while adding robusta's disease resistance. Varieties like Castillo in Colombia or various F1 hybrids show promise in combining quality with agricultural practicality. Climate change is forcing the industry to take varietal selection more seriously. Traditional varietals grow best at specific altitudes and temperature ranges that are shifting as global temperatures rise. Disease pressure increases in warmer, wetter conditions. Farmers must choose between maintaining traditional varietals with superior cup quality but increasing risk, or switching to hardier varietals that may not command premium prices. Some research institutions and progressive farms experiment with varietal trials, planting multiple genetypes side-by-side to determine what performs best in local conditions while meeting quality standards buyers demand. The relationship between varietal and terroir complicates matters further - a varietal that excels in one microclimate might underperform elsewhere, making universal recommendations impossible."],
    ],
    "normaluser14" => [
      ["water chemistry for optimal extraction", "thing", "Water comprises over 98% of brewed coffee, yet most home brewers give it almost no consideration beyond whether it tastes okay from the tap. Professional baristas and serious enthusiasts understand that water chemistry dramatically affects extraction efficiency, flavor balance, and equipment longevity. The minerals dissolved in your water determine whether you'll extract sweet, complex flavors or harsh, muddy bitterness from identical beans using identical techniques. Total dissolved solids, measured in parts per million, indicates the overall mineral content of your water. The Specialty Coffee Association recommends 75-250 ppm TDS for brewing, with an ideal range around 150 ppm. Water with very low TDS, like distilled water or reverse osmosis water, extracts poorly and produces flat, dull coffee lacking complexity. Water with very high TDS over-extracts and can create mineral buildup in equipment. The specific minerals matter more than total TDS alone. Calcium and magnesium, collectively called hardness, contribute to extraction by binding with flavor compounds in the coffee and pulling them into solution. Some calcium is beneficial for extraction, but excessive hardness creates scale buildup in kettles, espresso machines, and other equipment, requiring descaling and potentially causing equipment failure. The ideal hardness range is roughly 50-175 ppm as calcium carbonate equivalent. Alkalinity, primarily from bicarbonate, acts as a buffer that neutralizes acids. Some alkalinity is desirable because it prevents coffee from tasting overly sour or acidic. However, excessive alkalinity over-neutralizes coffee's desirable acids, creating flat cups lacking brightness and complexity. The ideal alkalinity range is approximately 40-75 ppm. The ratio between hardness and alkalinity particularly matters - water can have appropriate TDS but poor flavor results if the mineral balance is wrong. Sodium and chloride also influence flavor. Moderate sodium enhances sweetness perception, while excessive sodium makes coffee taste salty. Chloride can increase mouthfeel and sweetness in small amounts but creates strange metallic or chemical flavors at higher concentrations. Most brewing water should have minimal sodium and chloride - typically under 30 ppm of each. Testing your water is the first step toward optimization. Home test strips provide rough measurements of hardness and alkalinity. More accurate testing requires TDS meters for total dissolved solids and proper titration kits or laboratory testing for specific mineral levels. Many municipal water suppliers publish water quality reports showing mineral content, though this represents averages that may not match what comes from your specific tap. Bottled water varies tremendously in mineral composition. Some bottled spring waters have ideal composition for coffee brewing - Crystal Geyser and others popular in coffee communities have favorable mineral profiles. Distilled and reverse osmosis waters have almost no minerals and require mineralization before brewing. Enthusiasts often create custom water by starting with distilled or RO water and adding specific minerals to achieve target composition. Several commercial products exist for water optimization. Third Wave Water and other similar products provide mineral packets you add to distilled water, creating water with specific mineral profiles optimized for coffee extraction. Some products offer different formulas for different coffee styles - light roast versus dark roast, or espresso versus filter coffee. DIY water recipes circulate in online communities, with various formulas specifying exact amounts of epsom salt for magnesium, baking soda for alkalinity, and other minerals to add to distilled water. The most famous is probably the Barista Hustle water recipe or various iterations of it. Creating custom water sounds extreme, but for someone investing in expensive beans, quality grinders, and precise brewing techniques, water chemistry represents one of the few remaining variables that can transform mediocre results into excellent ones. Two identical pour-overs with identical beans and technique can taste dramatically different based solely on water mineral content. Equipment longevity also depends on water quality. Espresso machines cost hundreds to thousands of dollars and can be destroyed by scale buildup from hard water. Water softeners remove calcium and magnesium but typically replace them with sodium, which creates different problems. Inline water filters can reduce hardness and remove chlorine but may not address alkalinity. Some espresso machines include built-in water softening or filtration, though the effectiveness varies. For espresso specifically, water composition affects not just extraction and flavor but also machine function. The boiler pressure, temperature stability, and pump operation all depend on appropriate water chemistry. Some manufacturers specify maximum hardness levels for warranty coverage, voiding warranties if scale damage occurs from inappropriate water. The interaction between water chemistry and coffee chemistry is complex and still being researched. Different roast levels and different origins may extract optimally with different water profiles. Light roasts with bright acidity might benefit from lower alkalinity to preserve those acids, while darker roasts might need more alkalinity to prevent excessive acidity. Experimentation with your specific equipment, beans, and local water conditions ultimately determines what works best."],
      ["decaffeination process variations", "idea", "Removing caffeine from coffee beans while preserving flavor compounds represents a significant technical challenge, with multiple commercial processes offering different trade-offs between effectiveness, cost, and impact on cup quality. Understanding how decaffeination works reveals why decaf coffee often tastes different from regular coffee and why some decaf coffees taste significantly better than others. All decaffeination processes occur before roasting, using green beans as the starting material. Caffeine must be extracted from the bean structure while minimizing removal of the flavor compounds, oils, and other constituents that create coffee's taste. This is chemically difficult because caffeine and many flavor compounds have similar properties - both are organic molecules that respond to similar solvents and conditions. The oldest commercial method, direct solvent decaffeination, uses chemical solvents like methylene chloride or ethyl acetate to extract caffeine. Green beans are steamed to open their pore structure, then soaked in or rinsed with solvent that binds to caffeine molecules and removes them. The beans are steamed again to evaporate any residual solvent, then dried. This process can achieve 97-99% caffeine removal but also strips some flavor compounds, and many consumers object to chemical solvents touching their food despite safety assurances. Ethyl acetate, which occurs naturally in fruits, is sometimes marketed as natural decaffeination to distinguish it from methylene chloride. The Swiss Water Process, developed in Switzerland and now primarily performed in Canada, uses no chemical solvents. Green beans are soaked in hot water, which extracts both caffeine and flavor compounds. This first batch of beans is discarded, but the flavor-saturated water is passed through activated charcoal filters that trap caffeine molecules while allowing smaller flavor molecules through. The resulting Green Coffee Extract contains coffee flavor compounds but no caffeine. New batches of beans are soaked in this GCE - the saturation of flavor compounds in the water prevents further flavor loss from the beans while caffeine, which isn't saturated in the GCE, continues to migrate out of the beans into the water. The water is continuously filtered to remove caffeine while maintaining flavor compound saturation. The Swiss Water Process is chemical-free and preserves flavor better than solvent methods, though it's more expensive and time-consuming. The cup quality of Swiss Water decaf often exceeds solvent-processed decaf, making it popular in specialty coffee. The CO2 process uses liquid carbon dioxide under high pressure to extract caffeine. Green beans are soaked in water, then placed in a pressure vessel where CO2 at about 250-300 times atmospheric pressure acts as a solvent, binding to caffeine molecules. The caffeine-laden CO2 is then passed through water or activated charcoal to remove the caffeine, and the CO2 is recirculated. This process is highly selective for caffeine over flavor compounds and achieves excellent caffeine removal while preserving flavor. However, it requires expensive pressure equipment, making it economically viable only for large-scale operations. CO2 decaf often shows excellent cup quality comparable to Swiss Water. Regardless of process, decaffeination affects coffee in several ways beyond removing caffeine. The beans undergo physical changes - they become more porous and brittle, affecting how they roast. Decaf beans typically roast faster and darker than regular beans at the same temperature settings because their altered structure allows heat penetration more rapidly. Roasters must adjust their profiles for decaf beans to avoid overdevelopment. The flavor profile of decaf typically differs from regular coffee even with the best processing. Some volatile aromatic compounds inevitably wash out during decaffeination alongside caffeine. The cup often lacks some of the brightness, complexity, and aromatic intensity of regular coffee from the same origin. However, high-quality decaf from good origins processed carefully can still produce genuinely enjoyable coffee - it's no longer the flavorless disappointment it once was. The origin bean quality matters enormously for decaf. Starting with high-quality specialty grade beans produces better decaf than starting with commodity grade beans. Some specialty roasters now offer single-origin decafs from specific farms, processed using Swiss Water or CO2 methods, that score well in cupping and satisfy specialty coffee standards. These premium decafs cost more than regular coffee because you're paying for high-quality green beans plus expensive decaffeination processing. The market for quality decaf has grown as the specialty coffee movement matured. Some consumers avoid caffeine for health reasons, pregnancy, sensitivity, or wanting to drink coffee in the evening without sleep disruption. These consumers increasingly demand decaf that meets the quality standards they expect from specialty coffee rather than accepting inferior products. Roasters have responded by sourcing better decaf and treating it with the same care as regular offerings."],
    ],
    "normaluser15" => [
      ["flavor wheel and cupping lexicon", "essay", "The standardized vocabulary for describing coffee flavors evolved from subjective, inconsistent descriptions toward a shared lexicon that allows professionals worldwide to communicate about sensory experiences with precision. The SCAA Coffee Taster's Flavor Wheel, updated in collaboration with World Coffee Research, represents the most comprehensive attempt to categorize and organize the flavor and aroma compounds found in coffee, providing a visual reference that guides evaluation and communication. The flavor wheel arranges descriptors in a hierarchical structure, moving from general categories at the center to increasingly specific descriptors toward the outer edges. The center identifies the broadest categories - fruity, floral, sweet, nutty, spicy, roasted - which branch into more specific subcategories and ultimately to precise descriptors like blackcurrant, jasmine, caramel, hazelnut, cinnamon, or dark chocolate. This organization helps tasters identify flavors systematically rather than grasping for random descriptors. When cupping, a taster might first identify a general fruity character, then narrow it to berry-like, then further specify it as blueberry or blackcurrant. The vocabulary development drew on sensory science research and chemical analysis. Many flavor compounds in coffee exist in other foods - the same chemical that creates berry flavors in actual berries exists in coffee beans from certain origins. When trained tasters describe Ethiopian coffee as having blueberry notes, they're detecting actual shared chemical compounds, not engaging in pretentious metaphor. The flavor wheel helps calibrate tasters by providing shared references everyone can study. Training involves tasting actual reference samples - smelling real cinnamon, tasting actual caramel, experiencing fresh lemon - to build mental libraries of these flavors. Then when those compounds appear in coffee, tasters can accurately identify and describe them. Professional cuppers undergo extensive sensory training using Le Nez du Café and similar aroma kits that present isolated flavor compounds found in coffee. The cupping lexicon extends beyond flavor descriptors to include terminology for other sensory attributes. Acidity descriptions include qualitative terms - bright, sparkling, crisp, juicy, winey - that indicate not just acid presence but its character and quality. Body or mouthfeel descriptors range from light, delicate, or tea-like through medium and balanced to heavy, syrupy, or viscous. These textural characteristics relate to lipid content, dissolved solids, and particle suspension. Aftertaste receives specific attention with descriptors like clean, lingering, sweet, or describing what flavors persist after swallowing. A coffee might have pleasant fruit flavors initially but develop unpleasant bitter aftertaste, which the cupping form captures separately. Balance describes how all components work together - whether any single attribute dominates to the detriment of others or whether acidity, sweetness, body, and flavor integrate harmoniously. Defect descriptors form their own category within the lexicon. Fermented, sour, rancid, musty, moldy, earthy, phenolic, medicinal, woody - these terms indicate processing errors, storage problems, or contamination. Trained cuppers can identify specific defects and often determine their likely causes. A fermented note suggests over-fermentation during processing. Musty or moldy flavors indicate moisture damage during storage. Phenolic or medicinal flavors can come from certain processing water sources or equipment. The standardized vocabulary allows quality control throughout the supply chain. A buyer in New York can communicate with a producer in Guatemala using shared descriptors, ensuring both parties discuss the same sensory characteristics. Competition judges evaluate coffee using standardized forms and vocabulary, making scores comparable across judges and competitions. The cupping form used in professional evaluation breaks sensory assessment into specific scored attributes. Fragrance describes aromatics from dry grounds before water addition. Aroma describes the smell of coffee after water hits the grounds and during the break. Flavor captures the primary taste sensations. Aftertaste assesses what remains after swallowing. Acidity receives both intensity and quality ratings. Body describes mouthfeel and texture. Balance evaluates how attributes work together. Uniformity tracks consistency across multiple cups. Clean cup indicates freedom from off-flavors. Sweetness assesses pleasant sugar-like impressions. Overall captures the cupper's holistic impression. The vocabulary continues evolving as the industry discovers new flavor experiences. Experimental processing methods create novel flavor profiles that existing descriptors struggle to capture. Anaerobic fermentation coffees might taste like bourbon, beer, or wine in ways traditional coffee never did. Tasters develop new descriptors or borrow from other industries - wine terminology, beer terminology, culinary terminology - to describe these new experiences. Critics sometimes argue the vocabulary has become overly elaborate or pretentious. Descriptions of passionfruit, lemongrass, Earl Grey tea, or brown sugar might sound like marketing speak to skeptics. However, for trained palates, these descriptors communicate real sensory experiences more precisely than vague terms like good or smooth. The flavor wheel and cupping lexicon serve practical functions - quality control, pricing, selection, blending - that require precision beyond casual language provides."],
      ["single origin versus blends philosophy", "thing", "The choice between single origin coffee and blends represents different philosophies about what coffee should be and what role the roaster plays in creating the final product. Single origin showcases a specific farm, region, or cooperative, celebrating terroir and allowing consumers to taste place. Blends combine coffees from multiple origins to achieve specific flavor profiles, consistency, or balance that individual origins might not provide. Both approaches have merit and serve different purposes in the specialty coffee landscape. Single origin coffee emphasizes transparency and traceability - you know exactly where the beans came from, often down to specific farm or cooperative, processing method, varietal, and harvest date. This transparency allows appreciation of terroir, the unique environmental and agricultural factors that make each origin distinctive. An Ethiopian Yirgacheffe tastes recognizably different from a Colombian Huila or Guatemalan Antigua because of soil, altitude, climate, processing, and genetics. Single origin coffee invites you to explore these differences and develop preferences based on origin characteristics. The single origin philosophy aligns with the third wave movement's emphasis on coffee as an agricultural product with complexity and diversity similar to wine. Just as wine enthusiasts celebrate different regions, vintages, and terroirs, coffee enthusiasts explore different origins, processing methods, and microlots. Single origin allows farmers and regions to develop reputations for quality, commanding premium prices that reward excellence and encourage continued investment in quality. From a roasting perspective, single origin presents both opportunities and challenges. The roaster can develop a roast profile specifically optimized for that particular bean's characteristics - lighter roasts for delicate Ethiopian naturals to preserve floral notes, or slightly darker roasts for Brazilian beans to enhance chocolate and caramel sweetness. However, single origin coffee varies from harvest to harvest, creating consistency challenges. A Colombian coffee from last year's harvest might taste somewhat different from this year's harvest even from the same farm. Seasonal variation, weather patterns, and processing variations all affect flavor. Blends offer different advantages, primarily consistency and balance. By combining coffees from multiple origins, the roaster creates a flavor profile that remains consistent year-round despite individual components changing. If one origin from the blend becomes unavailable or changes character, it can be replaced with a similar origin without dramatically altering the blend. For cafés serving espresso drinks, this consistency matters enormously - customers expect their latte to taste the same week after week. Blending also allows roasters to create complexity and balance that individual origins might not achieve alone. A blend might combine a bright, acidic Colombian coffee for vibrancy, a heavy-bodied Sumatran coffee for texture, and a sweet Brazilian coffee for balance. The resulting cup offers complexity from multiple terroirs while achieving balance no single origin provides. This creative aspect of blending positions the roaster as an artist combining ingredients rather than simply a processor highlighting someone else's agricultural product. Espresso blends particularly benefit from the blending philosophy. The high-pressure, high-temperature extraction of espresso amplifies both positive and negative characteristics. A single origin that tastes bright and complex as filter coffee might taste aggressively sour as espresso. A single origin with full body and low acidity might taste one-dimensional and heavy as espresso. Blending allows the creation of espresso-specific profiles with sweetness, balanced acidity, syrupy body, and clean finish that work well both as straight shots and in milk drinks. The economics differ between single origin and blends. Single origin, particularly microlots from specific farms, typically costs more per pound because of smaller production volumes, premium quality, and the traceability infrastructure required. Blends can incorporate a range of price points - using premium coffees for character and more affordable coffees for body and balance - achieving good flavor at moderate cost. Specialty coffee consumers often seek single origin for its transparency and origin expression, while casual consumers might prefer blends for approachability and consistency. Some specialty roasters offer both - a rotating selection of single origins for enthusiasts to explore plus signature blends that represent the roaster's style and provide consistency. The philosophical divide sometimes creates tension in specialty coffee circles. Single origin purists argue that blending obscures terroir and reduces coffee to a commodity. Blend advocates counter that roasters should use their skills to create intentional flavor profiles rather than simply showcasing someone else's agricultural product. Both perspectives have merit, and neither approach is inherently superior - they serve different purposes and appeal to different preferences."],
    ],
    "normaluser16" => [
      ["quantum entanglement explained simply", "essay", "<p><strong>Quantum entanglement</strong> represents one of the most counterintuitive phenomena in modern [physics], challenging our everyday understanding of how the universe works at its most fundamental level. When two particles become entangled, measuring the state of one particle <em>instantly</em> determines the state of the other, regardless of the distance separating them.</p><p>This instantaneous correlation troubled even [Albert Einstein], who famously dismissed it as 'spooky action at a distance.' Yet decades of experimental verification have confirmed that quantum entanglement is not just a theoretical curiosity but a real feature of our universe with profound implications for [quantum computing], [cryptography], and our understanding of [reality] itself.</p><p>The basic principle involves creating pairs of particles - typically [photons] or [electrons] - that share a quantum state. Until measured, each particle exists in a [superposition] of multiple possible states simultaneously. The remarkable feature is that measuring one particle's state immediately collapses the wavefunction of its entangled partner, fixing its state too, even if the particles are separated by vast distances across the universe.</p><p>Applications of quantum entanglement drive cutting-edge research in quantum technologies. [Quantum computers] exploit entanglement to perform calculations that classical computers could never accomplish. Quantum cryptography uses entanglement to create theoretically unbreakable encryption keys.</p>"],
      ["quantum superposition in computing", "thing", "<p>The concept of <strong>quantum superposition</strong> - where quantum systems exist in multiple states simultaneously until measured - provides the foundational principle enabling quantum computers to vastly outperform classical computers for certain computational tasks.</p><p>Unlike classical [bits] that must be either 0 or 1, quantum bits or [qubits] can exist in a superposition of both states at once. When you have multiple qubits, the system exists in a superposition of <em>all possible combinations</em> simultaneously, allowing parallel processing of an exponentially large solution space.</p><p>Two entangled qubits exist in superposition of four states (00, 01, 10, 11) simultaneously. Three qubits exist in eight states at once. Twenty qubits exist in over one million states. Fifty qubits exist in more states than there are [atoms] in the [solar system].</p><p>This exponential scaling explains why quantum computers promise revolutionary capabilities for problems like [cryptography], drug discovery, materials science, and optimization challenges. However, maintaining superposition is extraordinarily difficult - any interaction with the environment causes [decoherence], collapsing the delicate quantum state into a definite classical state.</p><p>Current quantum computers operate at temperatures near [absolute zero] and employ sophisticated error correction to preserve superposition long enough to perform useful calculations.</p>"],
      ["quantum tunneling through barriers", "idea", "<p><strong>Quantum tunneling</strong> allows particles to pass through energy barriers that classical physics says should be impenetrable, explaining phenomena from [radioactive decay] to the fusion reactions powering the [sun].</p><p>In classical physics, a ball rolled toward a hill without sufficient energy simply rolls back down. But in the quantum realm, particles have a probability of appearing on the other side of barriers even when they lack the energy to climb over. This isn't particles going around or through holes - it's a fundamental consequence of [wave-particle duality] and the probabilistic nature of quantum mechanics.</p><p>The mathematics of quantum tunneling describe particles as <em>probability waves</em> that don't abruptly stop at barriers but rather decay exponentially through them. If the barrier is thin enough, a portion of the wave function extends to the other side, giving the particle a non-zero probability of being detected there.</p><p>Applications of quantum tunneling pervade modern technology. [Scanning tunneling microscopes] use controlled tunneling to image individual atoms on surfaces. [Flash memory] in computers relies on electrons tunneling through insulating barriers. Nuclear fusion in stars proceeds at temperatures far lower than classical physics would require because particles tunnel through the electromagnetic repulsion barrier.</p><p>Understanding quantum tunneling was crucial to developing the [transistor] and virtually all modern [semiconductor] devices.</p>"],
    ],
    "normaluser17" => [
      ["quantum entanglement explained simply", "idea", "<p>Look, this whole <strong>quantum entanglement</strong> thing is fucking amazing when you really think about it. Two particles get linked together and boom - measure one, and you instantly know about the other, no matter how far apart they are.</p><p>Einstein hated this spooky action at a distance crap, but experiments prove it works. The particles don't send signals to each other - they're just correlated in this weird quantum way that makes no sense classically.</p><p>What's really wild is how [quantum computers] and [encryption] systems exploit this. You can use entangled [photons] to create communication channels that are theoretically unbreakable because any eavesdropping collapses the quantum state and gets detected.</p><p>This isn't science fiction - it's real physics that's been verified thousands of times in labs around the world. The universe is stranger than we ever imagined.</p>"],
    ],
    "normaluser24" => [
      ["quantum tunneling through barriers", "essay", "<p>The phenomenon of <strong>quantum tunneling</strong> fundamentally challenges our classical intuitions about barriers and energy, revealing that particles can traverse energy barriers they classically lack sufficient energy to overcome. This isn't some theoretical curiosory - it's essential to understanding [nuclear fusion] in stars, [radioactive decay], and the operation of countless electronic devices.</p><p>Consider a particle approaching an energy barrier. Classically, if the particle's energy is less than the barrier height, it must reflect back. But quantum mechanically, the particle's wavefunction doesn't abruptly terminate at the barrier. Instead, it penetrates into and through the barrier with exponentially decreasing amplitude.</p><p>If the barrier is sufficiently thin, a non-zero portion of the wavefunction emerges on the other side. This means there's a finite probability of detecting the particle beyond the barrier, even though it never had enough energy to 'climb over' classically. The particle has <em>tunneled through</em>.</p><p>Real-world applications abound. The [scanning tunneling microscope] exploits controlled tunneling of electrons between a sharp tip and a sample surface to achieve atomic-resolution imaging. [Flash memory] stores data by trapping electrons behind barriers they can only escape via tunneling. [Tunnel diodes] use quantum tunneling for ultra-fast switching in electronics.</p><p>Perhaps most remarkably, nuclear fusion in the sun's core proceeds via tunneling. At solar core temperatures, hydrogen nuclei lack sufficient energy to overcome their electromagnetic repulsion classically. But quantum tunneling allows fusion to occur at much lower temperatures than classical physics would require, making stellar evolution and life on Earth possible.</p>"],
      ["quantum supremacy demonstrations", "idea", "<p>This whole <strong>quantum supremacy</strong> shit is basically about proving quantum computers can do something classical computers can't handle. [Google] claimed they hit it in 2019 with some sampling task that took 200 seconds on their quantum chip but would take thousands of years on a regular [supercomputer].</p><p>Of course [IBM] called bullshit and said they could do it in a few days with better algorithms. That's the problem with these demonstrations - they pick very specific tasks designed to make quantum look good.</p><p>The real question is whether this cock-measuring contest actually matters for solving problems people care about. Most everyday computing? Classical computers win hands down and always will. Quantum is only better for certain specific things.</p><p>But for [cryptography], [drug discovery], and simulating quantum systems, the advantage could be huge once the hardware matures. We're still in the early days.</p>"],
    ],
    "normaluser25" => [
      ["quantum sensing and metrology", "idea", "<p>So <strong>quantum sensing</strong> is all about using quantum weirdness to measure stuff way more precisely than normal sensors can. The same properties that make quantum computers so damn fragile - like how they respond to tiny environmental changes - actually become useful for sensing.</p><p>Atomic clocks use quantum transitions in atoms to keep time so accurately they wouldn't lose a second over billions of years. That's not just for bragging rights - it's essential for [GPS] and telecommunications.</p><p>Then you've got quantum magnetometers that can detect magnetic fields millions of times weaker than Earth's field. Medical applications include mapping brain activity by detecting the tiny magnetic signals from neurons. Pretty wild when you think about it.</p><p>Quantum gravimeters measure variations in gravity to find underground mineral deposits, oil, or hidden tunnels. Quantum gyroscopes detect rotation with extreme precision for navigation where GPS doesn't work.</p><p>The future applications are even crazier - microscopes that beat the diffraction limit, radar that can spot stealth aircraft, thermometers for measuring temperature at the nanoscale. This is one area where quantum tech is already proving practical.</p>"],
    ],
    "normaluser26" => [
      ["quantum machine learning prospects", "essay", "<p><strong>Quantum machine learning</strong> represents the intersection of two of computing's most hyped frontiers, promising to accelerate neural network training, discover patterns classical algorithms miss, or enable entirely new machine learning paradigms - though separating genuine potential from marketing buzzword combinations remains difficult.</p><p>Several theoretical avenues suggest quantum speedups. Quantum computers might search high-dimensional parameter spaces more efficiently during training. Quantum random access memory could manipulate large datasets in superposition, evaluating many data points simultaneously. Algorithms like HHL for solving linear systems offer exponential speedup for certain tasks - if you can efficiently prepare quantum states from classical data, which is a massive 'if' in practice.</p><p>The quantum support vector machine and quantum principal component analysis show theoretical promise for classification and dimensionality reduction. Variational quantum circuits could discover feature representations impossible for classical networks.</p><p>However, enormous caveats apply. Most quantum machine learning algorithms assume data is already in quantum form, requiring expensive state preparation. Reading results collapses quantum superpositions, severely limiting information extraction. Classical machine learning continues rapid improvement - quantum computers must compete with better algorithms and specialized AI chips.</p><p>Current demonstrations use toy problems with small datasets on noisy intermediate-scale quantum devices. Whether practical quantum advantage exists for real-world machine learning workloads remains speculative. The field is intellectually fascinating but far from demonstrating clear utility, and skepticism about near-term applications is warranted despite the hype.</p>"],
      ["quantum cryptography protocols", "idea", "<p>Man, <strong>quantum cryptography</strong> is the real deal for security. Unlike regular crypto that relies on math problems being hard, quantum crypto's security comes from the actual laws of physics. Try to intercept a quantum key and you inevitably fuck up the quantum states, which gets detected.</p><p>The BB84 protocol encodes bits in [photon] polarization states. Any eavesdropper measuring the photons necessarily disturbs them because of the uncertainty principle. This isn't theoretical - actual quantum key distribution networks are running in [China], [Europe], and other places.</p><p>[China's Micius satellite] demonstrated quantum key distribution over 1200 kilometers, proving this works for satellite links. That's a huge deal for global secure communications.</p><p>The catch is you need specialized hardware - single-photon sources, sensitive detectors, the whole nine yards. And quantum key distribution only solves the key sharing problem. You still need regular encryption for the actual messages.</p><p>But for high-security applications where you absolutely cannot risk key interception, quantum crypto offers guarantees no classical system can match. The physics doesn't lie.</p>"],
    ],
    "normaluser27" => [
      ["quantum dots in nanotechnology", "idea", "<p><strong>Quantum dots</strong> are these tiny semiconductor crystals, like 2-10 nanometers across, that glow different colors depending on their size. The smaller ones emit blue light, bigger ones red - it's all due to quantum confinement effects when you get down to nanoscale dimensions.</p><p>QLED TVs use quantum dots to get way better color than regular LED displays. When blue LED light hits quantum dots of precisely tuned sizes, they emit pure red and green that combine for more vibrant colors than conventional displays can manage.</p><p>In biology, quantum dots attach to antibodies to fluorescently label specific cells or proteins. They're brighter and more stable than traditional organic dyes, making them superior for microscopy applications.</p><p>Solar cells with quantum dots might exceed normal efficiency limits through multiple exciton generation - basically getting more bang for your buck from each absorbed photon.</p><p>The technology has moved from research labs to commercial products remarkably fast. This is one area where nanotechnology hype actually delivered real products people use every day.</p>"],
      ["quantum annealing for optimization", "idea", "<p>Okay so <strong>quantum annealing</strong> is this different approach to quantum computing that's actually further along than the gate-based universal quantum computers everyone talks about. Instead of running algorithms, you encode an optimization problem directly into the hardware.</p><p>The system starts in a quantum superposition and gradually 'anneals' toward the lowest energy state, which corresponds to the optimal solution. The quantum part is that it can tunnel through energy barriers instead of getting stuck in local minima like classical algorithms do.</p><p>[D-Wave] has sold quantum annealers with thousands of qubits, way more than universal quantum computers have. But these qubits are specialized - they only do optimization, not general quantum computation.</p><p>Applications include [machine learning], portfolio optimization, protein folding, traffic flow, logistics. The big debate is whether current devices actually show quantum advantage over classical optimization algorithms. Some problems seem to benefit, others not so much.</p><p>It's a pragmatic approach - build specialized quantum hardware for one class of problems rather than trying to build a fully universal quantum computer. For certain optimization tasks, it might be the first quantum tech that proves genuinely useful.</p>"],
    ],
    "normaluser28" => [
      ["quantum communication networks", "idea", "<p>The vision of a <strong>quantum internet</strong> is pretty wild - instead of routing bits through intermediate nodes like the regular internet, you'd distribute quantum entanglement and use teleportation to transmit quantum states while maintaining coherence end-to-end.</p><p>Building blocks include quantum repeaters that extend range beyond the 100km limit from photon loss in fibers. The [Chinese quantum satellite] demonstrated entanglement distribution over 1200 kilometers, so satellite-based quantum networks are definitely feasible.</p><p>Applications range from ultra-secure quantum key distribution to distributed quantum computing where multiple processors share entangled states to solve problems no single processor could handle. Quantum sensor networks could achieve precision impossible for independent sensors.</p><p>But the challenges are huge. You need quantum memories to store states while waiting for network synchronization. Photon loss limits transmission. Quantum repeaters are still experimental. Network protocols are just starting to be standardized.</p><p>We're probably decades from a full quantum internet, but pieces are coming together. The first applications will likely be secure communication networks for government and financial institutions willing to pay premium prices.</p>"],
      ["quantum algorithms for chemistry", "thing", "<p><strong>Quantum algorithms</strong> for chemistry could revolutionize drug discovery and materials science because molecules are inherently quantum mechanical systems that classical computers struggle to simulate accurately.</p><p>The problem is that electrons in molecules exist in quantum superpositions, chemical bonds involve entanglement, and reaction dynamics follow the Schrödinger equation. Classical computers must approximate this quantum behavior, with computational costs exploding exponentially as molecules get bigger.</p><p>A quantum computer with 50 good qubits could potentially simulate a 50-electron molecule exactly - something that might require more classical computational resources than exist in the universe.</p><p>The Variational Quantum Eigensolver algorithm combines quantum and classical computation. The quantum processor prepares trial wavefunctions while a classical optimizer adjusts parameters to minimize energy. Finding the minimum energy determines molecular structure and properties.</p><p>Applications include designing better catalysts for fertilizer production and carbon capture, discovering new drugs, creating improved batteries and solar cells, understanding high-temperature superconductivity.</p><p>This is probably the most promising near-term application of quantum computing - the physics match between quantum hardware and quantum chemistry problems is natural, unlike many other proposed quantum applications.</p>"],
    ],
    "normaluser29" => [
      ["quantum biology emerging evidence", "idea", "<p><strong>Quantum biology</strong> is investigating whether quantum effects like superposition and entanglement actually play functional roles in living systems. The assumption used to be that warm, wet, noisy cells would instantly destroy quantum effects, but evidence suggests nature is cleverer than we thought.</p><p>The clearest example is photosynthesis, where light-harvesting complexes transfer energy with near 100% efficiency. Experiments show energy moves in quantum superposition, sampling all possible paths and choosing the most efficient. Classical models can't explain this level of efficiency.</p><p>Bird navigation might use quantum entanglement. The radical pair mechanism proposes that avian magnetoreception works through electron pairs in entangled spin states that are sensitive to Earth's magnetic field. Behavioral and biochemical evidence supports this.</p><p>Enzyme catalysis may involve quantum tunneling where hydrogen atoms tunnel through energy barriers rather than climbing over them thermally. This would explain why some reactions proceed faster than classical chemistry predicts.</p><p>Even smell might work through quantum mechanics - the vibration theory suggests receptors detect electron tunneling across odorant molecules, with tunneling probability depending on molecular vibrations.</p><p>Skeptics argue biological environments should destroy coherence too quickly, but evolving evidence suggests quantum effects may be more biologically relevant than previously imagined.</p>"],
    ],
    "normaluser17" => [
      ["quantum field theory fundamentals", "essay", "<p><strong>Quantum field theory</strong> represents the marriage of [quantum mechanics] and [special relativity], providing the framework that underpins our deepest understanding of fundamental particles and forces. Rather than treating particles as discrete objects moving through empty space, QFT conceives of reality as a collection of quantum fields pervading all of space and time.</p><p>Each type of fundamental particle corresponds to a quantum field - there's an <em>electron field</em>, a [photon] field, a [quark] field, and so on. Particles are localized excitations or vibrations in these fields, somewhat like waves on the surface of an ocean. When we detect a particle, we're really detecting a localized ripple in the corresponding field.</p><p>This field perspective resolves many conceptual puzzles from earlier quantum theory. The creation and annihilation of particle-antiparticle pairs, impossible in non-relativistic quantum mechanics, emerges naturally as quantum fields transitioning between different excitation states. [Virtual particles] that mediate forces are temporary excitations in quantum fields.</p><p>The crowning achievement of quantum field theory is the [Standard Model] of particle physics, which describes three of the four fundamental forces - [electromagnetism], [weak nuclear force], and [strong nuclear force] - with extraordinary precision. Predictions of the Standard Model have been verified to better than one part in a billion in some cases.</p><p>Despite this success, quantum field theory faces unresolved challenges. It doesn't incorporate [gravity], cannot explain [dark matter] or [dark energy], and requires input parameters that must be measured rather than derived from deeper principles.</p>"],
      ["quantum decoherence mechanisms", "thing", "<p><strong>Quantum decoherence</strong> explains how the bizarre quantum world of superposition and entanglement transitions to the familiar classical world of definite states, resolving the long-standing measurement problem while presenting the primary engineering challenge for building practical quantum computers.</p><p>Quantum systems exist in fragile superpositions of multiple states until they interact with their environment. Any such interaction - absorption of a single photon, collision with an air molecule, thermal vibration of nearby atoms - causes rapid decoherence, collapsing the superposition into a single definite state.</p><p>The timescale for decoherence depends on system size and coupling to the environment. An isolated electron might maintain coherence for milliseconds. A qubit in a quantum computer might remain coherent for microseconds. A macroscopic object like [Schrödinger's cat] decoheres essentially instantaneously - it would be simultaneously alive and dead for less than 10^-40 seconds before environmental interactions force it into one state or the other.</p><p>This explains why we never observe macroscopic superpositions in everyday life. It's not that quantum mechanics stops applying at large scales; rather, larger systems inevitably interact more strongly with their surroundings, causing near-instantaneous decoherence.</p><p>Building quantum computers requires extraordinary measures to combat decoherence - temperatures near [absolute zero], electromagnetic shielding, vacuum chambers, and sophisticated error correction codes that detect and reverse decoherence-induced errors faster than they accumulate.</p>"],
    ],
    "normaluser18" => [
      ["quantum cryptography protocols", "idea", "<p><strong>Quantum cryptography</strong> exploits fundamental principles of quantum mechanics - particularly the no-cloning theorem and wavefunction collapse - to create communication systems with security guaranteed by the laws of physics rather than mathematical complexity.</p><p>The most developed application is <em>quantum key distribution</em> (QKD), which allows two parties to generate a shared secret key that can provably not have been intercepted. The BB84 protocol, proposed by Bennett and Brassard in 1984, encodes random bits in the polarization states of individual [photons].</p><p>The security derives from measurement inevitably disturbing quantum states. An eavesdropper trying to intercept and measure the quantum channel necessarily introduces detectable errors, alerting the legitimate parties to the presence of interception. Unlike classical cryptography where security depends on the difficulty of certain mathematical problems, quantum cryptography's security follows from the structure of quantum mechanics itself.</p><p>Several quantum key distribution networks now operate commercially, including networks in [China], [Switzerland], and the [United States]. The [Chinese Micius satellite] demonstrated quantum key distribution over 1200 kilometers, proving the technology works for satellite-ground links.</p><p>However, practical implementations face challenges. Quantum cryptography requires specialized hardware including single-photon sources and detectors. Transmission distances are limited by photon loss in optical fibers. And quantum key distribution solves only the key distribution problem - you still need classical encryption for the actual message transmission.</p>"],
      ["quantum error correction codes", "essay", "<p><strong>Quantum error correction</strong> represents one of the most remarkable theoretical and engineering achievements in quantum computing, using redundancy and clever encoding to protect fragile quantum information from inevitable errors without violating the fundamental principle that measuring a quantum state destroys it.</p><p>The challenge seems paradoxical at first. Classical computers detect errors by copying bits and comparing the copies - if they disagree, an error occurred. But the quantum no-cloning theorem proves you cannot copy an unknown quantum state. How can you detect errors without measurement, when measurement destroys the quantum information you're trying to protect?</p><p>The solution involves encoding a single <em>logical qubit</em> across multiple physical qubits in an entangled state. The simplest example uses nine physical qubits to encode one logical qubit. Errors affecting individual physical qubits can be detected and corrected without measuring the logical qubit's state directly.</p><p>The mathematics of quantum error correction codes draws on sophisticated group theory and linear algebra. The [Shor code], [Steane code], and [surface code] represent different approaches to encoding quantum information redundantly. The surface code has become the leading candidate for practical quantum computers because its two-dimensional layout matches the connectivity constraints of physical qubit architectures.</p><p>The overhead is substantial - protecting one logical qubit requires dozens or hundreds of physical qubits depending on the code and error rates. Current quantum computers with 50-100 qubits cannot yet implement full error correction. Achieving fault-tolerant quantum computing likely requires thousands of high-quality physical qubits.</p>"],
    ],
    "normaluser19" => [
      ["quantum annealing for optimization", "thing", "<p><strong>Quantum annealing</strong> offers a fundamentally different approach to quantum computing than the gate-based universal quantum computers that receive most attention, specializing in solving optimization problems by physically encoding problem structure into quantum hardware.</p><p>The concept leverages quantum tunneling and the tendency of quantum systems to seek their lowest energy state. An optimization problem is mapped onto a physical system of qubits whose energy landscape corresponds to the problem's cost function. The system is initialized in a quantum superposition and gradually 'annealed' - allowed to evolve toward its lowest energy state, which corresponds to the optimal solution.</p><p>Quantum annealing can potentially outperform classical optimization by <em>tunneling through energy barriers</em> rather than having to climb over them. Classical algorithms can get stuck in local minima, while quantum systems can tunnel through barriers to find global optima.</p><p>[D-Wave Systems] has commercialized quantum annealers with thousands of qubits, far exceeding the qubit counts of universal quantum computers. However, these specialized qubits cannot perform arbitrary quantum computations - they're designed specifically for optimization problems.</p><p>Applications include [machine learning], financial portfolio optimization, protein folding simulation, traffic flow optimization, and logistics scheduling. The debate continues about whether current quantum annealers demonstrate genuine [quantum advantage] over classical optimization algorithms, but the technology has advanced sufficiently for commercial deployment.</p>"],
      ["quantum teleportation protocol details", "idea", "<p><strong>Quantum teleportation</strong>, despite the sci-fi connotations of the name, doesn't transfer matter or energy faster than light - it's a protocol for transferring the complete quantum state of a particle from one location to another using [quantum entanglement] and classical communication.</p><p>The protocol requires a pre-shared entangled pair of particles split between sender and receiver. The sender performs a joint measurement on their half of the entangled pair and the particle whose state they want to teleport. This measurement yields two classical bits of information which are sent through a normal communication channel to the receiver.</p><p>Based on these two bits, the receiver performs one of four possible operations on their half of the entangled pair, which then assumes the exact quantum state the original particle had. Crucially, the original particle's state is destroyed in the measurement process - quantum information moves from one location to another without passing through the intervening space.</p><p>The no-cloning theorem is preserved because the original is destroyed and only classical information travels between sender and receiver. The maximum speed of information transfer is limited by the speed of light for the classical communication channel, so no relativistic paradoxes arise.</p><p>Quantum teleportation has been experimentally demonstrated with [photons], [atoms], and [ions]. Distances have grown from across a lab table to hundreds of kilometers using optical fibers and free-space links. Applications include distributed quantum computing and quantum communication networks.</p>"],
    ],
    "normaluser20" => [
      ["quantum supremacy demonstrations", "essay", "<p><strong>Quantum supremacy</strong> (sometimes called quantum advantage to avoid supremacy's negative connotations) refers to demonstrating a quantum computer solving a problem that classical computers effectively cannot, marking the threshold where quantum devices surpass classical capabilities for specific tasks.</p><p>In 2019, [Google's Sycamore processor] claimed to achieve quantum supremacy by performing a specific sampling task in 200 seconds that Google estimated would take the world's most powerful [supercomputer] 10,000 years. [IBM] disputed this claim, arguing optimizations could reduce the classical time to days, sparking debate about what counts as genuine supremacy.</p><p>The sampling task was specifically designed to be difficult classically while easy for a quantum computer - it's not practically useful but serves as a benchmark. Critics point out this doesn't demonstrate quantum advantage for problems anyone actually cares about solving.</p><p>More recently, quantum computers have shown advantage for optimization, quantum simulation, and certain machine learning tasks. The quest continues for clear demonstrations of practical quantum advantage - solving problems of genuine economic or scientific value faster than any classical approach.</p><p>The challenges are substantial. Quantum computers excel at specific problem classes - factoring large numbers, simulating quantum systems, certain search and optimization tasks. For most everyday computing tasks, classical computers remain vastly superior and always will be. The goal isn't replacing classical computers but complementing them with quantum devices that excel at currently intractable problems.</p>"],
      ["quantum computing hardware platforms", "thing", "<p>Multiple competing approaches to building physical quantum computers have emerged, each with distinct advantages, challenges, and development timelines, making the race to scalable quantum computing a multi-horse competition with no clear frontrunner.</p><p><strong>Superconducting qubits</strong>, used by [Google], [IBM], and [Rigetti], employ tiny superconducting circuits cooled to millikelvin temperatures. These artificial atoms can be fabricated with semiconductor manufacturing techniques and controlled with microwave pulses. They offer fast gate operations but suffer from short coherence times and require complex dilution refrigeration.</p><p><strong>Trapped ions</strong>, pursued by [IonQ] and [Honeywell], use individual atoms held in electromagnetic traps as qubits. Natural atoms are perfectly identical qubits with long coherence times, but scaling to large numbers of ions faces challenges with trap complexity and laser control systems. Gate operations are slower than superconducting qubits.</p><p><strong>Photonic quantum computing</strong> encodes qubits in properties of individual photons. [Photons] naturally operate at room temperature and don't decohere easily, but creating deterministic photon sources and performing two-qubit gates remains difficult. Companies like [Xanadu] and [PsiQuantum] pursue photonic approaches.</p><p><strong>Neutral atoms</strong> in optical traps, developed by [QuEra] and others, combine advantages of trapped ions (identical qubits, long coherence) with easier scaling to larger arrays. Recent demonstrations show promise, though gate fidelities still lag superconducting qubits.</p><p>The ultimate winner remains unclear - different platforms may prove optimal for different applications.</p>"],
    ],
    "normaluser21" => [
      ["quantum algorithms for chemistry", "idea", "<p><strong>Quantum algorithms</strong> for simulating molecular systems and chemical reactions represent one of the most promising near-term applications of quantum computing, potentially revolutionizing drug discovery, materials science, and our understanding of complex chemical processes.</p><p>The fundamental challenge is that molecules are inherently <em>quantum mechanical</em> systems. Electrons exist in superpositions of orbital states, chemical bonds involve quantum entanglement, and reaction dynamics follow the [Schrödinger equation]. Classical computers must approximate these quantum phenomena, with computational costs growing exponentially with system size.</p><p>Quantum computers naturally represent quantum systems - simulating a 50-electron molecule on a classical computer might require more computational resources than exist in the universe, while a quantum computer with 50 well-controlled qubits could potentially solve it exactly.</p><p>The [Variational Quantum Eigensolver] (VQE) algorithm has emerged as the leading approach for near-term quantum devices. It combines quantum and classical computation - the quantum processor prepares and measures trial wavefunctions while a classical optimizer adjusts parameters to minimize the system's energy. Finding the minimum energy configuration determines molecular structure, reaction pathways, and material properties.</p><p>Applications include designing more efficient catalysts for producing [fertilizer] and reducing carbon emissions, discovering new pharmaceutical compounds, creating better batteries and solar cells, and understanding complex phenomena like high-temperature superconductivity.</p>"],
      ["quantum sensing and metrology", "essay", "<p><strong>Quantum sensing</strong> exploits quantum mechanical effects - particularly superposition, entanglement, and the sensitivity of quantum states to perturbations - to measure physical quantities with precision far exceeding classical sensors, opening applications from gravitational wave detection to medical imaging.</p><p>The fundamental principle is that quantum systems are exquisitely sensitive to their environment. Properties that make quantum computers fragile (rapid decoherence from environmental interaction) become advantages for sensing - the quantum system acts as a probe that registers minute environmental changes.</p><p><em>Atomic clocks</em> use quantum transitions in atoms to measure time with precision better than one second in 100 million years. The [NIST] quantum clock loses less than a second over the age of the universe. This precision enables GPS navigation, synchronizes telecommunications networks, and tests fundamental physics like relativistic time dilation.</p><p>[Quantum magnetometers] detect magnetic fields millions of times weaker than Earth's magnetic field. Medical applications include magnetoencephalography (MEG) that maps brain activity by detecting tiny magnetic fields from neural currents. Geophysical applications include mineral prospecting and archaeological surveys.</p><p>[Quantum gravimeters] measure tiny variations in gravitational acceleration, useful for finding underground mineral deposits, oil reserves, tunnels, or cavities. [Quantum gyroscopes] detect rotation with extreme precision for navigation systems that work where GPS is unavailable.</p><p>Future applications include quantum-enhanced microscopes that exceed the diffraction limit, quantum radar that can detect stealth aircraft, and quantum thermometry for nanoscale temperature measurement.</p>"],
    ],
    "normaluser22" => [
      ["quantum dots in nanotechnology", "thing", "<p><strong>Quantum dots</strong> are nanoscale semiconductor crystals, typically 2-10 nanometers in diameter, small enough that quantum mechanical effects dominate their electronic and optical properties, leading to size-tunable light emission that has revolutionized display technology and biological imaging.</p><p>The quantum confinement effect is key to their behavior. When semiconductors are reduced to dimensions comparable to the [de Broglie wavelength] of electrons and holes, their energy levels become discrete rather than continuous bands. This quantization depends on the dot's size - smaller dots have larger energy gaps and emit higher-energy (bluer) light when excited, while larger dots emit lower-energy (redder) light.</p><p>By precisely controlling quantum dot size during synthesis, manufacturers can tune emission wavelength across the entire visible spectrum and into infrared. A solution of quantum dots might contain a distribution of sizes glowing different colors under UV light - smaller dots appear blue, medium ones green or yellow, larger ones red.</p><p>Applications in <em>display technology</em> have commercialized rapidly. QLED televisions use quantum dots to achieve wider color gamuts and better color purity than conventional LED displays. When blue light from an LED excites quantum dots of precisely tuned sizes, they emit pure red and green light, combining to create more vibrant colors than conventional phosphor-based displays.</p><p>In biological imaging, quantum dots attach to antibodies or other targeting molecules to fluorescently label specific cells or proteins. Their brightness, photostability, and size-tunable colors make them superior to traditional organic dyes for many microscopy applications.</p><p>Solar cells incorporating quantum dots could potentially exceed the Shockley-Queisser efficiency limit through multiple exciton generation.</p>"],
      ["quantum machine learning prospects", "idea", "<p><strong>Quantum machine learning</strong> explores whether quantum computers can accelerate training neural networks, find patterns in data more efficiently, or discover machine learning algorithms fundamentally impossible on classical computers - though separating genuine quantum advantages from hype remains challenging.</p><p>Several potential avenues for quantum speedup exist. Quantum computers might search high-dimensional parameter spaces more efficiently during neural network training. [Quantum random access memory] (qRAM) could load and manipulate large datasets in superposition, allowing parallel evaluation of many data points simultaneously. Quantum algorithms might identify patterns in data that classical algorithms miss.</p><p>The [HHL algorithm] for solving linear systems could accelerate certain machine learning tasks with exponential speedup - if the input and output can be efficiently prepared in quantum states, a big 'if' in practice. The [quantum support vector machine] and [quantum principal component analysis] algorithms show theoretical promise for data classification and dimensionality reduction.</p><p>However, significant caveats apply. Most quantum machine learning algorithms require assuming data is already in quantum form, which requires expensive quantum state preparation. Reading out results collapses quantum superpositions, limiting information extraction. And classical machine learning continues rapid progress - quantum computers must compete with continually improving classical algorithms and hardware.</p><p>Current quantum machine learning demonstrations typically use toy problems on small datasets. Whether practical quantum advantage exists for real-world machine learning workloads remains an open question, though research is accelerating as larger quantum computers become available.</p>"],
    ],
    "normaluser23" => [
      ["quantum communication networks", "essay", "<p><strong>Quantum communication networks</strong> link multiple quantum devices through quantum channels that preserve entanglement and superposition, enabling applications from ultra-secure communications to distributed quantum computing that could unlock capabilities impossible for isolated quantum processors.</p><p>The vision is a [quantum internet] fundamentally different from the classical internet. While the classical internet routes bits through intermediate nodes, quantum networks distribute entanglement between distant nodes and use quantum teleportation to transmit quantum states. The network maintains quantum coherence end-to-end rather than converting quantum information to classical and back.</p><p>Building blocks include <em>quantum repeaters</em> that extend quantum communication beyond the 100-kilometer limit imposed by photon loss in optical fibers. Repeaters use entanglement swapping and quantum error correction to transfer quantum states across long distances without measurement-induced collapse. The [Chinese quantum satellite] Micius has demonstrated entanglement distribution over 1200 kilometers, proving satellite-based quantum networks are feasible.</p><p>Applications range from quantum key distribution for secure communication to distributed quantum computing where multiple quantum processors share entangled states to solve problems no single processor could handle. Clock synchronization networks using entangled particles could improve GPS accuracy. Quantum sensor networks could achieve precision impossible for independent sensors.</p><p>However, formidable challenges remain. Quantum memories must store quantum states while waiting for network synchronization. Photon loss in fibers and free space limits transmission distances. Quantum repeaters remain experimental. And standards for quantum network protocols are still emerging.</p>"],
      ["quantum biology emerging evidence", "thing", "<p><strong>Quantum biology</strong> investigates whether quantum mechanical phenomena like superposition, tunneling, and entanglement play functional roles in biological processes, challenging the assumption that warm, wet, noisy cellular environments instantly destroy quantum effects before they can be biologically relevant.</p><p>The clearest example is <em>photosynthesis</em>, where light-harvesting complexes transfer energy from antenna pigments to reaction centers with near 100% efficiency. Classical models cannot explain this efficiency. Experimental evidence suggests energy moves through the complex in quantum superposition, sampling all possible paths simultaneously and 'choosing' the most efficient route - a phenomenon called [quantum coherence] in photosynthetic systems.</p><p>Bird navigation may exploit quantum effects. The [radical pair mechanism] proposes that avian magnetoreception works through pairs of electrons in quantum spin entangled states whose chemical reactions are sensitive to Earth's weak magnetic field. Behavioral experiments and biochemical evidence support this, though definitive proof remains elusive.</p><p>[Enzyme catalysis] may involve quantum tunneling, where hydrogen atoms tunnel through activation energy barriers rather than having sufficient thermal energy to overcome them classically. This would explain why some enzymatic reactions proceed faster than classical chemistry predicts and show unusual temperature dependence.</p><p>Olfaction might work through quantum mechanisms where molecular vibrations, not just molecular shapes, determine scents. The [vibration theory of smell] suggests receptors detect quantum tunneling of electrons across odorant molecules, with tunneling probability depending on molecular vibrational frequencies.</p><p>Skeptics argue biological environments should destroy quantum coherence too quickly for functional relevance, but evolving experimental evidence suggests nature may exploit quantum mechanics more cleverly than previously imagined.</p>"],
    ],
  },
  "draft" => {
    "normaluser1" => [
      ["Really old draft, editor neglected","thing","a draft to trigger editor neglect","review"],
      ["Really old draft, user neglected","thing","a draft to trigger user neglect","review"],
      ["Really, really old draft, user neglected","thing","a draft to trigger findable change","review"],
    ],
    "e2e_user" => [
      # 200 drafts with varied searchable content for testing draft search
      # Topics include: cooking, travel, technology, science, history, philosophy, music, art, literature, nature

      # Cooking drafts (1-20)
      ["Perfect sourdough bread technique", "thing", "<p>The art of <strong>sourdough bread</strong> requires patience and practice. Start with a healthy starter that bubbles vigorously. Mix flour, water, and salt in precise ratios. The fermentation process develops complex flavors over 12-24 hours.</p>", "findable"],
      ["Italian pasta secrets", "thing", "<p>Authentic <strong>Italian pasta</strong> begins with semolina flour and fresh eggs. The dough must rest before rolling. Each region has distinct shapes and sauces. Bologna is famous for its rich ragu.</p>", "findable"],
      ["French pastry fundamentals", "idea", "<p>Mastering <strong>French pastry</strong> means understanding laminated doughs. Croissants require precise butter temperature. Choux paste relies on proper hydration. The Maillard reaction creates golden crusts.</p>", "private"],
      ["Asian stir fry mastery", "thing", "<p>The secret to perfect <strong>stir fry</strong> is wok hei - the breath of the wok. High heat, quick cooking, and mise en place are essential. Aromatics go in first, proteins next, vegetables last.</p>", "private"],
      ["Fermentation and preservation", "thing", "<p>Traditional <strong>fermentation</strong> transforms ingredients through beneficial bacteria. Kimchi, sauerkraut, and miso share similar principles. Temperature and salt concentration control the process.</p>", "private"],
      ["Knife skills every cook needs", "thing", "<p>Professional <strong>knife skills</strong> improve safety and efficiency. The claw grip protects fingers. Proper sharpening maintains the edge. Different cuts suit different dishes.</p>", "private"],
      ["Understanding spice combinations", "idea", "<p>Global cuisines have distinctive <strong>spice combinations</strong>. Indian garam masala differs from Chinese five spice. Toasting spices releases essential oils. Balance and harmony matter most.</p>", "private"],
      ["Baking chemistry explained", "thing", "<p>The science of <strong>baking</strong> involves precise chemical reactions. Leavening agents produce carbon dioxide. Gluten networks trap gas bubbles. Oven spring happens in the first minutes.</p>", "private"],
      ["Sauce mother techniques", "thing", "<p>Classical French cuisine defines five <strong>mother sauces</strong>. Béchamel starts with a roux. Hollandaise requires emulsification. Modern chefs build countless derivatives.</p>", "private"],
      ["Seasonal cooking philosophy", "essay", "<p>Cooking with <strong>seasonal ingredients</strong> respects natural rhythms. Summer tomatoes taste nothing like winter ones. Local farmers markets offer the freshest produce.</p>", "private"],
      ["Cast iron care guide", "thing", "<p>A well-seasoned <strong>cast iron pan</strong> becomes naturally non-stick. Avoid soap and excessive scrubbing. Regular use builds the patina. These pans last generations.</p>", "private"],
      ["Bread scoring patterns", "thing", "<p>Decorative <strong>bread scoring</strong> controls oven spring. Sharp lames make clean cuts. Depth and angle affect the ear. Artists create elaborate wheat patterns.</p>", "private"],
      ["Coffee roasting basics", "thing", "<p>Home <strong>coffee roasting</strong> transforms green beans. First crack indicates light roast. Second crack produces darker profiles. Cooling quickly stops the process.</p>", "private"],
      ["Chocolate tempering science", "thing", "<p>Proper <strong>chocolate tempering</strong> creates shiny, snappy results. Crystal formation requires specific temperatures. Seeding method works best for beginners.</p>", "private"],
      ["Wine pairing principles", "idea", "<p>Successful <strong>wine pairing</strong> balances weight and flavor. Acidic wines cut through richness. Tannic reds match fatty meats. Regional combinations rarely fail.</p>", "private"],
      ["Cheese making at home", "thing", "<p>Basic <strong>cheese making</strong> requires milk, rennet, and culture. Temperature control is crucial. Aging develops complex flavors. Fresh cheeses are easiest to start.</p>", "private"],
      ["Smoking and curing meats", "thing", "<p>Traditional <strong>meat curing</strong> uses salt, time, and controlled environments. Cold smoking adds flavor. Hot smoking cooks the meat. Nitrates prevent botulism.</p>", "private"],
      ["Vegetable fermentation guide", "thing", "<p>Lacto-fermented <strong>vegetables</strong> are probiotic powerhouses. Salt creates anaerobic conditions. Wild bacteria transform sugars. Bubbling indicates active fermentation.</p>", "private"],
      ["Homemade ice cream techniques", "thing", "<p>Churned <strong>ice cream</strong> depends on fat content and overrun. Custard bases yield rich results. Churning incorporates air. Fast freezing prevents ice crystals.</p>", "private"],
      ["Grilling temperature zones", "thing", "<p>Direct and indirect <strong>grilling zones</strong> offer different cooking methods. Searing happens over high heat. Low and slow suits tough cuts. Resting redistributes juices.</p>", "private"],

      # Travel drafts (21-40)
      ["Exploring hidden Kyoto temples", "thing", "<p>Beyond the famous shrines, <strong>Kyoto</strong> hides quiet temples in residential neighborhoods. Moss gardens require contemplation. Dawn visits avoid crowds. Local buses reach everywhere.</p>", "findable"],
      ["Iceland's ring road adventure", "thing", "<p>Driving <strong>Iceland's ring road</strong> takes at least a week. Waterfalls appear around every bend. Northern lights dance in winter. Summer brings midnight sun.</p>", "findable"],
      ["Street food tour of Bangkok", "thing", "<p><strong>Bangkok's street food</strong> scene overwhelms the senses. Chinatown offers the best variety. Som tam vendors line Silom. Night markets come alive after dark.</p>", "private"],
      ["Hiking the Camino de Santiago", "essay", "<p>The <strong>Camino de Santiago</strong> transforms pilgrims over 800 kilometers. Albergues provide simple accommodation. Yellow arrows mark the way. Buen Camino greets fellow walkers.</p>", "private"],
      ["Safari planning in Tanzania", "thing", "<p>The <strong>Serengeti migration</strong> follows seasonal rains. Calving season brings predator action. Hot air balloons offer aerial views. Conservation fees support parks.</p>", "private"],
      ["Greek island hopping guide", "thing", "<p><strong>Greek islands</strong> each have distinct character. Ferries connect them all. Santorini attracts crowds. Smaller islands offer authentic experiences.</p>", "private"],
      ["Norwegian fjord expedition", "thing", "<p>Cruising <strong>Norwegian fjords</strong> reveals dramatic geology. Waterfalls cascade from cliffs. Tiny villages cling to shores. Midnight sun illuminates summer nights.</p>", "private"],
      ["Ancient ruins of Peru", "thing", "<p>Beyond Machu Picchu, <strong>Peru's ruins</strong> span millennia. The Nazca lines remain mysterious. Chan Chan was the largest adobe city. Altitude affects unprepared visitors.</p>", "private"],
      ["New Zealand adventure activities", "thing", "<p><strong>New Zealand</strong> invented bungee jumping and zorbing. Queenstown is the adventure capital. Milford Sound deserves its reputation. Both islands offer distinct experiences.</p>", "private"],
      ["Morocco's medina navigation", "thing", "<p>Getting lost in <strong>Marrakech's medina</strong> is inevitable and wonderful. Riads hide behind plain doors. Souks specialize by trade. Mint tea welcomes visitors everywhere.</p>", "private"],
      ["Vietnam by motorbike", "thing", "<p>Crossing <strong>Vietnam by motorbike</strong> connects north and south. The Hai Van pass offers stunning views. Traffic rules seem optional. Horn honking is communication.</p>", "private"],
      ["Scottish Highland castles", "thing", "<p>Ruined <strong>Scottish castles</strong> dot the Highland landscape. Clan histories fill centuries. Whisky distilleries welcome tours. Weather changes by the hour.</p>", "private"],
      ["Portuguese coastal villages", "thing", "<p>The <strong>Algarve coast</strong> hides traditional fishing villages. Grilled sardines perfume the air. Azulejos decorate every surface. The Atlantic shapes daily life.</p>", "private"],
      ["Japanese onsen etiquette", "thing", "<p>Traditional <strong>onsen bathing</strong> follows strict rituals. Wash thoroughly before entering. Tattoos may cause problems. Rotenburo outdoor baths connect with nature.</p>", "private"],
      ["Patagonia trekking routes", "thing", "<p><strong>Patagonian trails</strong> challenge experienced hikers. Torres del Paine demands preparation. Weather windows close quickly. Refugios provide shelter and meals.</p>", "private"],
      ["Indian train journeys", "thing", "<p>The <strong>Indian railway network</strong> connects a billion people. Sleeper class offers authentic experience. Chai wallahs patrol platforms. Delays are inevitable.</p>", "private"],
      ["Caribbean island comparisons", "idea", "<p>Each <strong>Caribbean island</strong> has unique character. Jamaica has reggae roots. Barbados offers refined elegance. Cuba remains frozen in time.</p>", "private"],
      ["Australian outback survival", "thing", "<p>The <strong>Australian outback</strong> demands respect and preparation. Distances seem endless. Wildlife can kill. Aboriginal culture spans millennia.</p>", "private"],
      ["Alpine skiing resorts ranked", "thing", "<p>European <strong>Alps resorts</strong> vary in character and terrain. Chamonix challenges experts. Zermatt offers views of Matterhorn. Austrian villages feel cozier.</p>", "private"],
      ["Central American backpacking", "thing", "<p><strong>Central America</strong> offers budget-friendly adventures. Guatemala's Lake Atitlan mesmerizes. Costa Rica prioritizes ecotourism. Safety concerns vary by country.</p>", "private"],

      # Technology drafts (41-60)
      ["Understanding neural networks", "thing", "<p><strong>Neural networks</strong> loosely mimic brain structure. Layers of nodes process information. Weights adjust during training. Deep learning stacks many layers.</p>", "findable"],
      ["Blockchain beyond cryptocurrency", "idea", "<p><strong>Blockchain technology</strong> enables trustless transactions. Immutable ledgers resist tampering. Smart contracts automate agreements. Energy consumption remains controversial.</p>", "findable"],
      ["Quantum computing explained", "thing", "<p><strong>Quantum computers</strong> exploit superposition and entanglement. Qubits exist in multiple states simultaneously. Certain problems become tractable. Current machines are error-prone.</p>", "private"],
      ["Open source software philosophy", "essay", "<p>The <strong>open source movement</strong> democratizes technology. Collaborative development accelerates innovation. Licensing determines usage rights. Community governance varies widely.</p>", "private"],
      ["Privacy in the digital age", "idea", "<p><strong>Digital privacy</strong> erodes with each convenience. Metadata reveals patterns. Encryption provides protection. Surveillance capitalism profits from data.</p>", "private"],
      ["Artificial intelligence ethics", "essay", "<p><strong>AI ethics</strong> confronts unprecedented questions. Bias reflects training data. Accountability remains unclear. Autonomous weapons raise moral concerns.</p>", "private"],
      ["Renewable energy technology", "thing", "<p><strong>Solar and wind power</strong> costs continue falling. Battery storage solves intermittency. Grid modernization enables distribution. Fossil fuel subsidies distort markets.</p>", "private"],
      ["Electric vehicle transition", "thing", "<p>The <strong>EV revolution</strong> accelerates globally. Battery chemistry improves steadily. Charging infrastructure expands. Legacy automakers scramble to adapt.</p>", "private"],
      ["Space exploration future", "thing", "<p>Private <strong>space companies</strong> reduce launch costs dramatically. Mars colonization remains ambitious. Asteroid mining could fund further exploration.</p>", "private"],
      ["Internet of things security", "thing", "<p><strong>IoT devices</strong> multiply vulnerabilities. Default passwords invite attacks. Firmware updates lag or cease. Smart homes require smart security.</p>", "private"],
      ["5G network implications", "thing", "<p><strong>5G networks</strong> promise transformative speeds. Low latency enables new applications. Infrastructure buildout continues. Conspiracy theories proliferate.</p>", "private"],
      ["Biometric authentication risks", "thing", "<p><strong>Biometric systems</strong> cannot be reset if compromised. Fingerprints persist at crime scenes. Facial recognition enables surveillance. Convenience trades security.</p>", "private"],
      ["Cloud computing architecture", "thing", "<p><strong>Cloud infrastructure</strong> virtualizes computing resources. Microservices replace monoliths. Containers simplify deployment. Serverless functions scale automatically.</p>", "private"],
      ["Cybersecurity fundamentals", "thing", "<p><strong>Cybersecurity</strong> requires defense in depth. Social engineering bypasses technical controls. Regular updates close vulnerabilities. Backups enable recovery.</p>", "private"],
      ["Augmented reality applications", "thing", "<p><strong>Augmented reality</strong> overlays digital information on physical world. Navigation benefits immediately. Industrial training shows promise. Consumer adoption lags predictions.</p>", "private"],
      ["Gene editing technology CRISPR", "thing", "<p><strong>CRISPR gene editing</strong> revolutionizes biotechnology. Precise cuts enable modifications. Therapeutic applications multiply. Germline editing raises ethical concerns.</p>", "private"],
      ["Robotics in manufacturing", "thing", "<p>Industrial <strong>robots</strong> transform factory floors. Collaborative robots work alongside humans. Programming becomes more accessible. Job displacement concerns persist.</p>", "private"],
      ["Virtual reality immersion", "thing", "<p><strong>VR technology</strong> creates compelling alternate realities. Gaming leads adoption. Training applications prove value. Social VR creates new communities.</p>", "private"],
      ["Autonomous vehicle progress", "thing", "<p><strong>Self-driving cars</strong> progress slower than predicted. Edge cases prove challenging. Regulatory frameworks evolve. Full autonomy remains elusive.</p>", "private"],
      ["Digital twin technology", "thing", "<p><strong>Digital twins</strong> replicate physical systems virtually. Simulation enables optimization. Predictive maintenance reduces costs. Industrial applications lead adoption.</p>", "private"],

      # Science drafts (61-80)
      ["Black holes and spacetime", "thing", "<p><strong>Black holes</strong> warp spacetime to extremes. Event horizons mark points of no return. Hawking radiation implies eventual evaporation. Singularities challenge physics.</p>", "findable"],
      ["Evolution of human consciousness", "idea", "<p>How <strong>consciousness</strong> emerged remains biology's hardest problem. Neurons fire in patterns. Subjective experience defies reduction. Theories abound without consensus.</p>", "findable"],
      ["Climate feedback loops", "thing", "<p><strong>Climate feedback</strong> mechanisms amplify or dampen warming. Melting ice reduces reflectivity. Thawing permafrost releases methane. Tipping points may cascade.</p>", "private"],
      ["Microbiome research advances", "thing", "<p>The <strong>gut microbiome</strong> influences more than digestion. Mental health connections emerge. Diet shapes bacterial populations. Fecal transplants treat infections.</p>", "private"],
      ["Dark matter mysteries", "thing", "<p><strong>Dark matter</strong> constitutes most mass yet remains invisible. Gravitational effects reveal its presence. Direct detection experiments continue. Alternative theories exist.</p>", "private"],
      ["CRISPR applications expanding", "thing", "<p><strong>CRISPR technology</strong> enables precise genetic modification. Disease treatments advance. Agricultural applications multiply. Ethical boundaries remain debated.</p>", "private"],
      ["Neuroscience of memory", "thing", "<p><strong>Memory formation</strong> involves synaptic strengthening. Hippocampus consolidates experiences. Sleep plays crucial roles. Forgetting serves important functions.</p>", "private"],
      ["Plate tectonics mechanisms", "thing", "<p><strong>Plate tectonics</strong> shapes continents over millions of years. Convection drives movement. Subduction creates volcanoes. Earthquakes release built stress.</p>", "private"],
      ["Antimicrobial resistance crisis", "thing", "<p><strong>Antibiotic resistance</strong> threatens modern medicine. Overuse accelerates evolution. New drug development lags. Agricultural use compounds problems.</p>", "private"],
      ["Photosynthesis efficiency", "thing", "<p>Natural <strong>photosynthesis</strong> converts sunlight with surprising efficiency. Quantum effects may play roles. Artificial systems seek improvement. Food and fuel production could transform.</p>", "private"],
      ["Epigenetics inheritance", "thing", "<p><strong>Epigenetic</strong> changes pass between generations without DNA alterations. Environmental factors leave marks. Trauma effects persist. Lamarck receives partial vindication.</p>", "private"],
      ["Particle physics puzzles", "thing", "<p>The <strong>Standard Model</strong> leaves questions unanswered. Gravity resists unification. Dark energy accelerates expansion. New particles remain elusive.</p>", "private"],
      ["Ocean acidification impacts", "thing", "<p><strong>Ocean acidification</strong> threatens marine ecosystems. Carbon dioxide dissolves into seawater. Shell formation becomes difficult. Coral reefs face multiple stressors.</p>", "private"],
      ["Sleep science discoveries", "thing", "<p><strong>Sleep</strong> serves essential biological functions. Glymphatic system clears waste. Dreams may process emotions. Chronic deprivation damages health.</p>", "private"],
      ["Fusion energy progress", "thing", "<p><strong>Nuclear fusion</strong> promises abundant clean energy. Plasma containment challenges persist. Private ventures accelerate timelines. Net energy gain approaches.</p>", "private"],
      ["Extremophile organisms", "thing", "<p><strong>Extremophiles</strong> thrive in hostile environments. Hot springs harbor thermophiles. Deep sea vents support chemosynthesis. Astrobiology implications follow.</p>", "private"],
      ["Brain plasticity research", "thing", "<p><strong>Neuroplasticity</strong> continues throughout life. Learning reshapes neural connections. Recovery from injury is possible. Practice literally changes brains.</p>", "private"],
      ["Quantum entanglement applications", "thing", "<p><strong>Quantum entanglement</strong> enables secure communication. Measurement affects distant particles instantly. Einstein called it spooky action. Quantum computing exploits correlations.</p>", "private"],
      ["Mass extinction patterns", "thing", "<p>Earth has experienced five major <strong>mass extinctions</strong>. Asteroid impacts, volcanism, and climate shifts caused them. Current biodiversity loss accelerates. Sixth extinction may be underway.</p>", "private"],
      ["Aging biology mechanisms", "thing", "<p><strong>Biological aging</strong> involves multiple interacting processes. Telomeres shorten with divisions. Cellular senescence accumulates. Intervention research intensifies.</p>", "private"],

      # History drafts (81-100)
      ["Fall of the Roman Empire", "essay", "<p>The <strong>Roman Empire's</strong> decline spanned centuries. Economic troubles weakened armies. Barbarian invasions accelerated collapse. Eastern half survived as Byzantium.</p>", "findable"],
      ["Industrial revolution impacts", "thing", "<p>The <strong>Industrial Revolution</strong> transformed society fundamentally. Factory production replaced crafts. Urban populations exploded. Working conditions were often brutal.</p>", "findable"],
      ["Ancient Egyptian mysteries", "thing", "<p>Ancient <strong>Egyptian civilization</strong> lasted three millennia. Pyramid construction methods still debated. Hieroglyphics preserved history. Pharaohs claimed divine status.</p>", "private"],
      ["World War I origins", "thing", "<p><strong>World War I</strong> began with an assassination and alliance obligations. Trench warfare defined the Western Front. Millions died for minimal gains. Empires collapsed.</p>", "private"],
      ["Silk Road trade networks", "thing", "<p>The <strong>Silk Road</strong> connected East and West for centuries. Goods, ideas, and diseases traveled together. Caravanserais provided shelter. Marco Polo popularized the route.</p>", "private"],
      ["French Revolution causes", "thing", "<p>The <strong>French Revolution</strong> exploded from multiple pressures. Enlightenment ideas spread. Food shortages angered masses. Aristocratic privileges infuriated commoners.</p>", "private"],
      ["Mongol Empire expansion", "thing", "<p>The <strong>Mongol Empire</strong> became history's largest contiguous empire. Genghis Khan united tribes. Military tactics proved devastating. Administrative innovations followed conquest.</p>", "private"],
      ["Renaissance artistic flowering", "thing", "<p>The <strong>Renaissance</strong> rediscovered classical learning. Perspective transformed painting. Humanism celebrated individual potential. Florence nurtured genius.</p>", "private"],
      ["Cold War dynamics", "thing", "<p>The <strong>Cold War</strong> divided the world for decades. Nuclear arsenals grew terrifying. Proxy wars devastated nations. Mutually assured destruction prevented direct conflict.</p>", "private"],
      ["Ancient Greek democracy", "thing", "<p><strong>Athenian democracy</strong> invented citizen participation. Male citizens voted directly. Slavery supported leisure classes. Philosophy flourished in open debate.</p>", "private"],
      ["Viking exploration routes", "thing", "<p><strong>Vikings</strong> explored far beyond Scandinavia. North America was reached centuries before Columbus. Trading posts spread across Russia. Fearsome reputation was partly earned.</p>", "private"],
      ["Mesoamerican civilizations", "thing", "<p><strong>Maya and Aztec</strong> civilizations developed sophisticated societies. Mathematics included zero. Astronomical observations proved precise. Spanish conquest proved devastating.</p>", "private"],
      ["Medieval plague pandemic", "thing", "<p>The <strong>Black Death</strong> killed perhaps half of Europe. Social structures collapsed. Labor became valuable. Religious responses varied wildly.</p>", "private"],
      ["Chinese imperial dynasties", "thing", "<p><strong>Imperial China</strong> cycled through dynasties for millennia. Civil service examinations selected officials. Technology often led the world. Isolation eventually proved costly.</p>", "private"],
      ["African kingdoms overview", "thing", "<p>Powerful <strong>African kingdoms</strong> flourished for centuries. Mali controlled gold trade. Great Zimbabwe defied colonial narratives. Oral histories preserved traditions.</p>", "private"],
      ["Ottoman Empire legacy", "thing", "<p>The <strong>Ottoman Empire</strong> bridged continents for centuries. Religious tolerance was often practiced. Military innovations spread. Decline was gradual and contested.</p>", "private"],
      ["American Revolution ideals", "thing", "<p>The <strong>American Revolution</strong> proclaimed universal principles selectively applied. Slavery contradicted liberty rhetoric. Enlightenment ideas shaped documents. Revolution inspired others.</p>", "private"],
      ["Japanese Meiji restoration", "thing", "<p>The <strong>Meiji Restoration</strong> rapidly modernized Japan. Feudalism ended abruptly. Western technology was adopted. Traditional culture was preserved.</p>", "private"],
      ["Indian independence movement", "thing", "<p><strong>Indian independence</strong> combined nonviolent resistance with negotiation. Gandhi's methods inspired globally. Partition caused massive tragedy. Democracy persisted.</p>", "private"],
      ["Age of exploration consequences", "thing", "<p>European <strong>exploration</strong> transformed global connections permanently. Indigenous populations collapsed. Columbian exchange spread species. Colonial extraction continued for centuries.</p>", "private"],

      # Philosophy drafts (101-120)
      ["Existentialism core concepts", "essay", "<p><strong>Existentialism</strong> places individual existence before essence. Freedom entails responsibility. Authenticity requires confronting anxiety. Meaning must be created.</p>", "findable"],
      ["Stoic philosophy practice", "thing", "<p><strong>Stoic philosophy</strong> emphasizes what we can control. Emotions follow judgments. Virtue is the only good. Marcus Aurelius practiced what he preached.</p>", "findable"],
      ["Buddhist mindfulness traditions", "thing", "<p><strong>Buddhist mindfulness</strong> cultivates present-moment awareness. Suffering arises from attachment. Meditation trains attention. Compassion extends to all beings.</p>", "private"],
      ["Utilitarian ethics dilemmas", "idea", "<p><strong>Utilitarian ethics</strong> maximizes overall happiness. Trolley problems expose difficulties. Rights may be sacrificed for greater good. Measurement challenges persist.</p>", "private"],
      ["Platonic forms theory", "thing", "<p><strong>Platonic forms</strong> represent perfect ideals. Physical objects merely participate. Knowledge requires recollection. Cave allegory illustrates enlightenment.</p>", "private"],
      ["Kantian moral imperatives", "thing", "<p><strong>Kant's ethics</strong> grounds morality in reason. Categorical imperatives apply universally. Persons must never be merely used. Intentions matter more than consequences.</p>", "private"],
      ["Eastern and Western philosophy", "idea", "<p><strong>Eastern philosophy</strong> often emphasizes harmony and process. Western thought privileges analysis. Boundaries blur on examination. Cross-pollination enriches both.</p>", "private"],
      ["Free will debate continues", "idea", "<p>The <strong>free will debate</strong> engages philosophy and neuroscience. Determinism challenges moral responsibility. Compatibilism seeks middle ground. Intuitions conflict with evidence.</p>", "private"],
      ["Phenomenology movement", "thing", "<p><strong>Phenomenology</strong> investigates conscious experience directly. Bracketing suspends assumptions. Intentionality characterizes consciousness. Husserl founded the movement.</p>", "private"],
      ["Virtue ethics revival", "thing", "<p><strong>Virtue ethics</strong> focuses on character over rules. Aristotle emphasized practical wisdom. MacIntyre revived the tradition. Community shapes virtues.</p>", "private"],
      ["Nihilism and meaning", "essay", "<p><strong>Nihilism</strong> denies objective meaning or value. Nietzsche diagnosed and resisted it. Creating values becomes imperative. Despair is not the only response.</p>", "private"],
      ["Pragmatism American philosophy", "thing", "<p><strong>Pragmatism</strong> evaluates ideas by practical consequences. Truth works rather than corresponds. Experience grounds inquiry. Democracy requires experimentation.</p>", "private"],
      ["Confucian social harmony", "thing", "<p><strong>Confucian philosophy</strong> emphasizes social relationships and roles. Ritual practices cultivate virtue. Filial piety anchors society. Governance requires moral cultivation.</p>", "private"],
      ["Skepticism philosophical tradition", "thing", "<p><strong>Philosophical skepticism</strong> questions knowledge claims. Descartes used doubt methodically. Pyrrhonism suspends judgment. Certainty proves elusive.</p>", "private"],
      ["Feminist philosophy developments", "thing", "<p><strong>Feminist philosophy</strong> challenges gendered assumptions. Care ethics offers alternatives. Intersectionality complicates categories. Knowledge is situated.</p>", "private"],
      ["Philosophy of mind puzzles", "thing", "<p><strong>Philosophy of mind</strong> grapples with consciousness. Dualism posits separate substances. Physicalism faces explanatory gaps. Functionalism defines mental states by roles.</p>", "private"],
      ["Environmental ethics emergence", "thing", "<p><strong>Environmental ethics</strong> extends moral consideration beyond humans. Intrinsic value debates continue. Future generations have claims. Deep ecology challenges anthropocentrism.</p>", "private"],
      ["Aesthetics and beauty", "thing", "<p><strong>Aesthetics</strong> investigates beauty and art. Kant distinguished taste from preference. Sublime experiences transcend pleasure. Contemporary art challenges definitions.</p>", "private"],
      ["Logic and reasoning foundations", "thing", "<p><strong>Formal logic</strong> structures valid reasoning. Syllogisms were systematized early. Modern logic extends far beyond. Fallacies remain common.</p>", "private"],
      ["Taoism natural philosophy", "thing", "<p><strong>Taoism</strong> emphasizes harmony with natural way. Wu wei means effortless action. Paradox reveals wisdom. Laozi remains enigmatic.</p>", "private"],

      # Music drafts (121-140)
      ["Jazz improvisation techniques", "thing", "<p><strong>Jazz improvisation</strong> balances freedom and structure. Chord changes provide framework. Scales suggest note choices. Listening drives conversation.</p>", "findable"],
      ["Classical music appreciation", "thing", "<p><strong>Classical music</strong> spans centuries of development. Sonata form structures movements. Orchestration creates color. Historical context illuminates meaning.</p>", "findable"],
      ["Rock music evolution", "thing", "<p><strong>Rock music</strong> evolved from blues and country. Electric guitars amplified rebellion. Subgenres proliferated endlessly. Stadium concerts became rituals.</p>", "private"],
      ["Electronic music production", "thing", "<p><strong>Electronic music production</strong> requires technical knowledge. Synthesizers generate sound. Sequencers arrange patterns. Mixing balances elements.</p>", "private"],
      ["Folk music traditions worldwide", "thing", "<p><strong>Folk music</strong> preserves cultural heritage. Oral transmission adapts over time. Instruments vary regionally. Revival movements rediscover roots.</p>", "private"],
      ["Hip hop cultural movement", "thing", "<p><strong>Hip hop</strong> emerged from urban streets. Sampling creates new from old. Lyrical complexity varies widely. Global spread continues.</p>", "private"],
      ["Opera dramatic traditions", "thing", "<p><strong>Opera</strong> combines music with theatrical spectacle. Librettos tell stories. Voices classify by range. Production values have escalated.</p>", "private"],
      ["Music theory fundamentals", "thing", "<p><strong>Music theory</strong> provides vocabulary for analysis. Scales and modes offer frameworks. Harmony creates movement. Rhythm organizes time.</p>", "private"],
      ["World music appreciation", "idea", "<p><strong>World music</strong> labels diverse traditions problematically. Western categories may not apply. Cultural context matters deeply. Fusion raises appropriation questions.</p>", "private"],
      ["Songwriting craft secrets", "thing", "<p><strong>Songwriting</strong> balances words and music. Hooks capture attention. Verse-chorus structures organize ideas. Collaboration often helps.</p>", "private"],
      ["Vinyl record renaissance", "thing", "<p><strong>Vinyl records</strong> have experienced unexpected revival. Analog warmth attracts audiophiles. Physical objects satisfy collectors. Pressing plants struggle with demand.</p>", "private"],
      ["Music psychology research", "thing", "<p><strong>Music psychology</strong> investigates emotional responses. Neural pathways process rhythm and melody. Chills indicate dopamine release. Musical training changes brains.</p>", "private"],
      ["Concert experience dynamics", "essay", "<p>Live <strong>concert experiences</strong> differ fundamentally from recordings. Shared attention creates community. Acoustics shape perception. Performers feed on energy.</p>", "private"],
      ["Blues roots and influences", "thing", "<p><strong>Blues music</strong> emerged from African American experience. Work songs evolved into performance. Twelve-bar structure became standard. Influences spread globally.</p>", "private"],
      ["Reggae and Jamaican culture", "thing", "<p><strong>Reggae music</strong> carries Rastafarian spiritual messages. Offbeat rhythms define the sound. Bob Marley achieved global fame. Political consciousness persists.</p>", "private"],
      ["Punk rock DIY ethic", "thing", "<p><strong>Punk rock</strong> rejected musical virtuosity requirements. Anyone could start a band. Independent labels emerged. Fashion signaled rebellion.</p>", "private"],
      ["Music streaming industry", "thing", "<p><strong>Streaming services</strong> transformed music consumption. Artists earn fractions of cents. Algorithms recommend listens. Physical sales continue declining.</p>", "private"],
      ["Choir and vocal ensemble", "thing", "<p><strong>Choral singing</strong> blends voices harmonically. Breathing synchronizes. Latin masses dominated early repertoire. Community choirs welcome amateurs.</p>", "private"],
      ["Film score composition", "thing", "<p><strong>Film scores</strong> enhance emotional impact. Leitmotifs identify characters. Orchestral colors paint scenes. Deadlines pressure composers.</p>", "private"],
      ["Music education benefits", "thing", "<p><strong>Music education</strong> develops multiple skills. Pattern recognition improves. Motor coordination develops. Social collaboration teaches cooperation.</p>", "private"],

      # Art drafts (141-160)
      ["Oil painting techniques", "thing", "<p><strong>Oil painting</strong> allows blending and layering. Slow drying enables revision. Glazes build luminosity. Impasto creates texture.</p>", "private"],
      ["Sculpture materials compared", "thing", "<p><strong>Sculpture</strong> works in diverse materials. Stone requires subtractive techniques. Clay allows additive modeling. Bronze casting preserves detail.</p>", "private"],
      ["Photography composition rules", "thing", "<p><strong>Photographic composition</strong> guides eye movement. Rule of thirds places subjects. Leading lines draw attention. Breaking rules creatively works too.</p>", "private"],
      ["Abstract expressionism movement", "thing", "<p><strong>Abstract expressionism</strong> emphasized spontaneous gesture. New York replaced Paris as center. Action painting recorded process. Critics debated meaning.</p>", "private"],
      ["Renaissance masters techniques", "thing", "<p><strong>Renaissance masters</strong> developed perspective and sfumato. Apprenticeship trained artists. Patronage supported production. Religious subjects dominated.</p>", "private"],
      ["Japanese woodblock prints", "thing", "<p><strong>Ukiyo-e prints</strong> depicted floating world pleasures. Multiple blocks created colors. Landscapes and actors were popular subjects. Western artists later embraced them.</p>", "private"],
      ["Street art legitimacy debate", "idea", "<p><strong>Street art</strong> challenges gallery boundaries. Banksy questions art markets. Murals revitalize neighborhoods. Permission versus vandalism blurs.</p>", "private"],
      ["Color theory fundamentals", "thing", "<p><strong>Color theory</strong> explains perception and mixing. Primary colors combine to secondaries. Complementary colors enhance contrast. Temperature affects mood.</p>", "private"],
      ["Art conservation challenges", "thing", "<p><strong>Art conservation</strong> preserves cultural heritage. Cleaning reveals original intent. Restoration choices prove controversial. Climate control matters critically.</p>", "private"],
      ["Installation art experiences", "thing", "<p><strong>Installation art</strong> transforms spaces immersively. Viewers become participants. Site specificity matters. Temporary works challenge collecting.</p>", "private"],
      ["Impressionism light studies", "thing", "<p><strong>Impressionism</strong> captured fleeting light effects. Plein air painting required speed. Brushwork remained visible. Critics initially mocked the movement.</p>", "private"],
      ["Digital art and NFTs", "thing", "<p><strong>Digital art</strong> challenges traditional ownership. NFTs create artificial scarcity. Environmental costs concern many. Market speculation dominates discussion.</p>", "private"],
      ["Ceramics and pottery traditions", "thing", "<p><strong>Ceramic arts</strong> span utilitarian and decorative purposes. Clay bodies vary regionally. Firing temperatures determine durability. Glazes add color and protection.</p>", "private"],
      ["Graphic design principles", "thing", "<p><strong>Graphic design</strong> communicates visually. Typography carries meaning beyond words. White space provides rest. Hierarchy guides attention.</p>", "private"],
      ["Art market economics", "thing", "<p>The <strong>art market</strong> operates by opaque rules. Auction houses set records. Galleries control access. Investment motivations distort values.</p>", "private"],
      ["Textile art traditions", "thing", "<p><strong>Textile arts</strong> have been undervalued as craft. Weaving requires complex planning. Embroidery demands patience. Contemporary artists reclaim the medium.</p>", "private"],
      ["Surrealism dreamlike imagery", "thing", "<p><strong>Surrealism</strong> accessed unconscious imagery. Automatism bypassed rational control. Dream logic structured compositions. Political commitments varied.</p>", "private"],
      ["Art criticism approaches", "thing", "<p><strong>Art criticism</strong> interprets and evaluates. Formalism analyzes visual elements. Contextualism considers social factors. Theory shapes perception.</p>", "private"],
      ["Public art controversies", "thing", "<p><strong>Public art</strong> confronts diverse audiences involuntarily. Monuments encode values. Removal debates intensify. Community input matters.</p>", "private"],
      ["Calligraphy as art form", "thing", "<p><strong>Calligraphy</strong> elevates writing to visual art. Asian traditions value brushwork. Islamic geometry decorates architecture. Western scripts evolved too.</p>", "private"],

      # Literature drafts (161-180)
      ["Novel structure techniques", "thing", "<p><strong>Novel structure</strong> organizes narrative experience. Linear plots follow chronology. Fragmented narratives challenge readers. Viewpoint shapes understanding.</p>", "private"],
      ["Poetry forms and functions", "thing", "<p><strong>Poetry</strong> concentrates language intensely. Form constrains and enables. Rhythm creates expectation. Metaphor reveals connections.</p>", "private"],
      ["Short story craft", "thing", "<p><strong>Short stories</strong> compress narrative impact. Every word must earn inclusion. Epiphanies often conclude. Twist endings surprise.</p>", "private"],
      ["Literary movements overview", "thing", "<p><strong>Literary movements</strong> share aesthetic principles. Romanticism valued emotion and nature. Modernism fragmented tradition. Postmodernism questioned representation.</p>", "private"],
      ["Shakespeare enduring relevance", "essay", "<p><strong>Shakespeare</strong> remains performed and adapted globally. Language innovations persist. Human complexity rings true. Interpretation possibilities seem inexhaustible.</p>", "private"],
      ["Science fiction traditions", "thing", "<p><strong>Science fiction</strong> imagines technological futures. Dystopias warn of dangers. Space opera entertains. Hard SF emphasizes plausibility.</p>", "private"],
      ["Mystery genre conventions", "thing", "<p><strong>Mystery novels</strong> follow detective investigations. Clues must play fair. Red herrings misdirect. Satisfying solutions feel inevitable.</p>", "private"],
      ["Memoir writing challenges", "thing", "<p><strong>Memoir</strong> transforms personal experience into art. Memory proves unreliable. Truth obligations vary. Craft shapes raw material.</p>", "private"],
      ["Magical realism traditions", "thing", "<p><strong>Magical realism</strong> blends fantastic and ordinary. Latin American authors developed the mode. Colonial histories underlie narratives. Gabriel García Márquez exemplifies.</p>", "private"],
      ["Literary translation difficulties", "thing", "<p><strong>Literary translation</strong> navigates impossible choices. Sound effects resist transfer. Cultural references need explanation. Translators become invisible authors.</p>", "private"],
      ["Children's literature evolution", "thing", "<p><strong>Children's literature</strong> has grown increasingly sophisticated. Picture books combine word and image. Young adult fiction tackles serious themes. Crossover appeal expands.</p>", "private"],
      ["Epic poetry traditions", "thing", "<p><strong>Epic poetry</strong> narrates heroic actions. Oral composition shaped conventions. National identities consolidated through epics. Modern attempts continue.</p>", "private"],
      ["Gothic fiction elements", "thing", "<p><strong>Gothic fiction</strong> cultivates fear and mystery. Haunted settings dominate. Sublime terror overwhelms. Psychological depths opened.</p>", "private"],
      ["Postcolonial literature voices", "thing", "<p><strong>Postcolonial literature</strong> writes back to empire. Hybrid identities emerge. Language choices signify. Center-periphery dynamics reverse.</p>", "private"],
      ["Drama theatrical elements", "thing", "<p><strong>Dramatic literature</strong> exists for performance. Dialogue carries action. Stage directions guide production. Live audiences complete the work.</p>", "private"],
      ["Essay as literary form", "thing", "<p>The <strong>essay</strong> explores ideas personally. Montaigne invented the form. Structure varies widely. Voice distinguishes great essayists.</p>", "private"],
      ["Reading strategies developing", "thing", "<p><strong>Reading strategies</strong> enhance comprehension. Active annotation aids memory. Context clues explain vocabulary. Rereading reveals depth.</p>", "private"],
      ["Publishing industry changes", "thing", "<p><strong>Publishing</strong> faces digital disruption. Self-publishing bypasses gatekeepers. Ebooks plateau after rapid growth. Bookstores adapt or close.</p>", "private"],
      ["Book club dynamics", "thing", "<p><strong>Book clubs</strong> combine social and literary pleasures. Discussion reveals perspectives. Selections balance challenge and accessibility. Oprah's influence proved transformative.</p>", "private"],
      ["Creative writing education", "thing", "<p><strong>Creative writing</strong> programs multiply globally. Workshop models dominate. Craft can be taught. Whether talent can is debated.</p>", "private"],

      # Nature drafts (181-200)
      ["Birdwatching beginner guide", "thing", "<p><strong>Birdwatching</strong> rewards patience and attention. Binoculars reveal detail. Field guides identify species. Dawn choruses reward early risers.</p>", "private"],
      ["Forest ecosystem dynamics", "thing", "<p><strong>Forest ecosystems</strong> cycle nutrients continuously. Canopy layers create microclimates. Mycorrhizal networks connect trees. Dead wood supports biodiversity.</p>", "private"],
      ["Ocean life zones explored", "thing", "<p><strong>Ocean zones</strong> vary dramatically with depth. Sunlit surfaces support photosynthesis. Twilight zones host daily migrations. Abyssal depths remain mysterious.</p>", "private"],
      ["Weather pattern understanding", "thing", "<p><strong>Weather patterns</strong> follow physical principles. Pressure differences drive winds. Fronts bring precipitation. Climate differs from weather.</p>", "private"],
      ["Insect diversity importance", "thing", "<p><strong>Insects</strong> dominate animal diversity. Pollinators enable flowering plants. Decomposers recycle nutrients. Populations are declining alarmingly.</p>", "private"],
      ["Mountain formation geology", "thing", "<p><strong>Mountain building</strong> reveals tectonic forces. Collision zones thrust rock upward. Erosion sculptures peaks. Glaciers carve valleys.</p>", "private"],
      ["Desert adaptation strategies", "thing", "<p><strong>Desert organisms</strong> solve water scarcity creatively. Cacti store water internally. Nocturnal activity avoids heat. Kangaroo rats never drink.</p>", "private"],
      ["River system hydrology", "thing", "<p><strong>River systems</strong> drain watersheds inevitably. Erosion and deposition shape channels. Floods renew floodplains. Dams disrupt natural processes.</p>", "private"],
      ["Plant identification basics", "thing", "<p><strong>Plant identification</strong> requires careful observation. Leaf shapes categorize families. Flower structures reveal relationships. Field guides organize by habitat.</p>", "private"],
      ["Wildlife photography tips", "thing", "<p><strong>Wildlife photography</strong> demands patience and preparation. Long lenses enable distance. Early morning light flatters subjects. Fieldcraft matters more than equipment.</p>", "private"],
      ["Coral reef conservation", "thing", "<p><strong>Coral reefs</strong> support exceptional biodiversity. Warming bleaches corals. Acidification inhibits skeleton formation. Protection requires climate action.</p>", "private"],
      ["Migration patterns revealed", "thing", "<p>Animal <strong>migrations</strong> cover extraordinary distances. Navigation mechanisms remain partly mysterious. Climate change disrupts timing. Stopover sites prove critical.</p>", "private"],
      ["Wetland ecosystem services", "thing", "<p><strong>Wetlands</strong> provide services exceeding their size. Flood mitigation protects communities. Water filtration cleans supplies. Wildlife habitat concentrates biodiversity.</p>", "private"],
      ["Butterfly life cycles", "thing", "<p><strong>Butterfly metamorphosis</strong> transforms caterpillars completely. Chrysalis stage restructures everything. Adult forms focus on reproduction. Host plants limit distributions.</p>", "private"],
      ["Tide pool exploration", "thing", "<p><strong>Tide pools</strong> reveal intertidal life. Zonation reflects exposure tolerance. Sea stars and anemones dominate. Low tides offer best access.</p>", "private"],
      ["Soil ecology fundamentals", "thing", "<p><strong>Soil ecosystems</strong> support terrestrial life. Bacteria and fungi decompose organics. Earthworms aerate structure. Healthy soils store carbon.</p>", "private"],
      ["Night sky observation", "thing", "<p><strong>Stargazing</strong> connects us to the universe. Dark skies become rare. Constellations tell stories. Planets wander among stars.</p>", "private"],
      ["Endangered species challenges", "thing", "<p><strong>Endangered species</strong> face multiple threats. Habitat loss predominates. Poaching targets valuable species. Conservation efforts show mixed results.</p>", "private"],
      ["Nature journaling practice", "thing", "<p><strong>Nature journaling</strong> deepens observation. Sketching forces attention. Written notes capture details. Regular practice reveals patterns.</p>", "private"],
      ["Ecological succession stages", "thing", "<p><strong>Ecological succession</strong> transforms landscapes over time. Pioneer species colonize bare ground. Communities replace each other. Climax states may be myths.</p>", "private"],
    ],
  },
};

# insertNode is: $title, $TYPE, $USER, $NODEDATA
foreach my $datatype (keys %$datanodes)
{
  foreach my $author (keys %{$datanodes->{$datatype}})
  {
    foreach my $thiswriteup (@{$datanodes->{$datatype}->{$author}})
    {
      my $authornode = getNode($author, "user");
      my $writeup_parent;
      unless($writeup_parent = getNode($thiswriteup->[0],"e2node"))
      {
        print STDERR "Inserting e2node: '$thiswriteup->[0]'\n";
        $DB->insertNode($thiswriteup->[0],"e2node",$authornode,{});
        $writeup_parent = $DB->getNode($thiswriteup->[0],"e2node");
      }
      my $writeuptype = getNode($thiswriteup->[1],"writeuptype");

      my $parent_e2node = getNode($thiswriteup->[0],"e2node");
      my $writeup = getNode("$thiswriteup->[0] ($writeuptype->{title})",$datatype);
      if (!$writeup) {
        print STDERR "Inserting writeup: '$thiswriteup->[0] ($writeuptype->{title})'\n";
        $DB->insertNode("$thiswriteup->[0] ($writeuptype->{title})",$datatype,$authornode, {});
        $writeup = getNode("$thiswriteup->[0] ($writeuptype->{title})",$datatype);
      } else {
        print STDERR "Writeup already exists: '$thiswriteup->[0] ($writeuptype->{title})' (updating)\n";
      }
      $writeup->{createtime} = $APP->convertEpochToDate(time());
      $writeup->{doctext} = $thiswriteup->[2];
      $writeup->{document_id} = $writeup->{node_id};

      if($datatype eq "writeup")
      {
        $writeup->{parent_e2node} = $parent_e2node->{node_id};
        $writeup->{wrtype_writeuptype} = $writeuptype->{node_id};
      
        $writeup->{notnew} = 0;
        if($thiswriteup->[0] =~ /hidden/i)
        {
          $writeup->{notnew} = 1;
        }

        $writeup->{cooled} = 0;
        $writeup->{writeup_id} = $writeup->{writeup_id};
        # Once we have better models, this will be a lot cleaner, but for now, faking the data is as best as we can do
        $writeup->{publishtime} = $writeup->{createtime};
        $writeup->{edittime} = $writeup->{createtime};
      }elsif($datatype eq "draft"){
        $writeup->{draft_id} = $writeup->{node_id};
        $writeup->{publication_status} = getNode($thiswriteup->[3],"publication_status")->{node_id};
      }
      $DB->updateNode($writeup, $authornode);
      if($datatype eq "writeup")
      {
        # Check if writeup is already in e2node's nodegroup
        my $already_in_group = $DB->sqlSelect('COUNT(*)', 'nodegroup',
          "nodegroup_id=$parent_e2node->{node_id} AND node_id=$writeup->{node_id}");
        if (!$already_in_group) {
          $DB->insertIntoNodegroup($parent_e2node,-1,$writeup);
          $DB->updateNode($parent_e2node, -1);
        }
      }
    }
  }
}

# Update drafts to trigger user and editor neglect
foreach my $d("user","editor")
{
  print STDERR "Updating draft to backdate for $d neglect\n";
  my $neglect = $DB->getNode("Really old draft, $d neglected (thing)","draft");
  unless($neglect)
  {
    die "Could not get draft for neglect detection!";
  }
  $neglect->{createtime} = $APP->convertEpochToDate(time()-20*24*60*60);
  $neglect->{publishtime} = $neglect->{createtime};
  $DB->updateNode($neglect, -1);

  # Insert a nodenote where the notetext is null
  print STDERR "Putting node notes on $d neglect\n";
  my $existing_note1 = $DB->sqlSelect('COUNT(*)', 'nodenote',
    "nodenote_nodeid=$neglect->{node_id} AND notetext='author requested review'");
  if (!$existing_note1) {
    $DB->sqlInsert("nodenote", {"nodenote_nodeid" => $neglect->{node_id}, "timestamp" => $APP->convertEpochToDate(time()-15*24*60*60),"notetext" => "author requested review"});
  }
  if($d eq "user")
  {
    my $existing_note2 = $DB->sqlSelect('COUNT(*)', 'nodenote',
      "nodenote_nodeid=$neglect->{node_id} AND notetext='looks good'");
    if (!$existing_note2) {
      $DB->sqlInsert("nodenote",{"nodenote_nodeid" => $neglect->{node_id}, "timestamp" => $APP->convertEpochToDate(time()-10*24*60*60),"notetext" => "looks good","noter_user" => $DB->getNode("root","user")->{node_id}});
    }
  }

}

# Trigger the neglecteddrafts boot back to findable
my $oldneglect = $DB->getNode("Really, really old draft, user neglected (thing)","draft");
$oldneglect->{createtime} = $APP->convertEpochToDate(time()-40*24*60*60);
$oldneglect->{publishtime} = $oldneglect->{createtime};
$DB->updateNode($oldneglect, -1);
my $existing_note3 = $DB->sqlSelect('COUNT(*)', 'nodenote',
  "nodenote_nodeid=$oldneglect->{node_id} AND notetext='author requested review'");
if (!$existing_note3) {
  $DB->sqlInsert("nodenote", {"nodenote_nodeid" => $oldneglect->{node_id}, "timestamp" => $APP->convertEpochToDate(time()-30*24*60*60),"notetext" => "author requested review"});
}
my $existing_note4 = $DB->sqlSelect('COUNT(*)', 'nodenote',
  "nodenote_nodeid=$oldneglect->{node_id} AND notetext='looks good'");
if (!$existing_note4) {
  $DB->sqlInsert("nodenote", {"nodenote_nodeid" => $oldneglect->{node_id}, "timestamp" => $APP->convertEpochToDate(time()-29*24*60*60),"notetext" => "looks good","noter_user" => $DB->getNode("root","user")->{node_id}});
}



# Create a document so we can create a new item
my $frontpage_usergroup = $DB->getNode("News", "usergroup");
print STDERR "Creating frontpage news item\n";
my $document = getNode("Front page news item 1","document");
if (!$document) {
  $DB->insertNode("Front page news item 1", "document", $DB->getNode("root","user"), {});
  $document = getNode("Front page news item 1","document");
}
$document->{doctext} = "This is the dawn of a new age. Of Everything. And Anything. <em>Mostly</em> [Everything]";
$DB->updateNode($document, -1);
my $existing_weblog = $DB->sqlSelect('COUNT(*)', 'weblog',
  "weblog_id=$frontpage_usergroup->{node_id} AND to_node=$document->{node_id}");
if (!$existing_weblog) {
  $DB->sqlInsert("weblog",{"weblog_id" => $frontpage_usergroup->{node_id}, "to_node" => $document->{node_id} });
} 

print STDERR "Making some edev news items\n";
foreach my $title("boring dev announcement 2","interesting dev announcement","lukewarm dev announcement")
{
  my $n = $DB->getNode($title,"e2node");
  my $existing_edev_weblog = $DB->sqlSelect('COUNT(*)', 'weblog',
    "weblog_id=$dev->{node_id} AND to_node=$n->{node_id}");
  if (!$existing_edev_weblog) {
    $DB->sqlInsert("weblog",{"weblog_id" => $dev->{node_id}, "to_node" => $n->{node_id},"linkedby_user" => $genericdev->{node_id}});
  }
}


# Cast some votes so we can generate front page content

my $writeup_bank = {
  "Quick brown fox (thing)" => 1,
  "lazy dog (idea)" => 1,
  "regular brown fox (person)" => 1,
  "really bad writeup (poetry)" => -1,
  "quantum supremacy demonstrations (idea)" => 1,  # Writeup with badwords for testing excerpt selection
  # AdSense dirty word filtering test weights - make these rank highly in search
  "sexual content test (thing)" => 1,
  "drug policy reform (thing)" => 1,
  "fuck censorship debates (essay)" => 1,
  "internet safety guidelines (thing)" => 1,
  "medical terminology primer (thing)" => 1,
  "historical prohibition era (essay)" => 1,
  "quantum computing basics (thing)" => 1,
  "coffee brewing methods (essay)" => 1
};

for my $writeup (keys %$writeup_bank)
{
  my $writeupnode = getNode($writeup, "writeup");
  unless($writeupnode)
  {
    print STDERR "ERROR: Could not get writeupnode: '$writeup'\n";
    next;
  }
  for my $userseq (2..30)
  {
    my $weight = $writeup_bank->{$writeup};
    if($userseq == 23)
    {
      #23 is a jerk
      $weight = -1*$weight;
    }

    my $user = getNode("normaluser$userseq","user");
    unless($user)
    {
      print STDERR "ERROR: Could not get author for vote: 'normaluser$userseq'\n";
      next;
    }
    print STDERR "Casting vote $user->{title} on '$writeupnode->{title}'\n";
    $APP->castVote($writeupnode, $user, $weight);
  }
}

# Inserting an editor cool
my $coollink = $DB->getNode("coollink","linktype");
my $to_cool = ["Quick brown fox","tomato"];

foreach my $n (@$to_cool)
{
  my $coolnode = $DB->getNode($n, "e2node");
  my $existing_coollink = $DB->sqlSelect('COUNT(*)', 'links',
    "from_node=$coolnode->{node_id} AND to_node=$genericed->{node_id} AND linktype=$coollink->{node_id}");
  if (!$existing_coollink) {
    print STDERR "Using editor cool from $genericed->{title} on $coolnode->{title}\n";
    $DB->sqlInsert("links",{"from_node" => $coolnode->{node_id}, "to_node" => $genericed->{node_id}, "linktype" => $coollink->{node_id}});
  }
}


my $thing_writeuptype = $DB->getNode("thing","writeuptype");
my $normaluser1 = $DB->getNode("normaluser1","user");
my $root = $DB->getNode("root","user");

## Insert a node_forward
# Work around maintenance weirdness
print STDERR "Inserting a node_foward\n";
$Everything::HTML::query = new CGI;
my $potato = $DB->getNode("potato", "e2node");
my $nf = $DB->getNode("Goto potato", "node_forward");
if (!$nf) {
  $nf = $DB->insertNode("Goto potato", "node_forward", $root, {});
  $nf = $DB->getNode("Goto potato", "node_forward");
}
$nf->{doctext} = $potato->{node_id};
$DB->updateNode($nf, -1);
print STDERR "Node_forward '$nf->{title}' points to '$potato->{title}' ($potato->{node_id})\n";

$Everything::HTML::query = undef;


## Create a writeup with a broken writeuptype
my $broken_type_e2node = $DB->getNode("writeup with a broken type", "e2node");
if (!$broken_type_e2node) {
  print STDERR "Inserting a node with a broken writeuptype\n";
  my $broken_type_e2node_id = $DB->insertNode("writeup with a broken type", "e2node", $root);
  $broken_type_e2node = $DB->getNodeById($broken_type_e2node_id);
}

my $broken_type_writeup = $DB->getNode("writeup with a broken type (thing)", "writeup");
if (!$broken_type_writeup) {
  my $broken_type_writeup_id = $DB->insertNode("writeup with a broken type (thing)", "writeup", $normaluser1);
  $broken_type_writeup = $DB->getNodeById($broken_type_writeup_id);
}
$broken_type_writeup->{parent_e2node} = $broken_type_e2node->{node_id};
$broken_type_writeup->{wrtype_writeuptype} = 9999;
$broken_type_writeup->{publishtime} = $broken_type_writeup->{createtime};

$DB->updateNode($broken_type_writeup, -1);
my $broken_type_in_group = $DB->sqlSelect('COUNT(*)', 'nodegroup',
  "nodegroup_id=$broken_type_e2node->{node_id} AND node_id=$broken_type_writeup->{node_id}");
if (!$broken_type_in_group) {
  $DB->insertIntoNodegroup($broken_type_e2node,-1,$broken_type_writeup);
}
print STDERR "Writeup with broken type: '$broken_type_writeup->{title}' ($broken_type_writeup->{node_id})\n";

my $no_parent_writeup = $DB->getNode("writeup with no parent (thing)", "writeup");
if (!$no_parent_writeup) {
  my $no_parent_id = $DB->insertNode("writeup with no parent (thing)", "writeup", $normaluser1);
  $no_parent_writeup = $DB->getNodeById($no_parent_id);
}
$no_parent_writeup->{doctext} = "This writeup is an [orphan]";
$no_parent_writeup->{wrtype_writeuptype} = $thing_writeuptype->{node_id};
$no_parent_writeup->{publishtime} = $no_parent_writeup->{createtime};
$DB->updateNode($no_parent_writeup, -1);
print STDERR "Writeup with no parent: '$no_parent_writeup->{title}'\n";

my $broken_nodegroup_e2node = $DB->getNode("writeup with a broken nodegroup", "e2node");
if (!$broken_nodegroup_e2node) {
  my $broken_nodegroup_e2node_id = $DB->insertNode("writeup with a broken nodegroup", "e2node", $root);
  $broken_nodegroup_e2node = $DB->getNodeById($broken_nodegroup_e2node_id);
}
my $broken_nodegroup_writeup = $DB->getNode("writeup with a broken nodegroup (thing)", "writeup");
if (!$broken_nodegroup_writeup) {
  my $broken_nodegroup_writeup_id = $DB->insertNode("writeup with a broken nodegroup (thing)", "writeup", $normaluser1);
  $broken_nodegroup_writeup = $DB->getNodeById($broken_nodegroup_writeup_id);
}
$broken_nodegroup_writeup->{doctext} = "This is a node that doesn't have the proper [group membership] in [nodegroup], but it has an e2node parent";
$broken_nodegroup_writeup->{parent_e2node} = $broken_nodegroup_e2node->{node_id};
$broken_nodegroup_writeup->{wrtype_writeuptype} = $thing_writeuptype->{node_id};
$broken_nodegroup_writeup->{publishtime} = $broken_nodegroup_writeup->{createtime};
$DB->updateNode($broken_nodegroup_writeup, -1);
print STDERR "Writeup with no nodegroup registration: '$broken_nodegroup_writeup->{title}'\n";

my $no_author_e2node = $DB->getNode("writeup with no owner","e2node");
if (!$no_author_e2node) {
  my $no_author_e2node_id = $DB->insertNode("writeup with no owner","e2node",$root);
  $no_author_e2node = $DB->getNodeById($no_author_e2node_id);
}
my $no_author_writeup = $DB->getNode("writeup with no owner (thing)", "writeup");
if (!$no_author_writeup) {
  my $no_author_writeup_id = $DB->insertNode("writeup with no owner (thing)", "writeup", $normaluser1);
  $no_author_writeup = $DB->getNodeById($no_author_writeup_id);
}
$no_author_writeup->{author_user} = 0;
$no_author_writeup->{parent_e2node} = $no_author_e2node->{node_id};
$no_author_writeup->{wrtype_writeuptype} = $thing_writeuptype->{node_id};
$no_author_writeup->{doctext} = "This writeup has no author to test broken node handling!";
$no_author_writeup->{publishtime} = $no_author_writeup->{createtime};
my $no_author_in_group = $DB->sqlSelect('COUNT(*)', 'nodegroup',
  "nodegroup_id=$no_author_e2node->{node_id} AND node_id=$no_author_writeup->{node_id}");
if (!$no_author_in_group) {
  $DB->insertIntoNodegroup($no_author_e2node, -1, $no_author_writeup);
}
$DB->updateNode($no_author_writeup, -1);
print STDERR "Writeup with no author: '$no_author_writeup->{title}'\n";

my $bad_cool_e2node = $DB->getNode("writeup with bad cool info", "e2node");
if (!$bad_cool_e2node) {
  my $bad_cool_e2node_id = $DB->insertNode("writeup with bad cool info", "e2node", $root);
  $bad_cool_e2node = $DB->getNodeById($bad_cool_e2node_id);
}
my $bad_cool_writeup = $DB->getNode("writeup with bad cool info (thing)", "writeup");
if (!$bad_cool_writeup) {
  my $bad_cool_writeup_id = $DB->insertNode("writeup with bad cool info (thing)", "writeup", $normaluser1);
  $bad_cool_writeup = $DB->getNodeById($bad_cool_writeup_id);
}
$bad_cool_writeup->{parent_e2node} = $bad_cool_e2node->{node_id};
$bad_cool_writeup->{wrtype_writeuptype} = $thing_writeuptype->{node_id};
$bad_cool_writeup->{doctext} = "This writeup was [Cool Archive|cooled] by a [ghost]";
$bad_cool_writeup->{cooled} = 1;
$bad_cool_writeup->{publishtime} = $bad_cool_writeup->{createtime};
my $bad_cool_in_group = $DB->sqlSelect('COUNT(*)', 'nodegroup',
  "nodegroup_id=$bad_cool_e2node->{node_id} AND node_id=$bad_cool_writeup->{node_id}");
if (!$bad_cool_in_group) {
  $DB->insertIntoNodegroup($bad_cool_e2node, -1, $bad_cool_writeup);
}
$DB->updateNode($bad_cool_writeup, -1);
my $existing_bad_cool = $DB->sqlSelect('COUNT(*)', 'coolwriteups',
  "coolwriteups_id=$bad_cool_writeup->{node_id} AND cooledby_user=9999");
if (!$existing_bad_cool) {
  $DB->sqlInsert("coolwriteups",{"coolwriteups_id" => $bad_cool_writeup->{node_id}, cooledby_user => 9999});
}
print STDERR "Writeup with bad cooler: '$bad_cool_writeup->{title}'\n";

# C! assignments - normaluser1-20 all cool "good poetry" to test tooltip with many C!s
my $cools = {
  "normaluser1" => ["good poetry (poetry)", "swedish tomatoë (essay)"],
  "normaluser2" => ["good poetry (poetry)"],
  "normaluser3" => ["good poetry (poetry)"],
  "normaluser4" => ["good poetry (poetry)"],
  "normaluser5" => ["good poetry (poetry)", "Quick brown fox (thing)","lazy dog (idea)", "regular brown fox (person)", "writeup with a broken type (thing)","writeup with no parent (thing)", "writeup with a broken nodegroup (thing)", "writeup with no owner (thing)"],
  "normaluser6" => ["good poetry (poetry)"],
  "normaluser7" => ["good poetry (poetry)"],
  "normaluser8" => ["good poetry (poetry)"],
  "normaluser9" => ["good poetry (poetry)"],
  "normaluser10" => ["good poetry (poetry)"],
  "normaluser11" => ["good poetry (poetry)"],
  "normaluser12" => ["good poetry (poetry)"],
  "normaluser13" => ["good poetry (poetry)"],
  "normaluser14" => ["good poetry (poetry)"],
  "normaluser15" => ["good poetry (poetry)"],
  "normaluser16" => ["good poetry (poetry)"],
  "normaluser17" => ["good poetry (poetry)"],
  "normaluser18" => ["good poetry (poetry)"],
  "normaluser19" => ["good poetry (poetry)"],
  "normaluser20" => ["good poetry (poetry)"],
};

foreach my $chinger (keys %$cools)
{
  my $chinger_node = getNode($chinger, "user");
  foreach my $writeup (@{$cools->{$chinger}})
  {
    my $writeup_node = getNode($writeup, "writeup");
    unless($writeup_node)
    {
      print STDERR "ERROR: Could not get writeup node '$writeup'";
      next;
    }
    $writeup_node->{cooled}++;
    updateNode($writeup_node, -1);
    my $existing_cool = $DB->sqlSelect('COUNT(*)', 'coolwriteups',
      "coolwriteups_id=$writeup_node->{node_id} AND cooledby_user=$chinger_node->{node_id}");
    if (!$existing_cool) {
      $DB->sqlInsert("coolwriteups",{"coolwriteups_id" => $writeup_node->{node_id}, cooledby_user => $chinger_node->{node_id}});
    }
  }
}

# Create ip_to_uint function that is needed for IP Hunter
$DB->{dbh}->do("CREATE DEFINER=`everyuser`@`%` FUNCTION `ip_to_uint`(ipin VARCHAR(255)) RETURNS int unsigned     DETERMINISTIC BEGIN     RETURN (CAST(SUBSTRING_INDEX(ipin,'.',1) AS UNSIGNED) * 256 * 256 * 256)      + (CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(ipin,'.',2),'.',-1) AS UNSIGNED) * 256 * 256)      + (CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(ipin,'.',3),'.',-1) AS UNSIGNED) * 256)      + (CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(ipin,'.',4),'.',-1)  AS UNSIGNED))      ;   END");
print STDERR "Created ip_to_uint function\n";

# Create a test poll with voting data
print STDERR "Creating test poll\n";
my $poll_title = "What is your favorite programming language?";

# Set poll options (newline-separated in doctext)
my @poll_options = (
  "Perl",
  "JavaScript",
  "Python",
  "Ruby",
  "Go",
  "Rust"
);

# Check if poll already exists
my $poll_node = $DB->getNode($poll_title, "e2poll");
if (!$poll_node) {
  # Use insertNode with skip_maintenance=1 to avoid triggering e2poll_create
  # which requires CGI context
  my $poll_node_id = $DB->insertNode($poll_title, "e2poll", $normaluser1, {}, 1);
  unless($poll_node_id) {
    print STDERR "ERROR: Could not create poll node\n";
    exit 1;
  }
  $poll_node = $DB->getNodeById($poll_node_id);
} else {
  print STDERR "Poll already exists: '$poll_title' (updating)\n";
}
$poll_node->{doctext} = join("\n", @poll_options);
$poll_node->{question} = $poll_title;
$poll_node->{poll_status} = 'current';
$poll_node->{poll_author} = $normaluser1->{node_id};
$poll_node->{multiple} = 0;
$poll_node->{is_dailypoll} = 0;
$poll_node->{was_dailypoll} = 0;
$poll_node->{e2poll_results} = "0,0,0,0,0,0";
$poll_node->{totalvotes} = 0;

# Use sqlUpdate to update the fields directly (avoid maintenance functions)
$DB->sqlUpdate("document", {
  doctext => join("\n", @poll_options)
}, "document_id = $poll_node->{node_id}");

$DB->sqlUpdate("e2poll", {
  question => $poll_title,
  poll_status => 'current',
  poll_author => $normaluser1->{node_id},
  multiple => 0,
  is_dailypoll => 0,
  was_dailypoll => 0,
  e2poll_results => "0,0,0,0,0,0",
  totalvotes => 0
}, "e2poll_id = $poll_node->{node_id}");

print STDERR "Created poll '$poll_title' (node_id: $poll_node->{node_id}) with status 'current'\n";

# Initialize vote counts to 0 for each option
my @vote_counts = (0) x scalar(@poll_options);

# Have normaluser1-20 vote on the poll with various preferences
my $poll_votes = {
  # Perl fans
  1 => 0, 2 => 0, 3 => 0, 4 => 0,
  # JavaScript fans
  5 => 1, 6 => 1, 7 => 1, 8 => 1, 9 => 1,
  # Python fans
  10 => 2, 11 => 2, 12 => 2, 13 => 2, 14 => 2, 15 => 2,
  # Ruby fan
  16 => 3,
  # Go fans
  17 => 4, 18 => 4,
  # Rust fans
  19 => 5, 20 => 5,
};

my $total_votes = 0;
foreach my $user_num (sort {$a <=> $b} keys %$poll_votes) {
  my $choice = $poll_votes->{$user_num};
  my $voter = $DB->getNode("normaluser$user_num", "user");

  unless($voter) {
    print STDERR "ERROR: Could not get voter normaluser$user_num\n";
    next;
  }

  # Check if vote already exists
  my $existing_vote = $DB->sqlSelect('COUNT(*)', 'pollvote',
    "pollvote_id=$poll_node->{node_id} AND voter_user=$voter->{node_id}");
  if (!$existing_vote) {
    # Insert the vote
    print STDERR "Recording poll vote: normaluser$user_num voting for option $choice ($poll_options[$choice])\n";
    $DB->sqlInsert("pollvote", {
      pollvote_id => $poll_node->{node_id},
      voter_user => $voter->{node_id},
      choice => $choice,
      votetime => $APP->convertEpochToDate(time())
    });
  }

  # Update vote count
  $vote_counts[$choice]++;
  $total_votes++;
}

# Update poll with final vote counts
$DB->sqlUpdate("e2poll", {
  e2poll_results => join(',', @vote_counts),
  totalvotes => $total_votes
}, "e2poll_id = " . $poll_node->{node_id});

print STDERR "Created poll '$poll_title' with $total_votes votes\n";
print STDERR "Results: " . join(', ', map { "$poll_options[$_]: $vote_counts[$_]" } 0..$#poll_options) . "\n";

# Create second poll with 'closed' status
print STDERR "\nCreating closed poll\n";
my $poll_title2 = "What's your favorite time of day?";
my @poll_options2 = (
  "Early morning (5am-8am)",
  "Late morning (8am-12pm)",
  "Afternoon (12pm-5pm)",
  "Evening (5pm-9pm)",
  "Night (9pm-12am)",
  "Late night (12am-5am)"
);

my $poll_node2 = $DB->getNode($poll_title2, "e2poll");
if (!$poll_node2) {
  my $poll_node_id2 = $DB->insertNode($poll_title2, "e2poll", $normaluser1, {}, 1);
  unless($poll_node_id2) {
    print STDERR "ERROR: Could not create second poll node\n";
    exit 1;
  }
  $poll_node2 = $DB->getNodeById($poll_node_id2);
} else {
  print STDERR "Poll already exists: '$poll_title2' (updating)\n";
}

$DB->sqlUpdate("document", {
  doctext => join("\n", @poll_options2)
}, "document_id = $poll_node2->{node_id}");

$DB->sqlUpdate("e2poll", {
  question => $poll_title2,
  poll_status => 'closed',
  poll_author => $normaluser1->{node_id},
  multiple => 0,
  is_dailypoll => 0,
  was_dailypoll => 0,
  e2poll_results => "0,0,0,0,0,0",
  totalvotes => 0
}, "e2poll_id = $poll_node2->{node_id}");

print STDERR "Poll '$poll_title2' (node_id: $poll_node2->{node_id}) with status 'closed'\n";

# Have normaluser1-15 vote on this poll
my @vote_counts2 = (0) x scalar(@poll_options2);
my $poll_votes2 = {
  # Early morning fans
  1 => 0, 2 => 0,
  # Late morning fans
  3 => 1, 4 => 1, 5 => 1,
  # Afternoon fans
  6 => 2, 7 => 2, 8 => 2, 9 => 2,
  # Evening fans
  10 => 3, 11 => 3, 12 => 3,
  # Night fans
  13 => 4, 14 => 4,
  # Late night fan
  15 => 5,
};

my $total_votes2 = 0;
foreach my $user_num (sort {$a <=> $b} keys %$poll_votes2) {
  my $choice = $poll_votes2->{$user_num};
  my $voter = $DB->getNode("normaluser$user_num", "user");

  unless($voter) {
    print STDERR "ERROR: Could not get voter normaluser$user_num\n";
    next;
  }

  my $existing_vote2 = $DB->sqlSelect('COUNT(*)', 'pollvote',
    "pollvote_id=$poll_node2->{node_id} AND voter_user=$voter->{node_id}");
  if (!$existing_vote2) {
    print STDERR "Recording poll vote: normaluser$user_num voting for option $choice ($poll_options2[$choice])\n";
    $DB->sqlInsert("pollvote", {
      pollvote_id => $poll_node2->{node_id},
      voter_user => $voter->{node_id},
      choice => $choice,
      votetime => $APP->convertEpochToDate(time())
    });
  }

  $vote_counts2[$choice]++;
  $total_votes2++;
}

$DB->sqlUpdate("e2poll", {
  e2poll_results => join(',', @vote_counts2),
  totalvotes => $total_votes2
}, "e2poll_id = $poll_node2->{node_id}");

print STDERR "Created poll '$poll_title2' with $total_votes2 votes\n";
print STDERR "Results: " . join(', ', map { "$poll_options2[$_]: $vote_counts2[$_]" } 0..$#poll_options2) . "\n";

# Create third poll with 'new' status (no votes)
print STDERR "\nCreating new poll\n";
my $poll_title3 = "Which season do you prefer?";
my @poll_options3 = (
  "Spring",
  "Summer",
  "Fall",
  "Winter"
);

my $poll_node3 = $DB->getNode($poll_title3, "e2poll");
if (!$poll_node3) {
  my $poll_node_id3 = $DB->insertNode($poll_title3, "e2poll", $normaluser1, {}, 1);
  unless($poll_node_id3) {
    print STDERR "ERROR: Could not create third poll node\n";
    exit 1;
  }
  $poll_node3 = $DB->getNodeById($poll_node_id3);
} else {
  print STDERR "Poll already exists: '$poll_title3' (updating)\n";
}

$DB->sqlUpdate("document", {
  doctext => join("\n", @poll_options3)
}, "document_id = $poll_node3->{node_id}");

$DB->sqlUpdate("e2poll", {
  question => $poll_title3,
  poll_status => 'new',
  poll_author => $normaluser1->{node_id},
  multiple => 0,
  is_dailypoll => 0,
  was_dailypoll => 0,
  e2poll_results => "0,0,0,0",
  totalvotes => 0
}, "e2poll_id = $poll_node3->{node_id}");

print STDERR "Poll '$poll_title3' (node_id: $poll_node3->{node_id}) with status 'new' (no votes)\n";

# ============================================================
# Iron Noder Test Data
# Create ironnoders usergroup and populate with test writeups
# Creates data for current year (if Nov/Dec) AND previous year
# ============================================================
print STDERR "\n=== Creating Iron Noder test data ===\n";

# Determine which years to create data for
# Always create previous year for historical testing
# Also create current year if we're in November or December
my @iron_years = ($realyear - 1);  # Always include last year
if ($mon >= 10) {  # November (10) or December (11) - 0-indexed
  push @iron_years, $realyear;
  print STDERR "Current month is Nov/Dec, creating data for both $realyear and " . ($realyear - 1) . "\n";
} else {
  print STDERR "Creating Iron Noder data for November " . ($realyear - 1) . " (historical only)\n";
}

# Create the ironnoders usergroup (generic, for current year)
my $ironnoders = $DB->getNode("ironnoders", "usergroup");
if (!$ironnoders) {
  print STDERR "Creating ironnoders usergroup\n";
  my $ironnoders_id = $DB->insertNode("ironnoders", "usergroup", $root, {});
  $ironnoders = $DB->getNodeById($ironnoders_id);
}

# Create year-specific groups for each year we're seeding
my %ironnoders_by_year;
foreach my $yr (@iron_years) {
  my $group_name = "ironnoders$yr";
  my $group = $DB->getNode($group_name, "usergroup");
  if (!$group) {
    print STDERR "Creating $group_name usergroup\n";
    my $group_id = $DB->insertNode($group_name, "usergroup", $root, {});
    $group = $DB->getNodeById($group_id);
  }
  $ironnoders_by_year{$yr} = $group;
}

# Iron Noder participants configuration
# Format: username => number of writeups to create (30+ = iron noder!)
my %iron_participants = (
  "normaluser1" => 35,   # Iron Noder! Over 30
  "normaluser2" => 30,   # Iron Noder! Exactly 30
  "normaluser3" => 25,   # Close but not quite
  "normaluser4" => 15,   # Halfway there
  "normaluser5" => 8,    # Some participation
  "normaluser6" => 3,    # Minimal participation
);

# Add participants to all usergroups
foreach my $username (keys %iron_participants) {
  my $user = $DB->getNode($username, "user");
  next unless $user;

  # Add to current ironnoders group
  add_to_group($user, $ironnoders, 0);

  # Add to each year-specific group
  foreach my $yr (@iron_years) {
    add_to_group($user, $ironnoders_by_year{$yr}, 0);
  }
}
print STDERR "Added " . scalar(keys %iron_participants) . " participants to ironnoders groups\n";

# Create November writeups for each participant, for each year
my $writeup_type = $DB->getType("writeup");
my $thing_type = $DB->getNode("thing", "writeuptype");
my $log_type = $DB->getNode("log", "writeuptype");

foreach my $iron_year (@iron_years) {
  print STDERR "\n--- Creating writeups for November $iron_year ---\n";

  foreach my $username (sort keys %iron_participants) {
    my $num_writeups = $iron_participants{$username};
    my $author = $DB->getNode($username, "user");
    next unless $author;

    print STDERR "Creating $num_writeups Iron Noder writeups for $username ($iron_year)\n";

    for my $i (1..$num_writeups) {
      my $title = "Iron Noder $iron_year - $username writeup $i";

      # Create e2node if needed
      my $e2node = $DB->getNode($title, "e2node");
      if (!$e2node) {
        my $e2node_id = $DB->insertNode($title, "e2node", $author, {});
        $e2node = $DB->getNodeById($e2node_id);
      }

      # Create writeup if needed
      my $writeup_title = "$title (thing)";
      my $writeup = $DB->getNode($writeup_title, "writeup");
      if (!$writeup) {
        my $writeup_id = $DB->insertNode($writeup_title, "writeup", $author, {});
        $writeup = $DB->getNodeById($writeup_id);
      }

      # Set writeup properties
      $writeup->{doctext} = "This is Iron Noder writeup #$i by $username for November $iron_year. " .
                            "The [Iron Noder] challenge requires 30 writeups during November!";
      $writeup->{parent_e2node} = $e2node->{node_id};
      $writeup->{wrtype_writeuptype} = $thing_type->{node_id};

      # Spread writeups across November (day 1-30)
      my $day = (($i - 1) % 30) + 1;
      my $publish_date = sprintf("%04d-11-%02d 12:00:00", $iron_year, $day);
      $writeup->{publishtime} = $publish_date;
      $writeup->{createtime} = $publish_date;

      $DB->updateNode($writeup, $author);

      # Add to e2node's nodegroup
      my $in_group = $DB->sqlSelect('COUNT(*)', 'nodegroup',
        "nodegroup_id=$e2node->{node_id} AND node_id=$writeup->{node_id}");
      if (!$in_group) {
        $DB->insertIntoNodegroup($e2node, -1, $writeup);
      }
    }
  }

  # Also add some daylog writeups to test the max_daylogs limit (for normaluser1)
  print STDERR "Creating daylog writeups for Iron Noder daylog limit testing ($iron_year)\n";
  my $daylog_author = $DB->getNode("normaluser1", "user");
  for my $day (1..8) {
    # Create daylog title in format "November DD, YYYY"
    my $daylog_title = sprintf("November %d, %d", $day, $iron_year);

    my $e2node = $DB->getNode($daylog_title, "e2node");
    if (!$e2node) {
      my $e2node_id = $DB->insertNode($daylog_title, "e2node", $daylog_author, {});
      $e2node = $DB->getNodeById($e2node_id);
    }

    my $writeup_title = "$daylog_title (log)";
    my $writeup = $DB->getNode($writeup_title, "writeup");
    if (!$writeup) {
      my $writeup_id = $DB->insertNode($writeup_title, "writeup", $daylog_author, {});
      $writeup = $DB->getNodeById($writeup_id);
    }

    $writeup->{doctext} = "Daylog entry for November $day, $iron_year. " .
                          "Testing the Iron Noder daylog limit (max 5 count toward total).";
    $writeup->{parent_e2node} = $e2node->{node_id};
    $writeup->{wrtype_writeuptype} = $log_type->{node_id};

    my $publish_date = sprintf("%04d-11-%02d 10:00:00", $iron_year, $day);
    $writeup->{publishtime} = $publish_date;
    $writeup->{createtime} = $publish_date;

    $DB->updateNode($writeup, $daylog_author);

    my $in_group = $DB->sqlSelect('COUNT(*)', 'nodegroup',
      "nodegroup_id=$e2node->{node_id} AND node_id=$writeup->{node_id}");
    if (!$in_group) {
      $DB->insertIntoNodegroup($e2node, -1, $writeup);
    }
  }
  print STDERR "Created 8 daylog writeups for normaluser1 (only 5 should count) for $iron_year\n";
}

print STDERR "\n=== Iron Noder test data complete ===\n";
print STDERR "  - ironnoders group: participants for current year\n";
print STDERR "  - Years with data: " . join(", ", @iron_years) . "\n";
print STDERR "  - Iron Noders (30+): normaluser1, normaluser2\n";
print STDERR "  - Other participants: normaluser3-6\n";

# ============================================================
# Nodeshells for Search and Interface Testing
# Create 100 e2nodes without writeups for search fodder
# ============================================================
print STDERR "\n=== Creating nodeshells for search testing ===\n";

my @nodeshell_titles = (
  # Technology and computing
  "artificial intelligence", "machine learning", "neural networks", "quantum computing",
  "blockchain technology", "cloud computing", "edge computing", "distributed systems",
  "microservices architecture", "container orchestration", "serverless computing",
  "cybersecurity", "encryption algorithms", "zero trust security", "penetration testing",

  # Science and nature
  "quantum mechanics", "general relativity", "black holes", "dark matter",
  "string theory", "particle physics", "thermodynamics", "fluid dynamics",
  "photosynthesis", "cellular respiration", "genetic engineering", "CRISPR technology",
  "ecosystem dynamics", "climate change", "renewable energy", "carbon sequestration",

  # Philosophy and thought
  "existentialism", "epistemology", "ontology", "phenomenology",
  "utilitarianism", "deontological ethics", "virtue ethics", "moral relativism",
  "dualism", "materialism", "idealism", "pragmatism",

  # Arts and culture
  "abstract expressionism", "impressionism", "surrealism", "minimalism",
  "postmodernism", "dadaism", "cubism", "baroque music",
  "jazz improvisation", "classical composition", "electronic music", "ambient soundscapes",

  # Literature and writing
  "magical realism", "stream of consciousness", "unreliable narrator", "metafiction",
  "dystopian fiction", "science fiction", "fantasy literature", "historical fiction",
  "gothic literature", "romantic poetry", "modernist literature", "postcolonial literature",

  # Mathematics
  "number theory", "abstract algebra", "topology", "differential geometry",
  "complex analysis", "probability theory", "statistics", "graph theory",
  "combinatorics", "game theory", "chaos theory", "fractal geometry",

  # History and society
  "industrial revolution", "renaissance period", "enlightenment era", "cold war",
  "ancient civilizations", "medieval history", "colonial period", "decolonization",
  "civil rights movement", "women's suffrage", "labor movement", "social justice",

  # Psychology and mind
  "cognitive dissonance", "confirmation bias", "dunning kruger effect", "imposter syndrome",
  "neuroplasticity", "cognitive behavioral therapy", "psychoanalysis", "behaviorism",
  "developmental psychology", "social psychology", "personality disorders", "mental health",

  # Random interesting concepts
  "collective consciousness", "emergence theory", "systems thinking", "feedback loops",
  "network effects", "path dependence", "paradigm shifts", "creative destruction",
  "technological singularity", "fermi paradox", "simulation hypothesis", "anthropic principle"
);

my $nodeshell_author = $DB->getNode("root", "user");
foreach my $title (@nodeshell_titles) {
  my $e2node = $DB->getNode($title, "e2node");
  if (!$e2node) {
    print STDERR "Creating nodeshell: '$title'\n";
    my $e2node_id = $DB->insertNode($title, "e2node", $nodeshell_author, {});
    $e2node = $DB->getNodeById($e2node_id);
  }
}

print STDERR "Created " . scalar(@nodeshell_titles) . " nodeshells for search testing\n";
print STDERR "\n=== Nodeshell creation complete ===\n";

# ============================================================
# E2nodes that share names with users (for testing "is also a" feature)
# These create e2nodes with the same title as existing users
# ============================================================
print STDERR "\n=== Creating e2nodes for 'is also a' testing ===\n";

my @user_named_e2nodes = (
  "root",           # Same name as root user
  "normaluser1",    # Same name as normaluser1
  "Content Editors", # Same name as Content Editors usergroup (if exists)
);

foreach my $title (@user_named_e2nodes) {
  my $existing_e2node = $DB->getNode($title, "e2node");
  if (!$existing_e2node) {
    print STDERR "Creating e2node with user name: '$title'\n";
    my $e2node_id = $DB->insertNode($title, "e2node", $nodeshell_author, {});
    if ($e2node_id) {
      print STDERR "  Created e2node '$title' with node_id $e2node_id\n";
    }
  } else {
    print STDERR "  E2node '$title' already exists\n";
  }
}

print STDERR "=== 'Is also a' test e2nodes complete ===\n";

# ============================================================
# Firmlinks - Semantic relationships between e2nodes
# Create firmlinks to test the display in zen template and future React
# ============================================================
print STDERR "\n=== Creating firmlinks between nodes ===\n";

my $firmlink_type = $DB->getNode("firmlink", "linktype");
unless($firmlink_type) {
  print STDERR "ERROR: Could not find firmlink linktype\n";
} else {
  # Define firmlink relationships (from_node => [to_node1, to_node2, ...])
  my %firmlink_relationships = (
    "artificial intelligence" => ["machine learning", "neural networks", "cognitive dissonance"],
    "machine learning" => ["neural networks", "artificial intelligence", "statistics"],
    "quantum computing" => ["quantum mechanics", "particle physics", "complex analysis"],
    "blockchain technology" => ["cybersecurity", "distributed systems", "encryption algorithms"],
    "climate change" => ["renewable energy", "ecosystem dynamics", "carbon sequestration"],
    "existentialism" => ["phenomenology", "ontology", "nihilism"],
    "jazz improvisation" => ["classical composition", "electronic music", "musical theory"],
    "dystopian fiction" => ["science fiction", "utopian literature", "social commentary"],
    "cognitive dissonance" => ["confirmation bias", "psychology of belief", "mental frameworks"],
    "fermi paradox" => ["drake equation", "extraterrestrial life", "anthropic principle"],
  );

  my $firmlink_count = 0;
  foreach my $from_title (keys %firmlink_relationships) {
    my $from_node = $DB->getNode($from_title, "e2node");
    next unless $from_node;

    foreach my $to_title (@{$firmlink_relationships{$from_title}}) {
      my $to_node = $DB->getNode($to_title, "e2node");
      next unless $to_node;

      # Check if firmlink already exists
      my $existing = $DB->sqlSelect('COUNT(*)', 'links',
        "from_node=$from_node->{node_id} AND to_node=$to_node->{node_id} AND linktype=$firmlink_type->{node_id}");

      if (!$existing) {
        print STDERR "Creating firmlink: '$from_title' -> '$to_title'\n";
        $DB->sqlInsert("links", {
          from_node => $from_node->{node_id},
          to_node => $to_node->{node_id},
          linktype => $firmlink_type->{node_id},
          food => 0
        });
        $firmlink_count++;
      }
    }
  }

  print STDERR "Created $firmlink_count firmlinks between e2nodes\n";
}

print STDERR "\n=== Firmlink creation complete ===\n";

# ============================================================
# Create nodeshells for softlink targets
# ============================================================
print STDERR "\n=== Creating nodeshells for softlink targets ===\n";

# Collect all unique target node titles from the softlink relationships
my @softlink_target_titles = (
  # Programming languages
  "Python", "JavaScript", "Rust", "COBOL", "Haskell", "Java", "C++", "Go",
  "Ruby", "PHP", "Swift", "Kotlin", "TypeScript", "Scala", "Perl", "Lua",
  "Elixir", "Clojure", "F#", "OCaml",

  # Coffee-related
  "caffeine", "Ethiopia", "Seattle", "espresso", "latte", "cappuccino",
  "arabica", "robusta", "brewing", "roasting", "beans",

  # Database-related
  "PostgreSQL", "MySQL", "MongoDB", "Redis", "Cassandra", "DynamoDB",
  "Elasticsearch", "Neo4j", "CouchDB", "InfluxDB", "SQLite", "Oracle",

  # AI/ML nodes
  "deep learning", "computer vision", "natural language processing",
  "reinforcement learning", "supervised learning", "unsupervised learning",

  # Physics nodes
  "string theory", "loop quantum gravity", "multiverse theory",
  "dark energy", "quantum entanglement", "wave-particle duality",

  # Security nodes
  "encryption", "penetration testing", "threat modeling",
  "zero trust", "blockchain security", "incident response",

  # Statistics nodes
  "bayesian inference", "regression analysis", "hypothesis testing",
  "p-values", "confidence intervals", "normal distribution",

  # Philosophy nodes
  "phenomenology", "ontology", "classical composition", "electronic music",
  "science fiction", "utopian literature", "confirmation bias",
  "psychology of belief", "drake equation", "extraterrestrial life",
  "abstract algebra", "differential geometry", "abstract expressionism",
  "renaissance period",

  # More misc targets
  "backpropagation", "activation functions",
);

my $nodeshell_count = 0;
foreach my $title (@softlink_target_titles) {
  # Check if node already exists
  my $existing = $DB->getNode($title, "e2node");
  next if $existing;

  # Create nodeshell
  my $e2node = $DB->getNode("e2node", "nodetype");
  my $nodeshell = $DB->sqlInsert("node", {
    title => $title,
    type_nodetype => $e2node->{node_id},
    author_user => $root->{node_id},
    createtime => $now,
  });
  $nodeshell_count++;
}

print STDERR "Created $nodeshell_count nodeshells for softlink targets\n";

# ============================================================
# Softlinks - Auto-generated relationships (linktype=0)
# Create softlinks between e2nodes to test display
# ============================================================
print STDERR "\n=== Creating softlinks between nodes ===\n";

# Softlinks use linktype=0 and have a hits counter for frequency/importance
# These simulate the auto-generated links from writeup cross-references
# Deterministic hits based on alphabetical position to make debugging easier
my %softlink_relationships = (
  # Multi-author nodes get many links (48+ to test pagination)
  "programming languages" => [
    {to => "Python", hits => 50}, {to => "JavaScript", hits => 45}, {to => "Rust", hits => 40},
    {to => "software development", hits => 35}, {to => "COBOL", hits => 30}, {to => "Haskell", hits => 25},
    {to => "Java", hits => 20}, {to => "C++", hits => 18}, {to => "Go", hits => 16},
    {to => "Ruby", hits => 14}, {to => "PHP", hits => 12}, {to => "Swift", hits => 10},
    {to => "Kotlin", hits => 9}, {to => "TypeScript", hits => 8}, {to => "Scala", hits => 7},
    {to => "Perl", hits => 6}, {to => "Lua", hits => 5}, {to => "Elixir", hits => 4},
    {to => "Clojure", hits => 3}, {to => "F#", hits => 2}, {to => "OCaml", hits => 1},
  ],
  "coffee" => [
    {to => "caffeine", hits => 100}, {to => "developers", hits => 80}, {to => "Ethiopia", hits => 60},
    {to => "Seattle", hits => 50}, {to => "espresso", hits => 40}, {to => "latte", hits => 35},
    {to => "cappuccino", hits => 30}, {to => "arabica", hits => 25}, {to => "robusta", hits => 20},
    {to => "brewing", hits => 15}, {to => "roasting", hits => 12}, {to => "beans", hits => 10},
  ],
  "databases" => [
    {to => "PostgreSQL", hits => 75}, {to => "MySQL", hits => 70}, {to => "NoSQL", hits => 65},
    {to => "MongoDB", hits => 60}, {to => "Redis", hits => 55}, {to => "relationships", hits => 50},
    {to => "SQL", hits => 45}, {to => "database", hits => 40}, {to => "indexing", hits => 35},
    {to => "transactions", hits => 30}, {to => "ACID", hits => 25}, {to => "schema", hits => 20},
  ],

  # Nodes with writeups - varying amounts of links
  "artificial intelligence" => [
    {to => "machine learning", hits => 90}, {to => "neural networks", hits => 85},
    {to => "deep learning", hits => 80}, {to => "natural language processing", hits => 75},
    {to => "computer vision", hits => 70}, {to => "cognitive dissonance", hits => 10},
  ],
  "machine learning" => [
    {to => "artificial intelligence", hits => 88}, {to => "neural networks", hits => 82},
    {to => "algorithms", hits => 76}, {to => "statistics", hits => 70},
    {to => "data science", hits => 64}, {to => "supervised learning", hits => 58},
  ],
  "quantum computing" => [
    {to => "quantum mechanics", hits => 95}, {to => "particle physics", hits => 85},
    {to => "complex analysis", hits => 75}, {to => "superposition", hits => 65},
    {to => "entanglement", hits => 55}, {to => "qubits", hits => 45},
  ],
  "blockchain technology" => [
    {to => "Bitcoin", hits => 100}, {to => "cryptocurrency", hits => 90},
    {to => "distributed systems", hits => 80}, {to => "consensus algorithms", hits => 70},
    {to => "smart contracts", hits => 60}, {to => "Ethereum", hits => 50},
  ],
  "cybersecurity" => [
    {to => "encryption algorithms", hits => 92}, {to => "penetration testing", hits => 84},
    {to => "firewalls", hits => 76}, {to => "malware", hits => 68},
    {to => "social engineering", hits => 60}, {to => "zero trust security", hits => 52},
  ],

  # Popular seed nodes
  "tomato" => [
    {to => "vegetable", hits => 42}, {to => "fruit", hits => 38}, {to => "potato", hits => 34},
    {to => "stew", hits => 30}, {to => "sauce", hits => 26}, {to => "garden", hits => 22},
  ],
  "lazy dog" => [
    {to => "Quick brown fox", hits => 55}, {to => "dogs", hits => 45},
    {to => "pangram", hits => 35}, {to => "alphabet", hits => 25},
  ],
  "Quick brown fox" => [
    {to => "lazy dog", hits => 54}, {to => "foxes", hits => 44},
    {to => "pangram", hits => 34}, {to => "typography", hits => 24},
  ],

  # Many nodeshells get various amounts of links
  "Python" => [
    {to => "programming languages", hits => 48}, {to => "software development", hits => 42},
    {to => "scripting", hits => 36}, {to => "Django", hits => 30}, {to => "Flask", hits => 24},
  ],
  "JavaScript" => [
    {to => "programming languages", hits => 46}, {to => "web development", hits => 40},
    {to => "Node.js", hits => 34}, {to => "React", hits => 28}, {to => "TypeScript", hits => 22},
  ],
  "statistics" => [
    {to => "machine learning", hits => 44}, {to => "probability theory", hits => 38},
    {to => "data analysis", hits => 32}, {to => "hypothesis testing", hits => 26},
  ],
  "neural networks" => [
    {to => "artificial intelligence", hits => 86}, {to => "machine learning", hits => 80},
    {to => "backpropagation", hits => 74}, {to => "activation functions", hits => 68},
  ],

  # More nodeshells with varying link counts (some with just 1-2 links)
  "existentialism" => [{to => "phenomenology", hits => 50}, {to => "ontology", hits => 40}],
  "jazz improvisation" => [{to => "classical composition", hits => 36}, {to => "electronic music", hits => 28}],
  "dystopian fiction" => [{to => "science fiction", hits => 44}, {to => "utopian literature", hits => 34}],
  "cognitive dissonance" => [{to => "confirmation bias", hits => 52}, {to => "psychology of belief", hits => 42}],
  "fermi paradox" => [{to => "drake equation", hits => 48}, {to => "extraterrestrial life", hits => 38}],

  # Nodeshells with single links
  "number theory" => [{to => "abstract algebra", hits => 30}],
  "topology" => [{to => "differential geometry", hits => 28}],
  "impressionism" => [{to => "abstract expressionism", hits => 26}],
  "medieval history" => [{to => "renaissance period", hits => 24}],
);

my $softlink_count = 0;
foreach my $from_title (keys %softlink_relationships) {
  my $from_node = $DB->getNode($from_title, "e2node");
  next unless $from_node;

  foreach my $link_info (@{$softlink_relationships{$from_title}}) {
    my $to_title = $link_info->{to};
    my $hits = $link_info->{hits} || 1;

    my $to_node = $DB->getNode($to_title, "e2node");
    next unless $to_node;

    # Check if softlink already exists
    my $existing = $DB->sqlSelect('COUNT(*)', 'links',
      "from_node=$from_node->{node_id} AND to_node=$to_node->{node_id} AND linktype=0");

    if (!$existing) {
      print STDERR "Creating softlink: '$from_title' -> '$to_title' (hits: $hits)\n";
      $DB->sqlInsert("links", {
        from_node => $from_node->{node_id},
        to_node => $to_node->{node_id},
        linktype => 0,  # 0 = softlink
        hits => $hits,
        food => 0
      });
      $softlink_count++;
    }
  }
}

print STDERR "Created $softlink_count softlinks between e2nodes\n";
print STDERR "\n=== Softlink creation complete ===\n";

# ============================================================================
# CATEGORIES
# ============================================================================
print STDERR "\n=== Creating categories ===\n";

my $category_type = $DB->getType("category");
my $category_type_id = $category_type->{node_id};
my $category_linktype = getNode("category", "linktype")->{node_id};
my $guest_user = getNode($Everything::CONF->guest_user);

# Helper to create a category and link writeups to it
sub create_category_with_members {
  my ($title, $description, $maintainer, $member_titles) = @_;

  # Check if category already exists
  my $existing = $DB->getNode($title, "category");
  if ($existing) {
    print STDERR "Category '$title' already exists (updating members)\n";
  } else {
    my $maintainer_id = ref($maintainer) ? $maintainer->{node_id} : $maintainer;
    print STDERR "Creating category: '$title' (maintainer: $maintainer_id)\n";
    $DB->insertNode($title, "category", $root_user, {
      doctext => $description,
      author_user => $maintainer_id
    });
    $existing = $DB->getNode($title, "category");
  }

  return unless $existing;

  # Add member nodes to category
  my $added = 0;
  foreach my $member_title (@$member_titles) {
    # Try to find as e2node first, then as writeup
    my $member = $DB->getNode($member_title, "e2node");
    next unless $member;

    # Check if link already exists
    my $link_exists = $DB->sqlSelect('COUNT(*)', 'links',
      "from_node=$existing->{node_id} AND to_node=$member->{node_id} AND linktype=$category_linktype");

    if (!$link_exists) {
      $DB->sqlInsert("links", {
        from_node => $existing->{node_id},
        to_node => $member->{node_id},
        linktype => $category_linktype,
        hits => 0,
        food => 0
      });
      $added++;
    }
  }
  print STDERR "  Added $added members to '$title'\n" if $added > 0;

  return $existing;
}

# Category 1: Coffee Culture (public category - any noder can edit)
my @coffee_nodes = (
  "morning brew rituals",
  "espresso extraction science",
  "third wave movement",
  "café culture in Europe",
  "roasting profiles and chemistry",
  "sustainable farming practices",
  "bean processing methods",
  "pour-over technique mastery",
  "origin terroir characteristics",
  "home barista equipment guide",
  "milk steaming science",
  "cold brew extraction differences",
  "historical origins of the beverage",
  "cupping protocols and evaluation",
  "grinder burr geometry comparison",
  "varietal differences in the plant",
  "water chemistry for optimal extraction",
  "decaffeination process variations",
  "flavor wheel and cupping lexicon",
  "single origin versus blends philosophy",
  "coffee",  # multi-author node
);

create_category_with_members(
  "Coffee Culture",
  "<p>A comprehensive collection of writeups about <strong>coffee</strong> - from brewing techniques and equipment to the science of extraction, global café culture, and the specialty coffee movement.</p><p>Whether you're interested in perfecting your morning pour-over, understanding coffee origins, or exploring the third wave revolution, this category has something for every coffee enthusiast.</p>",
  $guest_user,  # Public category - any noder can add
  \@coffee_nodes
);

# Category 2: Quantum Physics (maintained by genericdev)
my @quantum_nodes = (
  "quantum entanglement explained simply",
  "quantum superposition in computing",
  "quantum tunneling through barriers",
  "quantum field theory fundamentals",
  "quantum decoherence mechanisms",
  "quantum cryptography protocols",
  "quantum error correction codes",
  "quantum supremacy demonstrations",
  "quantum sensing and metrology",
  "quantum machine learning prospects",
  "quantum dots in nanotechnology",
  "quantum annealing for optimization",
  "quantum communication networks",
  "quantum algorithms for chemistry",
  "quantum biology emerging evidence",
  "quantum computing",  # from normaluser4
);

my $normaluser16 = getNode("normaluser16", "user");
create_category_with_members(
  "Quantum Physics",
  "<p>Explorations of <strong>quantum mechanics</strong> and its applications - from fundamental concepts like entanglement and superposition to cutting-edge technologies in quantum computing, cryptography, and sensing.</p><p>This category covers both theoretical foundations and practical applications of quantum physics.</p>",
  $normaluser16,  # Maintained by normaluser16 (quantum writeup author)
  \@quantum_nodes
);

# Category 3: Unicode Test Data (maintained by root for testing)
my @unicode_nodes = (
  "café ☕",
  "日本語 Japanese",
  "emoji test 😀",
  "math symbols ∑∫",
  "currency test €£¥",
  "diacritics àéîöü",
  "arrows ↑→↓←",
  "music notes ♪♫",
  'quotes "test"',
  "unicode spaces",
  "weather symbols ☀☁",
  "zodiac signs ♈♉",
  "hearts and flowers ❤🌸",
  "animals 🐕🐈",
  "cyrillic Привет",
  "greek Ελληνικά",
  "hebrew עברית",
  "food emojis 🍕",
  "tech symbols ⚙️💻",
);

my $normaluser1 = getNode("normaluser1", "user");
create_category_with_members(
  "Unicode and Emoji Test Data",
  "<p>A collection of writeups containing <strong>Unicode characters</strong>, <strong>emoji</strong>, and international text for testing character encoding and display.</p><p>Includes mathematical symbols, currency signs, arrows, music notes, weather symbols, and text in various languages including Japanese, Greek, Hebrew, and Cyrillic.</p>",
  $normaluser1,  # Maintained by normaluser1 (unicode writeup author)
  \@unicode_nodes
);

# Category 4: Programming Topics (public category)
my @programming_nodes = (
  "programming languages",
  "artificial intelligence",
  "machine learning",
  "databases",
  "cybersecurity",
  "neural networks",
  "blockchain technology",
);

create_category_with_members(
  "Programming and Technology",
  "<p>Writeups about <strong>software development</strong>, <strong>programming languages</strong>, and modern technology topics including AI, machine learning, databases, and cybersecurity.</p>",
  $guest_user,  # Public category
  \@programming_nodes
);

# Category 5: Empty category for testing
my @empty_nodes = ();
create_category_with_members(
  "Empty Test Category",
  "<p>This category intentionally has no members. It exists for testing category display when empty.</p>",
  $guest_user,  # Public category
  \@empty_nodes
);

print STDERR "\n=== Category creation complete ===\n";
