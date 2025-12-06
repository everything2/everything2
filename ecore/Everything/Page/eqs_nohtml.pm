package Everything::Page::eqs_nohtml;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::eqs_nohtml - Everything Quote Server (No HTML version)

=head1 DESCRIPTION

Returns a random quote from a curated collection. This is the plain text version
without HTML formatting, suitable for embedding or API consumption.

=head1 METHODS

=head2 display($REQUEST, $node)

Returns a random quote with parseLinks applied but minimal HTML formatting.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;

    my @wit = (

"No [Viet Cong] ever called me a [nigger].
<br>
<br>--[Muhammad Ali], on why he would not go to [Vietnam]",

"[Love] wakes men, once a [lifetime] each;<br>
They lift their heavy [eyelid|lids], and look;<br>
And, lo, what [textbook|one sweet page] can teach,<br>
They read with [joy], then shut the [book].<br>
And some give thanks, and some [blaspheme],<br>
And most [forget]; but either way,<br>
That and the child's unheeded [dream]<br>
Is all the [light] of all their day.
<br>
<br>--[Uncle Gabby], <i>[Tony Millionaire's The Adventures of Sock Monkey|The Adventures of Tony Millionaire's Sock Monkey]</i>",

"There is no such thing as a 'self-made' man. [interpersonality in Tamil Nadu|We are made up of thousands of others].
<br>Everyone who has ever done a kind deed for us, or spoken one word of [encouragement] to us, has entered into
<br>the make-up of our character and of our thoughts.
<br>
<br>--[George Matthew Adams]",

"<i>Men never start from humble beginnings,</i> I thought. <i>They seem to come
out of the womb seeking a woman's approval.</i>
<br>
<br>--[Templeton], [04/03/00: tether me to the real]",

"Have some [tact] for breakfast!  It's helpful in avoiding the [eat crow|crow] you've got coming for dinner.<br><br>--[dem bones]",

"You can get more with a kind word and a gun than you can with a kind word alone.
<br>
<br>--[Al Capone]",

"If you're going to put your time into this, do [something worth doing].
<br>
<br>- [ideath] -",

"As an adolescent I aspired to lasting [fame], I craved factual certainty, and I thirsted for [a meaningful vision of human life] -- so I became a [scientist]. This is like becoming an archbishop so you can meet girls.
<br>
<br>--[Matt Cartmill]",

"I know not with what [weapons] [World War III] will be fought, but [World War IV] will be fought with [sticks and stones].
<br>
<br>--[Albert Einstein]",

"Flow with whatever is happening and [let your mind be free].
<br>Stay centered by accepting whatever you are doing. This is the ultimate.
<br>
<br>--[Chuang Tzu]",

"It's the Tarantino script of confessions - [chinoodle] in
[Chatterbox] in response to [everyone]'s [Genital Home Wart Removal] node
<br>
<br>",

"[Theatre] is [Life]. [Cinema] is [Art]. [TV] is [Furniture].",

"I am not the first to point out that [capitalism], having defeated [communism], now seems about to do the same to [democracy]. The [market] is doing splendidly, yet we are not.
<br>
<br>--[Ian Frazier]",

"Eat your pets",

"I don't crack the door too far for anyone who's [pushing too hard on me].
<br>
<br>[Liz Phair]",
"Just remember, [math without numbers] scares people, and [people without numbers] scares math.<br><br>--[ameoba], [Amy's drug addled rantings: 11-10-97]",
"This is my '[depressed stance]'. When you're [depressed], it makes a lot of difference how you stand. The [worst] thing you can do is straighten up and hold your head high because then you'll start to [feel better]. If you're going to get any [joy] out of being depressed, you've got to stand like this.<br><br>--[Charlie Brown]",
"No matter how [cynical] I get, I can't keep up.<br><br>--[Lily Tomlin]",
"The [computer] can't tell you the [emotional] story. It can give you the exact [mathematical design], but what's missing is the [eyebrows].<br><br>--[Frank Zappa]",
"Hoping to goodness is not theologically sound.<br><br>--[Charles Schulz], [Peanuts]",
"The majority of the [stupid] is invincible and [guaranteed for all time]. The terror of their [tyranny], however, is alleviated by their lack of [consistency].<br><br>--[Albert Einstein]",
"The [wide world] is all about you; you can [fence] yourselves in, but you cannot for ever fence it out.<br><br>--[Gildor], [The Fellowship Of The Ring], by [J.R.R. Tolkien]",
"So much to do, so much to do...Maybe later I'll go [kick God's ass]...  Oh, wait. [I forgot]. <b>I CAN'T.</b><br><br>--[Satan]",
"He who makes a [beast] of himself gets rid of the [pain] of being a [man].<br><br>--[Hunter S. Thompson]",
"[Survivor2: Journal of the Bones (Endgame)|They say she done them, all of them, in.  <br>They say she done it with an axe.]",
"As far as I'm concerned, being any [gender] is a [drag].
<br>
<br>[Patti Smith]",

"A title like [recreational surgery] is false advertising!  I was expecting something far more depraved!<br><br>--[Uberfetus], in the [chatterbox]",

"Those with the greatest [faith] have the greatest [crises].
<br>
<br>Zed Saeed (a guy [ideath] met on the train, going into New York)",

"..did you know that [friends come in boxes]..
<br>
<br>--[Gary Numan]",

"We try hard to make it work the way it does in movies.
<br>
<br>--The [Gnutella] Support Team",

"Regret for the things we did can be tempered by time; it is [regret] for the things we did not do that is inconsolable.
<BR>
<br>--[Sydney J. Harris]",

"There are very few things I take seriously in life, and my [sense of humor] is one of them.
<br>
<br>--[CaptainSpam]",

"When you have [eliminate]d [everything] that is [impossible], what remains, however [improbable], is the [truth].
<br>
<br>--[Sherlock Holmes|S. Holmes]",


"Highest are those who are born wise. Next are those who become wise by learning. After them come those who have to work hard in order to acquire learning. Finally, to the lowest class of the common people belong those who work hard without ever managing to learn.
<br>
<br>--[Confucius]",


"The oldest and strongest emotion of mankind is [fear] and the oldest and strongest kind of fear is [fear of the unknown].
<br>
<br>--[H. P. Lovecraft]",

"I have been fortunate to be born with a [restless and efficient brain], with a capacity of [clear thought] and an ability to put that thought into words ... I am the lucky beneficiary of a lucky break in the [genetic sweepstakes].
<br>
<br>--[Isaac Asimov]",

"It was funny how people were people everywhere you went, even if the people
concerned weren't the people the people who made up the phrase <i>people are
people everywhere</i> had traditionally thought of as people.
<br>
<br>--[Terry Pratchett], <i>[The Fifth Elephant]</i>",

"Sometimes you just need the clear [epiphany] that an [ass kicking] provides.
<br>
<br>--[Nathan Regener]",

"You Live and Learn or you don't Live long.
<br>
<br>[Lazarus Long]",

"[King Kong died for your sins]
<br>
<br>[Principia Discordia]",

"This book is a [mirror]. When a [monkey] looks in, no apostle looks out.
<br>
<br>Lichtenberg, [Principia Discordia]",

"[Surrealism] aims at the total transformation of the mind and all that resembles it.
<br>
<br>Breton",

"[Bullshit] makes the flowers grow, and that is [beautiful].
<br>
<br>[Principia Discordia]",

"The preferred method of entering a building is to use a tank [main gun round], direct fire [artillery round], or [TOW], [Dragon], or [Hellfire missile] to clear the first room.
<br>
<br>--THE [RANGER HANDBOOK], [U.S. Army], 1992",

"If you want to get into a [fight], there is only one good choice of targets. [Pacifist]s. They don't fight back.
<br>
<br>--[Buster Crash], The [Flametrick Subs]",

"There are no differences but differences of [degree]
<br>between different [degrees of difference]
<br>and no [difference].
<br>
<br>--[William James], under [nitrous oxide], 1882",

"Nobody steps on a church in my town.<br><br>--[Ghostbusters]",

"[Things fall apart...it's scientific.]",

"I don't want to run a company, I'm not good at managing people. You have a problem with the guy in the next
  cubicle? I don't care. Shoot him or something.<br><br>[Marc Andreessen], May 1997",

"You know how you feel right now is how [wimps|pussies] feel all the time.<br><br>--[dem bones], after a serious bout of [dune running]",

"Some see it as a glass [pessimist|half empty], some see it as a glass [optimist|half full].
<br>I prefer to see it as a glass that's twice as big as it needs to be.
<br><br>--[George Carlin]",

"Whoever is fundamentally a [teacher] takes things -- including himself  --
seriously only as they affect his [student]s.
<br><br>--[Friedrich Nietzsche], <i>[Beyond Good and Evil]</i>",

"[Life] is a series of [small awakening]s.<br><br>[Electric Mollusk], <i>[Someone please kill me]</i>",

"I don't know the meaning of the word [surrender]!
<br>I mean, I know it, I'm not dumb... just not in this [context].
<br><br>--[The Tick]",

"[Withdrawal] in [disgust] is not the same as [apathy].<br><br>--[Richard Linklater]",

"To eat were best done at [home].<br><br>--[Macbeth|Lady Macbeth]",

"[Tragedy] is if I cut my finger; [comedy] is if you walk into an open sewer and die.<br><br>--[Mel Brooks]",

"[Work] is [Worship].",

"[Memory] is like a train; you can see it getting [smaller] as it pulls away...<br><br>--[Tom Waits]",

"[N-Wing] hasn't tasted [urine] yet.<br><br>--[N-Wing] in Chatterbox",

"[Obscenity] is whatever gives a [moralist] an [erection].",

"Amicus Plato amicus Aristoteles magis amica veritas <i>Plato is my friend, Aristotle is my friend, but my best friend is truth</i>. --Sir Isaac Newton",

"<i>Knifegirl nods gravely</i><br><br>--[Knifegirl] (obviously) as [zot-fot-piq] went on and on in the [Chatterbox]",

"The [law], in its equality, forbids the [eat the rich|rich] as well as the [kill the poor|poor] to [sleep] under bridges, to [beg] in the streets, and to [steal] bread.<br><br>--[Anatole France]",

"To man the [World] is [twofold], in accordance with his [twofold attitude].--Martin Buber, [I & Thou]",

"Life is a gift of [nature], but beautiful living is the gift of [wisdom].
<br><br>--[Greek] [adage]",

"[Friendship] is one [soul] in two bodies.
<br><br>--[Aristotle]",

"I thought of how odd it is for billions of people to be [alive], yet not one of them is really quite sure what makes people people.
 The only activities I could think of that have no other animal equivalent were [smoking], [body-building], and [writing]. That's not
 much, considering how [special] we seem to think we are.
 <br><br>--[Douglas Coupland], [Life After God]",

"Time ticks by; we grow older. Before we know it, too much time has passed and we've missed the chance to have had other
 people [hurt] us. To a younger me this sounded like [luck]; to an older me this sounds like a [quiet] [tragedy].
<br><br>--[Douglas Coupland], [Life After God]",

"Approach [life] and [cooking] with reckless abandon.
<br><br>--the Dalai Lama",

"Take into account that great [love] and great [achievements] involve great [risk].
<br><br>--The [Dalai Lama]",


"I shall come to you [in the night] and we shall see who is stronger--a [little girl] who won't eat her dinner or a [great big man] with
[cocaine] in his veins.<br><br>--[Sigmund Freud] (in a letter to his fiancee)",

"What a marketing gimmick:  [ass-flavoured yogurt]!  It's low in [fat] and it tastes like [ass] so you eat less! <br><br>--[hoopy frood]",

"Have you any idea what the numbers for the [Theory of Everything] look like?<br><br>--[God] to [Jim Morrison], Doc Holliday], et al, in the book [Jim Morrison's Adventures in the Afterlife].",

"Groups and individuals contain [microfascisms] just waiting to [crystallize].<br><br>--[Deleuze & Guattari]",

"The basic difference between [classical music] and [jazz] is that in the former the music is always greater than its
performance--whereas the way jazz is [performed] is always more important than what is being played.<br><br>--[Andre Previn]",

"[God] created the [Integers]; all the rest is the work of [Man].<br><br>--[L. Kronecker]",

"We have a saying around here [senator]: Don't [piss] down my back and tell me it's [raining].<br><br>--Fletcher, [The Outlaw Josey Wales]",

"Sometimes people say, 'She's no great [talent]<br>
                                 I could [write] like she does'.<br> They are right. <br>
                                         They could; but I do.<br><br>--[Elizabeth Wurtzel]",

"You were [born]. And so you're [free]. So [Happy Birthday].<br><br>--[Laurie Anderson]",

"Either get busy [living] or get busy [dying].<br><br>[The Shawshank Redemption]",

"I cannot and will not cut my [conscience] to fit this year's [fashion|fashions].<br><br>--[Lillian Hellman], [HUAC], 1954",

"Why should I drink [Tequila] in Mexico, when I can get such good [kerosene] in the U.S.? <br><br>--[John Barrymore]",

"[Undead] are my specialty, really.<br><br>--[TheFez]",

"That's all it is: [information]. Even a dream or simulated experience is simultaneous [reality] and [fantasy]. Any way you look at it, all the information a person acquires in a lifetime is just [a drop in the bucket].<br><br>--Batou, [Ghost in the Shell]",

"Like flies to wanton boys, are we to the [gods].
They kill us for their [sport].<br><br>--[Gloucester], [King Lear]",

"Those who will not reason, are [bigots], those who cannot, are [fools], and those who dare not, are [slaves].<br><br>--[George Gordon Noel Byron]",

"The urge to [perform] is not an indication of [talent], and don't you ever forget it.
<br><br>--[Garrison Keillor]",

"There is hopeful [symbolism] in the fact that flags do not wave in a vacuum.<br><br>--[Arthur C. Clarke]
",

"Highly developed spirits often encounter resistance from [mediocre] minds.
<br><br>--[Albert Einstein]",

"[Nature] has given [women] so much power that the [law] has wisely given them very little
<br><br>[Samuel Johnson]",

"I think [polygamy] is absolutely [splendid].<br><br>--[Adam West]",

"To live is to war with trolls in [heart] and [soul]. To write is to sit in judgement on oneself.
<br><br>[Henrik Ibsen]",

"By the time you swear that you are his,<br>
shivering and sighing, <br>
and he promises his [passion] is,<br>
[infinite], undying,<br>
Lady, make a note of this:<br>
one of you is [lying].<br><br>--[Dorothy Parker]",

"A [computer] lets you make more mistakes faster than any invention in human history--with the possible exceptions of
  [handguns] and [tequila].<br><br>--[Mitch Ratliffe], [Technology Review]",

"May you get fucked by a [donkey]! May your wife get fucked by a donkey! May your child fuck your wife!<br><br>--[Egyptian] legal [curse], c. 950 [BC]",

"May you dig up your [father] by moonlight and make [soup] of his [bones].<br><br>--[Fiji Islands] [curse]",

"We [praise] the man who is [angry] on the right grounds, against the right persons, in the right manner, at the right moment, and for the right length of time.<br><br>--[Aristotle], [Nicomachean Ethics], IV",

"Every man with a belly full of the [classics] is an enemy of the human race.<br><br>--[Henry Miller]",

"In my work<br>
  I will take the blame for what is [wrong]<br>
  For that which is clearly mine.<br>
  But what is [right] I can not comprehend.<br><br>
  --[James Hubbell]",

"I prefer the [wicked] rather than the [foolish]. The wicked sometimes rest.<br><br>--[Alexandre Dumas]",

"There's a [truism] that the road to [Hell] is often paved with good intentions. The corollary is that [evil] is best known not by its motives but by its <i>methods</i>.<br><br>--[Eric S. Raymond]",

"Now, now my good man, this is no time for making [enemies]. <br><br>--[Voltaire], on his deathbed, in response to a priest asking that he renounce [Satan]",

"<i>That's a lot of [douche].</i><br><br>--[moJoe], [feminine hygiene products never cease to amaze]",

"I'm a member of an [monkey|ape-like] race at the [end|asshole-end] of the twentieth century...<br><br>--[James], [Low]",

"Shut your [Multifarious postings of Deborah909|multifarious] ass up, [dem bones|bones].<br>
<br>--[knifegirl], [Chatterbox]",

"[Abandon all hope ye who enter here]",

"God made [night] but man made [darkness].<br><br>--[Spike Milligan]",

"If I die in [war] you remember me. If I live in [peace] you don't.<br><br>--[Spike Milligan]",

"The trouble with us in [America] isn't that [the poetry of life] has turned to prose,
but that it has turned to [advertising] copy.<br><br>-- [Louis Kronenberger], [1954]",

"It is harder to fight against [pleasure] than against [anger].<br><br>-- [Aristotle]",

"A [critic] is a bundle of biases held loosely together by [a sense of taste].<br><br>--
[Whitney Balliett]",

"I'm out of your [back door] and into another<br>
Your [boyfriend] doesn't know about me and your [mother]
<br><br>--[The Beastie Boys], [3-Minute Rule]",

"We'll cut the [thick] and break the [thin]...<br><br>--[Peter Murphy], [Cuts You Up]",

"I live with [desertion]...and eight million people.<br><br>
--[The Cure], [Other Voices]",

"A [prayer] can't travel so far these days...<br><br>
--[David Bowie], [A Small Plot Of Land]",

"Give me back the [Berlin wall]<br>
Give me [Joseph Stalin|Stalin] and [St. Paul]<br>
Give me [Christ]<br>
Or give me [Hiroshima]...<br><br>--[Leonard Cohen], [The Future]",

"[Who By Fire?]<br><br>--[Leonard Cohen]",

"Your [money] talks but my [genius] walks...<br><br>--[They Might Be Giants], [You'll Miss Me]",

"[the alphabet is a playground (overview)|The alphabet is a playground]",

"Breathe in...then squeeze the trigger on the [exhale].
<br><br>--[TheFez]",

"Blessed are the [insane|cracked], for they shall let in the [light].",

"I'm allergic to [power]...<br><br>--[Nate]",

"[This aggression will not stand...man.]<br><br>--[The Big Lebowski]",

"[Liberty] without [socialism] is [privilege] and [injustice]; [socialism] without [liberty] is [slavery] and [brutality].<br><br>--[Mikhail Bakunin]",

"If [God] really existed, it would be necessary to [abolish] him.<br><br>--[Mikhail Bakunin]",

"[Skepticism] is the agent of [truth].<br><br>--[Joseph Conrad]",

"What is a [rebel]?  A [man] who says [no].<br><br>
--[Albert Camus]",

"If a man really wants to make a [million dollars], the best way would be to start his own [religion].<br><br>
--[L. Ron Hubbard]",

"If [God] does not [exist], [everything] is permitted.
<br><br>--[Fyodor Dostoyevsky]",

"The [distinction] between [past], [present], and [future] is only a stubbornly persistent [illusion].<br><br>--[Albert Einstein]",

"If the [law] is of such a [nature] that it requires you to be an agent of [injustice] to another, then I say, [breaking the law|break the law].<br><br>--[Henry David Thoreau]",

"You must realize that the [computer] has it in for you. The irrefutable [proof] of this is that the [computer] always does what you tell it to do.",

"Political [language]...is designed to make [lies] sound truthful and [murder] respectable, and to give an appearance of [solidity] to pure wind.<br><br>--[George Orwell]",

"The entire sum of [existence] is the [magic] of being needed by just one person.<br><br>--[Vii Putnam]",

"A ship in harbor is [safe], but that's not what ships are built for.<br><br>--[John Shedd]",

"An [Error] does not become [Truth] by reason of multiplied propagation, nor does Truth become Error just because nobody sees it.<br><br>--[Mohandas Gandhi]",

"When people are [free] to do as they please, they usually [imitate] each other.<br><br>--[Eric Hoffer]",

"[The following addresses had permanent fatal errors...]",

"Give a man a [fire] and he's [warm] for a day, but set fire to him and he's warm for the rest of his [life].<br><br>
--[Terry Pratchett]",

"Just because it's [not nice] doesn't mean it's not [miraculous].<br><br>--[Terry Pratchett]",

"He was said to have the [body] of a twenty-five year old, although no one knew where he kept it...<br><br>--[Terry Pratchett]",

"You can take a [horticulture] but you can't make her think
<br><br>--[Groucho Marx]",

"I'm Great [Me]<br><br>--[Rhys Lewis], Personal Statement on a job application",

"EDB is a dirty [slut].<br><br>--[ohe]",

"For what shall it [profit] a man, if he shall gain the whole world, and lose his own [soul]?<br><br>--[Matthew 16:26]",

"The [faith] that stands on [authority] is not faith.<br><br>--[Ralph Waldo Emerson]",

"So far as I can remember, there is not one word in [the Gospels] in praise of [intelligence].<br><br>--[Bertrand Russell]",

"We should take care not to make the [intellect] our god; it has, of course, powerful muscles, but no [personality].<br><br>--[Albert Einstein]",

"Only two things are [infinite], the [Universe] and human stupidity, and I'm not sure about the former.<br><br>--[Albert Einstein]",

"The Dude Abides<br><br>--[The Big Lebowski]",

"[Evil] never dies, it just comes back in [reruns].<br><br>--[CaptainSpam]",


"In the beginning, there was [nothing]. Then [god] said <i>Let there be light</i>, and there was still [nothing], but you could see it.<br><br>--[Dave Thomas]",

"It is dangerous to be [right] when the [government] is [wrong].<br><br>--[Voltaire]",

"[What luck for rulers that men do not think.]<br><br>
--[Adolf Hitler]",

"The aim of [education] should be to teach us rather [how] to [think], than [what] to think - rather to [improve] our minds, so as to enable us to think for ourselves, than to load the memory with the thoughts of other men.<br><br>--[James Beattle]",

"[Science] is built up with [facts], as a [house] is with stones. But a collection of facts is not more a science than a heap of stones is a home.<br><br>--[Henri Poincar&#233;]",

"[Television] made me what I am.
<br><br>--[David Byrne]",

"[Ideas] lie everywhere, like apples fallen and melting in the [grass] for lack of wayfaring strangers with an [eye] and a [tongue] for [beauty].<br><br>--[Ray Bradbury]",

"[Fascism] is [fascism]. I don't care if the trains run on time.
<br><br>--[Douglas McFarland]",

"I'd rather be [brilliant] than on time.
<br><br>--[edebroux]",

"When [I] look [up], I miss all the [big stuff].  When I look [down], I [trip] over [things].<br><br>--
[Ani Difranco]",

"What makes the universe so hard to [comprehend] is that there is nothing to [compare] it with.",

"My [thumbs] have gone weird!<br><br>--[Bruce Robinson]",

"I have nothing to declare but my [genius].<br><br>--[Oscar Wilde]",

"Server Error (Error Id 5066529)!
<br><br>An [error] has occured. Please contact the site [Nathan, this is unacceptable|administrator] with the Error Id. [Thank you].<br><br>--[Everything Quote Server]",

"Human beings can always be relied upon to assert, with vigor, their God-given right to be [stupid].<br><br>
--[Dean Koontz]",

"Well, that was about as useful as [bong hits] at 7:30 in the morning...<br><br>--overheard by [Ailie] after her [inverse theory] class",

"The only man who makes no [mistakes] is the man who never does anything. Do not be [afraid] of mistakes providing you do not make the same one [twice].<br><br>--[Theodore Roosevelt]",

"I am not interested in the [past]. I am interested in the [future] for that is where I intend to spend the rest of my [life].<br><br>--[Charles F. Kettering]",

"To be irritated by [criticism] is to acknowledge it is deserved.<br><br>--[Cornelius Tacitus]",

"[Damocles] got sucker punched--<br>
a [bastard sword] at Sunday brunch",

"[Fantastic] tricks the [truth].",

"These are the motions of a [lifetime],<br>
Given to us in the spirit of [tragedy]<br>
By [mad], laughing [children].",

"You might want to [Gary|get down] for this...<br><br>--[the gilded frame]",

"You've got an [organ] going there...no wonder the sound has so much [body]...",

"I don't <i>do</i> [pennies].<br><br>--[The Gilded Frame]",

"All [pleasure] is [relief].",

"Well, [dem bones|dude], if you're not going to go to the [hospital] maybe we should smoke another bowl?<br><br>--[TheFez]",

"That'd be the [butt], Bob<br><br>
--[tregoweth], [the most interesting place you've had sex]",

"[Art] is anything you can get away with.<br><br>
--[Marshall McLuhan]",

"Admit [Nothing]. Blame [Everyone]. Be [Bitter].
<br><br>--?[Jonathan Carroll]?",

"For as a man thinketh in his [heart], so is he.<br><br>
--[Proverbs] 23:7",

"The mind is the [man], and knowledge [mind]; a man is but what he knoweth.<br><br>--[Francis Bacon]",

"Repetition is the [death] of the soul.",

"Eat the [rich].",

"E2: The Return. <i>This time it's personal</i>.
<br><br>--[CaptainSpam], [E2]",

"Give in to [love], or give in to [fear].",

"The only thing to [fear] is [fearlessness].<br><br>--[R.E.M.]",

"[History] is made to seem [unfair].<br><br>--[R.E.M.]",

"[Grace Beats Karma]",

"[Simplicity] of character is the natural result of [Deep Thoughts|profound thought].",

"<i>[I've]got[a]match[your]embrace[and]my[collapse]...</i>
<br><br>--[They Might Be Giants], [I've Got A Match]",

"Where your eyes don't go a filthy [scarecrow] waves his broomstick arms and does a [parody] of each [unconscious] thing you do...<br><br>--[They Might Be Giants], [Where Your Eyes Don't Go]",

"[Subvert] the dominant paradigm.",

"Avoid the [cliche] of your time.",

"[Everything Drugs|Participate in your own manipulation.]",

"Drink [cold], <br>piss [warm]<br> and fuck the [Hitler|Huns].<br><br>--[Henry Miller]",

"Then [Goldilocks] said, 'These hands have too much [semen] on them. And these hands don't have enough [semen] on them.
But these hands - these [semen]-covered hands are just right.'<br><br>--[jessicapierce], [What to do if you've got too much semen on your hands]",

"[He] hung out with philosophers like [Socrates] and other layabouts and ne'er-do-wells
            <br><br>--[hatless], [play-doh]",

"I do not resemble a [warrior] so much as a [short bus|special student] out on a [shore leave|day pass]. So be it.<br><br>--[hoopy_frood], [The Squirrel Diaries]",

"In the [Fall] of 1999, I figured out that I'm just not as [smart] as I like to think I am.<br><br>--[pife], [I Wish I Had Thought Of Everything]",

"<i>Let's get those [missiles] ready to destroy the [universe]!</i><br><br>--[They Might Be Giants], [For Science] ",

"No one in the world ever gets what they [want] and that is [beautiful]<br><br>--[They Might Be Giants], [Don't Let's Start]",

"[Nathan, This Is Unacceptable]",

"It is not your [duty] to finish the [work], but you are not at liberty to [neglect] it.<br> ([Avot]. 1:10)",

"i represent<br><b>[GOD]</b><br>you fuck<br><br>--[Unamerican Activities|!!!srini x]",

"I never did [a day's work] in my life; [it was all fun].<br><br>--[Thomas Edison]",

"A society is a [healthy society] only to the degree that it exhibits [anarchistic] traits.<br><br>--Jens Bj&#248;rneboe",

"[This world] is gradually becoming a place where [I do not care] to be any more.<br><br>--[John Berryman]",

"[Authenticity] is a [red herring].<br><br>--Jocelyn Linnekin",

"The [weed] of crime bears [bitter fruit]. But it makes a pretty good [milkshake].<br><br>--<i>[Sam & Max]</i>",

"[Truth] suffers from too much [analysis].<br><br>--ancient [Fremen] saying,<br><i>[Dune Messiah]</i> by [Frank Herbert]",

"[Luminous] beings are we, not this [crude matter].<br><br>--[Yoda]",

"My head is a [strange] place.<br><br>--[pukesick]",

"Live your [life], do your [work], then [take your hat].<br><br>--[Henry David Thoreau]",

"I am trying to wrap my [brain] around your weirdness; it's not working.<br><br>--[Dylan Hillerman: Freelance Illustrator|Dylan Hillerman]",

"I'm not [nodes about Everything addiction|addicted]. I can stop any time my computer crashes.<br><br>--[The Grey Defender]",

"When I hear the word [culture] I [that's when i reach for my revolver|reach for my revolver].<br><br>attributed to [Hermann G&#246;ring]",

"I got no time for the jibba-jabba!<br><br>--[Mr. T]",

"Never eat at a place called [Mom]'s. Never play [cards] with a man named Doc. And never [lie down] with a woman who's got more [troubles] than you.<br><br>--[Nelson Algren]",

"A boy <i>likes</i> being a member of the [bourgeoisie]. Being a member of the bourgeoisie is <i>good</i> for a boy.<br>It makes him feel <i>warm</i> and <i>happy</i>.<br><br>--[Donald Barthelme], <i>[Our Work And Why We Do It]</i>",

"I have the [hammer], I will [smash] anybody who threatens, however remotely, the [company] way of life. We know what we're doing. The [vodka] ration is generous. Our reputation for excellence is unexcelled, in every part of the world. And will be maintained until the destruction of our [art] by some other art which is just as good but which, I am happy to say, has not yet been invented.<br><br>--[Donald Barthelme], <i>[Our Work And Why We Do It]</i>"

);

    my $quote = $wit[int(rand(@wit))];
    my $html = "<b><font size=3>" . $self->APP->parseLinks($quote) . "</font></b>";

    return [$self->HTTP_OK, $html];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
