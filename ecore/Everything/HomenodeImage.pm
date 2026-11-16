package Everything::HomenodeImage;

use strict;
use warnings;

use File::Temp ();

=head1 NAME

Everything::HomenodeImage - turn an uploaded file into a homenode image

=head1 SYNOPSIS

  my $result = Everything::HomenodeImage->process($bytes, max_width => 200, max_height => 400);
  if ($result->{ok}) {
    # $result->{data}, $result->{content_type}, $result->{width}, $result->{height}
  } else {
    # $result->{error} is a message for the user
  }

=head1 DESCRIPTION

Identifies the image format from the file's own bytes (never its name or the browser's
claimed type), decodes it with only that format's decoder, then auto-orients it (phone
photos), strips metadata, fits it within the size limits and re-encodes it. What's stored is
always a freshly encoded JPEG, PNG or GIF.

Accepted: JPEG, PNG, GIF (animation kept), WebP (stored as PNG), HEIC/HEIF/AVIF (stored as
JPEG). The ImageMagick policy in the app image allows only these formats too.

=cut

# Raw upload limit. Images are always resized, so this only bounds the work per upload;
# it's sized for full-resolution phone photos. Keep react/components/Documents/UserEdit.js
# (MAX_UPLOAD_BYTES) in sync.
our $MAX_UPLOAD_BYTES = 12 * 1024 * 1024;

# Largest source image we'll decode (a 48 MP phone photo is ~8064x6048).
our $MAX_SOURCE_PIXELS = 60_000_000;

# Most frames we'll take from an animated GIF.
our $MAX_FRAMES = 300;

# format => [ decoder, stored format, file extension, content type ]
my %FORMATS = (
  jpeg => [ 'jpeg', 'jpeg', 'jpg', 'image/jpeg' ],
  png  => [ 'png',  'png',  'png', 'image/png'  ],
  gif  => [ 'gif',  'gif',  'gif', 'image/gif'  ],
  webp => [ 'webp', 'png',  'png', 'image/png'  ],
  heic => [ 'heic', 'jpeg', 'jpg', 'image/jpeg' ],
  avif => [ 'avif', 'jpeg', 'jpg', 'image/jpeg' ],
);

sub accepted_formats_message
{
  return 'Only JPEG, PNG, GIF, WebP and HEIC images are allowed';
}

sub max_upload_megabytes
{
  return int($MAX_UPLOAD_BYTES / (1024 * 1024));
}

# The format of an image file from its leading bytes, or undef if it isn't one we accept.
sub detect_format
{
  my ($class, $bytes) = @_;
  return unless defined $bytes && length($bytes) >= 12;

  return 'png'  if substr($bytes, 0, 8) eq "\x89PNG\r\n\x1a\n";
  return 'jpeg' if substr($bytes, 0, 3) eq "\xFF\xD8\xFF";
  return 'gif'  if substr($bytes, 0, 6) eq 'GIF87a' || substr($bytes, 0, 6) eq 'GIF89a';
  return 'webp' if substr($bytes, 0, 4) eq 'RIFF' && substr($bytes, 8, 4) eq 'WEBP';

  # ISO base media file: "ftyp" box at offset 4, major brand after it
  if (substr($bytes, 4, 4) eq 'ftyp')
  {
    my $brand = substr($bytes, 8, 4);
    return 'avif' if $brand eq 'avif' || $brand eq 'avis';
    return 'heic' if $brand =~ /^(?:heic|heix|hevc|hevx|heim|heis|hevm|hevs|mif1|msf1)$/;
  }

  return;
}

sub process
{
  my ($class, $bytes, %opt) = @_;
  my $max_width  = $opt{max_width}  || 200;
  my $max_height = $opt{max_height} || 400;

  return _fail('No image file uploaded') unless defined $bytes && length($bytes);
  return _fail('Image is too large. Maximum size is ' . $class->max_upload_megabytes . 'MB')
    if length($bytes) > $MAX_UPLOAD_BYTES;

  my $format = $class->detect_format($bytes) or return _fail($class->accepted_formats_message);
  my ($decoder, $stored, $extension, $content_type) = @{ $FORMATS{$format} };

  my $in = File::Temp->new(TEMPLATE => 'e2upload-XXXXXXXX', TMPDIR => 1, UNLINK => 1);
  binmode($in);
  print {$in} $bytes;
  close($in);

  require Image::Magick;
  my $image = Image::Magick->new;

  # Size it up before decoding anything.
  my ($src_width, $src_height) = $image->Ping("$decoder:" . $in->filename);
  return _fail('Failed to read image file') unless $src_width && $src_height;
  return _fail('Image dimensions are too large') if $src_width * $src_height > $MAX_SOURCE_PIXELS;

  my $status = $image->Read("$decoder:" . $in->filename);
  return _fail('Failed to read image file') if _is_error($status) || !@$image;
  return _fail('Animated image has too many frames') if @$image > $MAX_FRAMES;

  if (@$image > 1)
  {
    # Animated GIF: expand optimized frames before resizing them.
    my $frames = $image->Coalesce();
    $image = $frames if ref $frames;
  }
  else
  {
    _check($image->AutoOrient()) or return _fail('Failed to process image');
  }
  _check($image->Strip()) or return _fail('Failed to process image');

  my ($width, $height) = $image->Get('width', 'height');
  my $resized = 0;
  my $scale = 1;
  $scale = $max_width / $width if $width > $max_width;
  $scale = $max_height / $height if $height * $scale > $max_height;
  if ($scale < 1)
  {
    $width  = int($width * $scale)  || 1;
    $height = int($height * $scale) || 1;
    _check($image->Resize(width => $width, height => $height, filter => 'Lanczos'))
      or return _fail('Failed to process image');
    $resized = 1;
  }

  my $out = File::Temp->new(TEMPLATE => 'e2image-XXXXXXXX', TMPDIR => 1, UNLINK => 1);
  close($out);
  my %write = (filename => "$stored:" . $out->filename);
  $write{quality} = 88 if $stored eq 'jpeg';
  _check($image->Write(%write)) or return _fail('Failed to process image');

  open(my $fh, '<', $out->filename) or return _fail('Failed to process image');
  binmode($fh);
  my $data = do { local $/ = undef; <$fh> };
  close($fh);
  return _fail('Failed to process image') unless defined $data && length($data);

  return {
    ok           => 1,
    data         => $data,
    content_type => $content_type,
    extension    => $extension,
    format       => $format,
    width        => $width,
    height       => $height,
    resized      => $resized,
  };
}

sub _fail { return { ok => 0, error => $_[0] } }

# PerlMagick methods return an empty string on success, or an "Exception NNN: ..." string.
# 3xx are warnings (e.g. unknown EXIF tags); 4xx and up are errors.
sub _is_error
{
  my ($status) = @_;
  return 0 unless defined $status && "$status" ne '';
  return 1 unless "$status" =~ /Exception\s+(\d+)/;
  return $1 >= 400 ? 1 : 0;
}

sub _check { return _is_error($_[0]) ? 0 : 1 }

1;
