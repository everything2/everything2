package Everything::MAIL;

############################################################
#
#	Everything::MAIL.pm
#
############################################################

use strict;
use Everything;
use Email::Sender::Simple qw(try_to_sendmail);
use Email::Simple;
use Email::Simple::Creator;
use Email::Sender::Transport::SMTP;


sub BEGIN {
	use Exporter ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(node2mail);
}


sub node2mail {
	my ($addr, $node, $html) = @_;
	my @addresses = (ref $addr eq "ARRAY") ? @$addr:($addr);
	my ($user) = $DB->getNodeWhere({node_id => $$node{author_user}},
		$DB->getType("user"));
	my $subject = $$node{title};
	my $body = $$node{doctext};

	my $SETTING = getNode('mail settings', 'setting');
	my ($from);
	if ($SETTING) {
		my $MAILSTUFF = getVars $SETTING;
		$from = $$MAILSTUFF{systemMailFrom};
	}
	# Make sure we gots some defaults
	$from ||= "root\@localhost";


	my $transport = Email::Sender::Transport::SMTP->new(
  	{ "host" => $Everything::CONFIG{smtp_host},
    	  "port" => $Everything::CONFIG{smtp_port},
    	  "ssl" => $Everything::CONFIG{smtp_use_ssl},
    	  "sasl_username" => $Everything::CONFIG{smtp_user},
    	  "sasl_password" => $Everything::CONFIG{smtp_pass},
  	});

	my $email = Email::Simple->create(
  	"header" => [
     		"To"		=> $addr,
     		"From"		=>  $from,
     		"Subject"		=> $subject,
  	],
  	"body" => $body
	);

	try_to_sendmail($email, { "transport" => $transport });
}

1;
