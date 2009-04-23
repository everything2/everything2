package Everything::File;

#############################################################################
#
#	Everything::Files.pm
#		A module for handling files on the system.  This takes care of 
#		storing, verifying user permissions, and retrieving the file
#		contents.
#
#############################################################################

use strict;
use Everything;
use Everything::HTML;

sub BEGIN
{
	use Exporter ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
#	@EXPORT=qw(
#		getBaseDir
#		getFilename
#		getRelativeFilename
#		getFullFilename
#		getFileType
#		linkFile
#		read
#		write
#		isDirectory
#		genFilename
#		getParentDir
#		);
}


#############################################################################
#	Sub
#		new
#
#	Purpose
#		Construct a new file object.
#
#	Parameters
#		$relName - the name of the file/directory to look at.  This can be
#			a relative (ie '../myfile'), or an absolute path (ie
#			'/usr/local/mydir').  If it is a relative path, the path is
#			relative to the installation directory of Everything (default
#			'/usr/local/everything').
#		$base - (optional) the directory to base the relative directory
#			off of.  If not given, the base will default to the Everything
#			install directory.
#
#	Returns
#		The new file object
#
sub new
{
	my ($packageName, $relName, $base) = @_;
	my $this = {};

	$base = getInstallDir() if(not defined $base);

	$this->{filename} = genFilename($base, $relName);
	$this->{basedir} = $base;

	bless $this;
	return $this;
}


#############################################################################
#	Sub
#		getFileType
#
#	Purpose
#		This looks at the 'filetypes' setting on the system and attempts
#		to figure out the MIME type of that file.
#
#	Returns
#		The MIME type of file.  'text/unknown' if not found.
#
sub getFileType
{
	my ($this) = @_;
	my $NODE = $DB->getNode("filetypes", $DB->getType("setting"));
	my $type = "text/unknown";
	my $vars;
	my $ext = $this->getFullFilename();
	
	if(defined $NODE)
	{
		$vars = getVars($NODE);

		if(defined $vars)
		{
			# get the file extension from the file name
			$ext =~ s/.*\.(.*)/$1/;

			$type = $$vars{$ext} if(exists $$vars{$ext});
		}
	}

	return $type;
}


#############################################################################
#	Sub
#		getFullFilename
#
#	Purpose
#		Get the absolute path fo the file name of this file object.
#
#	Returns
#		The complete path to the file (ie /usr/local/everything/myfile.txt)
#
sub getFullFilename
{
	my ($this) = @_;

	return $this->{filename};
}


#############################################################################
#	Sub
#		getBaseDir
#
#	Purpose
#		Get the directory which is the base of this file.
#
#	Returns
#		The base directory.  This is an absolute path.
#
sub getBaseDir
{
	my ($this) = @_;

	return $this->{basedir};
}


#############################################################################
#	Sub
#		getRelativeFilename
#
#	Purpose
#		Get the full filename relative to the install directory.  For
#		example, if the full filename is:
#			/usr/local/everything/user/root/files/thefile.txt
#		And the install directory is '/usr/local/everything', this will
#		return 'user/root/files/thefile.txt'.
#
#	Returns
#		The filename relative to the base directory given when this object
#		was constructed.
#
sub getRelativeFilename
{
	my ($this) = @_;
	my @base = split '/', ($this->getBaseDir());
	my @file = split '/', ($this->getFullFilename());
	my $baseDir;
	my $fileDir;
	my $result;
	
	while(@base && @file && ($base[0] eq $file[0]))
	{
		shift @base;
		shift @file;
	}

	while(@base)
	{
		shift @base;
		unshift @file, "..";
	}

	$result = join '/', @file;

	return $result;
}


#############################################################################
#	Sub
#		getFilename
#
#	Purpose
#		Get the name of the file.  This does not include any path
#		information.
#
#	Returns
#		The file name
#
sub getFilename
{
	my ($this) = @_;
	my $filename = $this->getFullFilename();

	# Use a greedy search for a '/'.  The result is we get the stuff after
	# the last slash.
	$filename =~ s/(.*)\/(.*)$/$2/;

	return $filename;
}


#############################################################################
#	Sub
#		linkFile
#
#	Purpose
#		Generate an Everything URL to this file using the file manager or
#		the file editor.
#
#	Parameters
#		$label - the text that should appear as the link in the browser
#		$edit - (optional) True if you want to edit the file (use File
#			Editor as the display page), false if you just want to view the
#			file.
#		$full - (optional) True if the link should contain the full path
#			to the file.  Most of the time you will not want to turn this
#			on (users can look at the html and possibly figure out your
#			file system structure, which would be a security risk).
#			However, there may be instances where a full path is necessary.
#
#	Returns
#		The "<a href...>label</a>" string link
#
sub linkFile
{
	my ($this, $label, $edit, $full) = @_;
	my %PARAMS;
	my $href;

	$edit ||= 0;
	
	$PARAMS{node} = "file manager";
	$PARAMS{node} = "file editor" if($edit);

	$PARAMS{filename} = $this->getFullFilename();
	$PARAMS{filename} = $this->getRelativeFilename() if(not $full);

	$PARAMS{displaytype} = "display";

	$href = "<a href=" . urlGen(\%PARAMS) . ">$label</a>";

	return $href;
}


#############################################################################
#	Sub
#		linkFileRaw
#
#	Purpose
#		Create a link to this file using a 'rawdata' node as the handler.
#		The result is a URL that will display the filedata directly to the
#		browser.  For example, following the generated URL to an image will
#		display the image in the browser.  To display an image on a page,
#		just put the URL that this returns in the <IMG SRC="...">.
#
#	Parameters
#		$handler - the 'rawdata' node that is responsible for generating or
#			retrieving the data.
#		$full - (optional) True if the link should contain the full path
#			to the file.  Most of the time you will not want to turn this
#			on (users can look at the html and possibly figure out your
#			file system structure, which would be a security risk).
#			However, there may be instances where a full path is necessary.
#
#	Returns
#		A URL to the file.
#
sub linkFileRaw
{
	my ($this, $handler, $full) = @_;
	my %PARAMS;
	my $url;

	$PARAMS{node} = $handler;
	$PARAMS{type} = "rawdata";
	$PARAMS{filename} = $this->getFullFilename();
	$PARAMS{filename} = $this->getRelativeFilename() if(not $full);
	$PARAMS{displaytype} = "raw";

	$url = urlGen(\%PARAMS);

	return $url;
}


#############################################################################
#	Sub
#		read
#
#	Purpose
#		Read the contents of the file into a string.
#
#	Returns
#		A string that contains the file contents.  If the file is binary,
#		it will contain binary data.
#
sub read
{
	my ($this) = @_;
	my @stats;
	my $data;
	
	open FILE, $this->{filename};
	@stats = stat FILE;

	read FILE, $data, $stats[7];
	close FILE;

	return $data;
}


#############################################################################
#	Sub
#		write
#
#	Purpose
#		Write the given string data to the file.  This will overwrite the
#		existing file.
#
#	Returns
#		1 if successful, 0 otherwise.
#
sub write
{
	my ($this, $data) = @_;

	if(not $this->isDirectory)
	{
		my $file = "> " . $this->{filename};
		if(open FILE, $file)
		{
			print FILE $data;
			close FILE;

			return 1;
		}
	}

	return 0;
}


#############################################################################
sub isDirectory
{
	my ($this) = @_;

	return (-d $this->{filename});
}


#############################################################################
sub isText
{
	my ($this) = @_;

	return (-T $this->{filename});
}


#############################################################################
#	Sub
#		getInstallDir
#
#	Purpose
#		Get the directory where Everything is installed.  This information
#		is created in the database when 'ebase' installed.  This 
#
#	Returns
#		The directory where this instance of the Everything system is
#		installed.
#
sub getInstallDir
{
	my $NODE;
	my $install;
	
	$NODE = $DB->getNode("installdir", $DB->getType("setting"));
	return undef if (not defined $NODE);

	$install = getVars($NODE);

	return $$install{installdir};
}


#############################################################################
sub getParentDir
{
	my ($this) = @_;

	my $parent = $this->getFullFilename();
	$parent .= "/" unless($parent =~ /\/$/);
	$parent .= "../";

	$parent = genFilename("", $parent);

	return $parent;
}


#############################################################################
#	Sub
#		genFilename
#
#	Purpose
#		Given a base path and a relative or absolute path, construct the
#		absolute path to a file/directory.
#
#	Parameters
#		$base - the directory to base relative paths from (ie
#			'/usr/local/everything').  This should not have a trailing
#			slash ('/').
#		$relPath - the relative path to the file (ie '../../myfile.txt').
#			This can be an absolute path, in which case, the base path is
#			ignored.
#
#	Returns
#		The absolute path
#
sub genFilename
{
	my ($base, $relPath) = @_;
	my $NODE;
	my $filename;

	# If a path starts with a '/', it is an absolute path.
	if($relPath =~ /^\//)
	{
		$filename = $relPath;
	}
	else
	{
		$filename = $base . '/' . $relPath;
	}

	# If the path has any ".." (parent dir) in it, we need to remove them
	# Otherwise, the user may be able to play tricks with the path to see
	# files that they do not have access to.  This finds a pattern of
	# "path/../" and replaces it with nothing.  We have this in a loop
	# because somebody might have "/dir1/dir2/dir3/../../../file" and
	# the regex would only match the "dir3/../" ignoring the rest.
	while($filename =~ /\.\.\//)
	{
		$filename =~ s/[^\/]*\/\.\.\///g;
	}

	$filename =~ s/\/\//\//g;
	
	return $filename;
}


#############################################################################
# End of Package
#############################################################################
1;

