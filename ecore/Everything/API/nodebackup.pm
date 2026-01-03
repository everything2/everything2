package Everything::API::nodebackup;

use Moose;
extends 'Everything::API';

use IO::Compress::Zip qw($ZipError);
use Everything::S3;

sub routes {
    return {
        'create' => 'create_backup',
    };
}

sub create_backup {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Login required'}]
        if $user->is_guest;

    # Check environment
    if ($Everything::CONF->environment eq 'development') {
        return [$self->HTTP_OK, {
            success => 0,
            error   => 'Node backup is not available in the development environment. This feature requires AWS S3 access.'
        }];
    }

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $USER_DATA = $user->NODEDATA;
    my $VARS = $user->VARS;

    my $data = $REQUEST->JSON_POSTDATA;
    my $content_type = $data->{contentType} // 'both';  # 'writeups', 'drafts', or 'both'
    my $format = $data->{format} // 'both';             # 'raw', 'html', or 'both'
    my $for_noder = $data->{forNoder};

    # Determine target user
    my $target_user = $USER_DATA;
    if ($for_noder && $user->is_admin) {
        my $target = $DB->getNode($for_noder, 'user');
        return [$self->HTTP_OK, {success => 0, error => "User '$for_noder' not found"}]
            unless $target;
        $target_user = $target;
    }

    my $uid = $target_user->{user_id};

    # Build type filter
    my @type_conditions = ();
    my $writeup_type = $DB->getType('writeup');
    my $draft_type = $DB->getType('draft');

    if ($content_type eq 'writeups' || $content_type eq 'both') {
        push @type_conditions, "type_nodetype=" . $writeup_type->{node_id};
    }
    if ($content_type eq 'drafts' || $content_type eq 'both') {
        push @type_conditions, "type_nodetype=" . $draft_type->{node_id};
    }

    return [$self->HTTP_OK, {success => 0, error => 'No content type selected'}]
        unless @type_conditions;

    my $type_where = join(' OR ', @type_conditions);

    # Get approved HTML tags for rendering
    my $TAGNODE = $DB->getNode('approved html tags', 'setting');
    my $TAGS = $APP->getVars($TAGNODE);

    # Fetch documents
    my $csr = $DB->sqlSelectMany(
        'title, doctext, type_nodetype, node_id',
        'document JOIN node ON document_id=node_id',
        "author_user=$uid AND ($type_where)"
    );

    my @wus = ();
    my $e2parse = $format eq 'raw' ? 1 : ($format eq 'html' ? 2 : 3);

    while (my $wu_row = $csr->fetchrow_hashref) {
        # Add raw text version
        if ($e2parse & 1) {
            push @wus, {
                title         => $wu_row->{title},
                type_nodetype => $wu_row->{type_nodetype},
                suffix        => 'txt',
                doctext       => $wu_row->{doctext},
            };
        }
        # Add rendered HTML version
        if ($e2parse & 2) {
            push @wus, {
                title         => $wu_row->{title},
                type_nodetype => $wu_row->{type_nodetype},
                suffix        => 'html',
                doctext       => "<base href=\"https://everything2.com\">\n" .
                    $APP->breakTags($APP->parseLinks($APP->screenTable($APP->htmlScreen($wu_row->{doctext}, $TAGS))))
            };
        }
    }
    $csr->finish;

    return [$self->HTTP_OK, {success => 0, error => 'No content found to back up'}]
        unless @wus;

    # Create zip file
    my $zipbuffer;
    my $zip = IO::Compress::Zip->new(\$zipbuffer);

    return [$self->HTTP_OK, {success => 0, error => "Failed to create zip: $ZipError"}]
        unless $zip;

    my $draft_type_id = $draft_type->{node_id};
    my %usedtitles = ();

    foreach my $wu (@wus) {
        my $wu_title = $wu->{title};
        my $suffix = $wu->{suffix} || 'txt';

        # Clean title for filesystem
        $wu_title =~ s,[^[:alnum:]&#; ()],-,g;
        $wu_title .= ' (draft)' if $wu->{type_nodetype} == $draft_type_id;

        # Handle duplicate titles
        my $trytitle = $wu_title;
        my $dupebust = 1;
        $wu_title = $trytitle . ' (' . $dupebust++ . ')' while $usedtitles{"$wu_title.$suffix"};
        $usedtitles{"$wu_title.$suffix"} = 1;

        my $doctext = $wu->{doctext};
        utf8::encode($doctext);

        my $folder = $suffix eq 'html' ? 'html' : 'text';
        $zip->newStream(Name => "$folder/$wu_title.$suffix");
        $zip->print($doctext);
    }

    # Generate filename with date
    my $time_offset = ($VARS->{localTimeOffset} || 0) + (($VARS->{localTimeDST} || 0) * 3600);
    my ($day, $month, $year) = (gmtime(time + $time_offset))[3 .. 5];
    $month += 1;
    $year += 1900;
    $day = "0$day" if $day < 10;
    $month = "0$month" if $month < 10;

    my $clean_user = $APP->rewriteCleanEscape($target_user->{title});
    my $format_label = ('text', 'html', 'text-html')[$e2parse - 1];

    # Obfuscate URL
    my $obfuscate = int(rand(8999999)) + 1000000;
    my $filename = "$clean_user.$format_label.$obfuscate.$year-$month-$day.zip";

    $zip->close();

    # Upload to S3
    my $s3 = Everything::S3->new('nodebackup');
    $s3->upload_data($filename, $zipbuffer, {content_type => 'application/zip'});

    my $url = "https://s3-us-west-2.amazonaws.com/nodebackup.everything2.com/$filename";

    my $response = {
        success     => 1,
        downloadUrl => $url,
        filename    => $filename,
        nodeCount   => scalar(@wus),
    };

    # Add warning if backing up someone else's content
    if ($uid != $USER_DATA->{user_id} && $type_where =~ /$draft_type_id/) {
        $response->{warning} = 'This backup contains another user\'s content and may include private drafts. Please do not read the drafts and delete the backup after checking it is OK.';
    }

    return [$self->HTTP_OK, $response];
}

__PACKAGE__->meta->make_immutable;

1;
