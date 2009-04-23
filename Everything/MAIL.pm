package Everything::MAIL;

############################################################
#
#	Everything::MAIL.pm
#
############################################################

use strict;
use Everything;



sub BEGIN {
	use Exporter ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
			node2mail
			mail2node);
}


sub node2mail {
	my ($addr, $node, $html) = @_;
	my @addresses = (ref $addr eq "ARRAY") ? @$addr:($addr);
	my ($user) = $DB->getNodeWhere({node_id => $$node{author_user}},
		$DB->getType("user"));
	my $subject = $$node{title};
	my $body = $$node{doctext};
	use Mail::Sender;

	my $SETTING = getNode('mail settings', 'setting');
	my ($mailserver, $from);
	my $client = "localhost";
	if ($SETTING) {
		my $MAILSTUFF = getVars $SETTING;
		$mailserver = $$MAILSTUFF{mailServer};
		$from = $$MAILSTUFF{systemMailFrom};
		$client = $$MAILSTUFF{client};
	}
	# Make sure we gots some defaults
	$mailserver ||= "localhost";
	$from ||= "root\@localhost";


	my $sender = new Mail::Sender({smtp => $mailserver, from => $from});
	$sender->{client} = $client;
	my $headers = "MIME-Version: 1.0\r\nContent-type: text/html\r\nContent-Transfer-Encoding: 7bit" if $html;

	$sender->MailMsg({to=>$addr,
			headers => $headers, 
			subject=>$subject,
			msg => $body});
	$sender->Close();                
}

sub mail2node
{
	my ($file) = @_;
	my @filez = (ref $file eq "ARRAY") ? @$file:($file);
	use Mail::Address;
	my $line = '';
	my ($from, $to, $subject, $body);
	foreach(@filez)
	{
		open FILE,"<$_" or die 'suck!\n';
		until($line =~ /^Subject\: /)
		{
			$line=<FILE>;
			if($line =~ /^From\:/)       
			{ 
				my ($addr) = Mail::Address->parse($line);
				$from = $addr->address;
			}
			if($line =~ /^To\:/)  
			{
				my ($addr) = Mail::Address->parse($line);
				$to = $addr->address;
			}
			if($line =~ /^Subject\: (.*?)/)
			{ print "hya!\n"; $subject = $1; }
			print "blah: $line" if ($line);
		}
		while(<FILE>)
		{
			my $body .= $_;
		}
		my ($user) = $DB->getNodeWhere({email=>$to},
			$DB->getType("user"));
		my $node;
		%$node = { author_user => getId($user),
			from_address => $from,
			doctext => $body};
        $DB->insertNode($subject, $DB->getType("mail"), -1, $node);
	}
}
1;
