package Everything::Delegation::document;

use strict;
use warnings;

# Used in: ajax_update
use JSON;
use Everything::Delegation::opcode;

BEGIN {
    *getNodeById     = *Everything::HTML::getNodeById;
}

sub ajax_update
{
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $mode = $query->param("mode") || "var";
    $PAGELOAD->{noparsecodelinks} = 'nolinks';

    if ($mode eq 'message') {
        $query->param('message',$query->param("msgtext"));
        my @deleteParams = split(',', $query->param("deletelist") || '');
        foreach (@deleteParams) {
            $query->param($_,1);
        }
        Everything::Delegation::opcode::message($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
        return $query->param('sentmessage');
    }

    $NODE = getNodeById(124);

    return '';
}

1;
