#!/usr/bin/perl -w
#
# Homenode image uploads: Everything::HomenodeImage (format detection, decode, orient, strip,
# resize, re-encode), the ImageMagick setup in the app image, and POST /api/user/upload-image
# end to end with S3 stubbed.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5 /var/everything/t/lib);
use Test::More;
use File::Temp ();
use JSON;
use URI::Escape qw(uri_escape_utf8);
use Everything;
use Everything::HomenodeImage;
use TestSeed;
use Image::Magick;

initEverything 'everything';

my $HI = 'Everything::HomenodeImage';
my $fixture = '/var/everything/t/fixtures/images/homenode-base.png';
plan skip_all => "missing $fixture" unless -r $fixture;

sub slurp { my ($f) = @_; open( my $fh, '<', $f ) or die "$f: $!"; binmode $fh; local $/; return scalar <$fh> }
my $base_png = slurp($fixture);    # 64x48

# Derive test images from the fixture (writing the accepted formats is allowed by the policy).
sub derive {
    my ( $format, %opt ) = @_;
    my $img = Image::Magick->new;
    $img->Read("png:$fixture");
    $img->Resize( width => $opt{width}, height => $opt{height} ) if $opt{width};
    if ( $opt{frames} ) {
        my $second = $img->Clone;
        $second->Negate;
        push @$img, $second->[0];
    }
    my $out = File::Temp->new( UNLINK => 1 );
    close $out;
    my $err = $img->Write("$format:" . $out->filename);
    die "derive $format: $err" if "$err";
    return slurp( $out->filename );
}

sub dims {
    my ( $bytes, $format ) = @_;
    my $tmp = File::Temp->new( UNLINK => 1 );
    binmode $tmp;
    print {$tmp} $bytes;
    close $tmp;
    my $img = Image::Magick->new;
    $img->Read("$format:" . $tmp->filename);
    return ( $img->Get( 'width', 'height' ), scalar(@$img) );
}

# A JPEG with an EXIF orientation tag (6 = rotate 90 degrees clockwise to display).
sub with_exif_orientation {
    my ($jpeg) = @_;
    my $tiff = "II*\x00" . pack( 'V', 8 ) . pack( 'v', 1 ) . pack( 'vvVvv', 0x0112, 3, 1, 6, 0 ) . pack( 'V', 0 );
    my $payload = "Exif\x00\x00" . $tiff;
    my $app1 = "\xFF\xE1" . pack( 'n', length($payload) + 2 ) . $payload;
    return substr( $jpeg, 0, 2 ) . $app1 . substr( $jpeg, 2 );
}

# --- format detection -------------------------------------------------------------------------
is( $HI->detect_format($base_png),                 'png',  'PNG' );
is( $HI->detect_format( derive('jpeg') ),          'jpeg', 'JPEG' );
is( $HI->detect_format( derive('gif') ),           'gif',  'GIF' );
is( $HI->detect_format( derive('webp') ),          'webp', 'WebP' );
is( $HI->detect_format( "\0\0\0\x18ftypheic" . "\0" x 8 ), 'heic', 'HEIC' );
is( $HI->detect_format( "\0\0\0\x18ftypmif1" . "\0" x 8 ), 'heic', 'HEIF' );
is( $HI->detect_format( "\0\0\0\x1cftypavif" . "\0" x 8 ), 'avif', 'AVIF' );
is( $HI->detect_format("%!PS-Adobe-3.0\nshowpage\n"),      undef,  'not an accepted image: refused' );
is( $HI->detect_format("<svg xmlns='http://www.w3.org/2000/svg'/>"), undef, 'SVG: refused' );
is( $HI->detect_format('short'),                   undef,  'too short to tell: refused' );

# --- processing --------------------------------------------------------------------------------
{
    my $r = $HI->process( $base_png, max_width => 200, max_height => 400 );
    ok( $r->{ok}, 'a small PNG is accepted' );
    is( $r->{content_type}, 'image/png', 'and stored as PNG' );
    ok( !$r->{resized}, 'without resizing' );
    is( substr( $r->{data}, 0, 8 ), "\x89PNG\r\n\x1a\n", 'the stored bytes are a PNG' );
}

{
    my $photo = derive( 'jpeg', width => 3000, height => 2250 );
    my $r = $HI->process( $photo, max_width => 200, max_height => 400 );
    ok( $r->{ok}, 'a full-size photo is accepted' );
    ok( $r->{resized}, 'and resized' );
    is( "$r->{width}x$r->{height}", '200x150', 'to fit the width limit' );
    is( $r->{content_type}, 'image/jpeg', 'stored as JPEG' );
    my ( $w, $h ) = dims( $r->{data}, 'jpeg' );
    is( "${w}x$h", '200x150', 'the stored image really is that size' );
}

{
    my $tall = derive( 'png', width => 300, height => 1200 );
    my $r = $HI->process( $tall, max_width => 200, max_height => 400 );
    is( "$r->{width}x$r->{height}", '100x400', 'a tall image fits the height limit' );
}

{
    my $rotated = with_exif_orientation( derive('jpeg') );
    my $r = $HI->process( $rotated, max_width => 200, max_height => 400 );
    ok( $r->{ok}, 'a photo with EXIF orientation is accepted' );
    is( "$r->{width}x$r->{height}", '48x64', 'and turned upright' );
    unlike( $r->{data}, qr/Exif/, 'with its metadata stripped' );
}

{
    my $r = $HI->process( derive('webp'), max_width => 200, max_height => 400 );
    ok( $r->{ok}, 'WebP is accepted' );
    is( $r->{content_type}, 'image/png', 'and stored as PNG' );
    is( substr( $r->{data}, 0, 4 ), "\x89PNG", 'the stored bytes are a PNG' );
}

{
    my $anim = derive( 'gif', width => 600, height => 450, frames => 1 );
    my $r = $HI->process( $anim, max_width => 200, max_height => 400 );
    ok( $r->{ok}, 'an animated GIF is accepted' );
    is( $r->{content_type}, 'image/gif', 'stored as GIF' );
    my ( $w, $h, $frames ) = dims( $r->{data}, 'gif' );
    is( "${w}x$h", '200x150', 'resized' );
    is( $frames, 2, 'with its animation intact' );
}

{
    my $r = $HI->process( "%!PS-Adobe-3.0\nnewpath 10 10 moveto 50 50 lineto stroke showpage\n" );
    ok( !$r->{ok}, 'a file that is not an accepted image is refused' );
    is( $r->{error}, $HI->accepted_formats_message, 'with the accepted-formats message' );

    $r = $HI->process( "\x89PNG\r\n\x1a\n" . "%!PS-Adobe-3.0\nshowpage\n" x 4 );
    ok( !$r->{ok}, 'a broken image is refused' );
    is( $r->{error}, 'Failed to read image file', 'as unreadable' );

    $r = $HI->process( "\x89PNG\r\n\x1a\n" . ( "\0" x $Everything::HomenodeImage::MAX_UPLOAD_BYTES ) );
    ok( !$r->{ok}, 'an upload over the size limit is refused' );
    like( $r->{error}, qr/Maximum size is 12MB/, 'with the limit in the message' );

    $r = $HI->process('');
    ok( !$r->{ok}, 'an empty upload is refused' );
}

# --- the app image's ImageMagick setup ----------------------------------------------------------
{
    my $ps = File::Temp->new( UNLINK => 1 );
    print {$ps} "%!PS-Adobe-3.0\nnewpath 10 10 moveto 50 50 lineto stroke showpage\n";
    close $ps;
    for my $coder (qw(ps eps pdf mvg msl)) {
        my $err = Image::Magick->new->Read( "$coder:" . $ps->filename );
        like( "$err", qr/security policy|not authorized|no decode delegate/i, "only accepted formats can be decoded ($coder)" );
    }
    ok( !-e '/usr/bin/gs', 'no unneeded interpreters in the image' );
}

# --- image URLs ----------------------------------------------------------------------------------
{
    my $host = $Everything::CONF->homenode_image_host;
    is( $APP->homenode_image_url('/jaybonci?v=123'), "https://s3-us-west-2.amazonaws.com/$host/jaybonci?v=123", 'a versioned imgsrc keeps its version' );
    is( $APP->homenode_image_url('/old_user'), "https://s3-us-west-2.amazonaws.com/$host/old_user", 'an unversioned one still works' );
    is( $APP->homenode_image_url('no_slash'), "https://s3-us-west-2.amazonaws.com/$host/no_slash", 'a missing slash is added' );
    is( $APP->homenode_image_url(''), '', 'no image, no URL' );
}

# --- S3 write failures are reported, not just written to a file in the container ---------------
{
    require Everything::S3;
    my $s3 = bless { bucket => 'test-bucket', s3 => bless( {}, 'FailingS3' ) }, 'Everything::S3';
    no warnings 'once';
    *FailingS3::PutObject = sub { die "simulated failure\n" };
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    ok( !$s3->upload_data( 'somekey', 'data', { content_type => 'image/png' } ), 'a failed S3 write returns false' );
    like( join( '', @warnings ), qr/upload_data failed: bucket=test-bucket key=somekey: simulated failure/, 'and warns, so it reaches the error log' );
}

# --- POST /api/user/upload-image, end to end -----------------------------------------------------
my $app = eval { do '/var/everything/app.psgi' };
SKIP: {
    skip "app.psgi unavailable: $@", 1 unless ref $app eq 'CODE';
    require Plack::Test;
    require HTTP::Request::Common;
    require Everything::S3;
    my $test = Plack::Test->create($app);

    my $user = TestSeed::make_user( $DB, $APP, label => 'imgup', password => 'blah', experience => 1000, numwriteups => 25 );
    ok( $APP->getLevel($user) >= 1, 'the uploader is level 1 or more: the normal-user limits' );
    my $cookie_for = sub { my ($u) = @_; $Everything::CONF->cookiepass . '=' . uri_escape_utf8("$u->{title}|$u->{passwd}") };
    my $cookie = $cookie_for->($user);

    my @stored;
    no warnings 'redefine';
    local *Everything::S3::new = sub { return bless {}, 'Everything::S3' };
    local *Everything::S3::upload_data = sub { my ( $self, $key, $data, $props ) = @_; push @stored, { key => $key, data => $data, %{ $props || {} } }; return 1 };
    local $Everything::CONF->{environment} = 'production';    # uploads only run in production

    my $upload = sub {
        my ( $name, $type, $bytes, $as ) = @_;
        my $res = $test->request( HTTP::Request::Common::POST(
            '/api/user/upload-image',
            Cookie       => $as ? $cookie_for->($as) : $cookie,
            Content_Type => 'form-data',
            Content      => [ imgsrc_file => [ undef, $name, 'Content-Type' => $type, Content => $bytes ] ],
        ) );
        return eval { decode_json( $res->content ) } || { raw => $res->content };
    };

    my $json = $upload->( 'IMG_1234.jpg', 'image/jpeg', derive( 'jpeg', width => 3000, height => 2250 ) );
    is( $json->{success}, 1, 'a full-size phone photo uploads' ) or diag explain $json;
    is( scalar(@stored), 1, 'one object is stored' );
    is( $stored[0]{ContentType} // $stored[0]{content_type}, 'image/jpeg', 'with the content type of what was stored' );
    my ( $w, $h ) = @stored ? dims( $stored[0]{data}, 'jpeg' ) : ( 0, 0 );
    ok( $w <= 400 && $h <= 800, "and it was resized (${w}x$h)" );
    like( $DB->sqlSelect( 'imgsrc', 'user', "user_id = $user->{node_id}" ), qr{^/\Q$stored[0]{key}\E\?v=\d+$},
        'the homenode points at it, with a version so browsers fetch the new image' ) if @stored;
    is( $stored[0] && $stored[0]{cache_control}, 'public, max-age=604800', 'stored with a cache lifetime' );
    like( $json->{imgsrc_url} // '', qr{^https://s3-us-west-2\.amazonaws\.com/[^/]+/\Q$stored[0]{key}\E\?v=\d+$}, 'the response has the new URL' )
        if @stored;
    ok( $DB->sqlSelect( 'newuserimage_id', 'newuserimage', "newuserimage_id = $user->{node_id}" ), 'it is queued for moderation' );

    @stored = ();
    $json = $upload->( 'avatar.png', 'image/png', "%!PS-Adobe-3.0\nshowpage\n" );
    ok( !$json->{success}, 'a file that is not an image is refused, whatever its name and type' );
    is( scalar(@stored), 0, 'and nothing is stored' );

    @stored = ();
    $json = $upload->( 'sticker.webp', 'image/webp', derive('webp') );
    is( $json->{success}, 1, 'a WebP image uploads' );
    is( $stored[0] && ( $stored[0]{ContentType} // $stored[0]{content_type} ), 'image/png', 'stored as PNG' );

    @stored = ();
    my $newbie = TestSeed::make_user( $DB, $APP, label => 'imgnewbie', password => 'blah' );
    if ( $APP->getLevel($newbie) < 1 ) {
        $json = $upload->( 'me.png', 'image/png', $base_png, $newbie );
        like( $json->{error} // '', qr/level 1/, 'a level 0 user is told they need level 1' );
        is( scalar(@stored), 0, 'and nothing is stored' );
    }

    # Every attempt leaves one log line with what came in and what happened.
    my $logged = sub {
        my ($code) = @_;
        my $err = '';
        {
            local *STDERR;
            open( STDERR, '>', \$err ) or die;
            $code->();
        }
        return [ map { decode_json($_) } $err =~ /^E2EVENT (\{.*\})$/mg ];
    };
    my $events = $logged->( sub { $upload->( 'notes.png', 'image/png', 'not an image at all' ) } );
    my ($refusal) = grep { $_->{event} eq 'homenode_image_upload' } @$events;
    ok( $refusal, 'a refused upload is logged' );
    is( $refusal && $refusal->{outcome}, 'refused', 'as refused' );
    is( $refusal && $refusal->{reason}, Everything::HomenodeImage->accepted_formats_message, 'with the reason' );
    is( $refusal && $refusal->{client_type}, 'image/png', "with the browser's claimed type" );
    is( $refusal && $refusal->{client_ext}, 'png', 'and the file extension' );
    is( $refusal && $refusal->{user}, $user->{title}, 'and who' );

    $events = $logged->( sub { $upload->( 'IMG_9.jpg', 'image/jpeg', derive( 'jpeg', width => 1200, height => 900 ) ) } );
    my ($stored_event) = grep { $_->{event} eq 'homenode_image_upload' } @$events;
    is( $stored_event && $stored_event->{outcome}, 'stored', 'a stored upload is logged' );
    is( $stored_event && $stored_event->{detected}, 'jpeg', 'with the detected format' );
    is( $stored_event && "$stored_event->{width}x$stored_event->{height}", '200x150', 'and the stored size' );
    ok( $stored_event && $stored_event->{bytes} > 0, 'and the upload size' );

    {
        local *Everything::S3::upload_data = sub { return };
        $events = $logged->( sub { $upload->( 'IMG_9.jpg', 'image/jpeg', derive('jpeg') ) } );
        my ($failed) = grep { $_->{event} eq 'homenode_image_upload' } @$events;
        is( $failed && $failed->{outcome}, 'storage_failed', 'a storage failure is logged as one' );
    }

    # Outside production the image is processed and checked, but not stored.
    {
        local $Everything::CONF->{environment} = 'development';
        @stored = ();
        $json = $upload->( 'IMG_1234.jpg', 'image/jpeg', derive( 'jpeg', width => 3000, height => 2250 ) );
        like( $json->{error} // '', qr/This image is fine \(200x150 image\/jpeg\).*only stored in production/, 'dev reports what would be stored' );
        is( scalar(@stored), 0, 'and stores nothing' );
        $json = $upload->( 'avatar.png', 'image/png', "not an image at all" );
        is( $json->{error}, Everything::HomenodeImage->accepted_formats_message, 'and still refuses what it should' );
    }

    $DB->sqlDelete( 'newuserimage', "newuserimage_id IN ($user->{node_id}, $newbie->{node_id})" );
}

END { TestSeed::cleanup($DB) if $DB }

done_testing();
