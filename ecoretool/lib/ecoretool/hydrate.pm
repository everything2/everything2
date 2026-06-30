#!/usr/bin/perl -w

use strict;
use lib qw(lib);

use ecoretool::base;
package ecoretool::hydrate;
use base qw(ecoretool::base);

BEGIN
{
	unshift @INC, qw(lib /var/everything/ecore);
}

use Everything;
use JSON;
use File::Basename qw(dirname);
use File::Path qw(make_path);

# ecoretool hydrate -- generate the permanent hydration cache bundle (#4423).
#
# Dumps the *canonical, source-controlled* definition of the core/system nodes to
# a JSON bundle that gets committed to the tree and (later) loaded into NodeCache
# at worker startup as a permanent, version-check-exempt resident set.
#
# Membership rule (the safety boundary): nodes whose type is in CONF->static_cache
# -- deploy-only "code nodes" by definition -- plus a short explicit list of
# known-static *instances* that aren't a whole static type (Guest User). A node
# *missing* from the bundle is harmless (it falls back to the normal DB cache
# path); the only unsafe case (bundling a node that mutates at runtime) is
# structurally prevented by the static_cache-type restriction.
#
# This is generation only -- nodepack-style: run occasionally, commit the output,
# build consumes it (the build never touches the DB). The startup loader + the
# dev-time consistency check are separate follow-ups.

sub shortdesc { return "Generate the permanent hydration cache bundle of core (static_cache) nodes"; }

sub _inputs
{
	return {
		"database" => { type => "s", default => "development-docker",
			help => "Database to read from (initEverything config name)" },
		"output"   => { type => "s", default => "../hydration/hydration_cache.json",
			help => "Output JSON bundle path (relative to ecoretool/)" },
	};
}

sub main
{
	my ($this) = @_;

	$this->{options} = $this->_handle_inputs();
	initEverything $this->{options}->{database};

	# Always-static instances that are not a whole static_cache type.
	my %extra_node = ( $Everything::CONF->guest_user => "Guest User" );

	my $static_types = $Everything::CONF->static_cache;   # { typename => 1, ... }

	my %seen;
	my @nodes;
	my %per_type;       # typename => count, for the composition summary

	# 1) Every node of each static_cache type.
	foreach my $typename (sort keys %$static_types)
	{
		my $type = getNode($typename, "nodetype");
		unless ($type)
		{
			print STDERR "WARN: static_cache type '$typename' not found in DB -- skipping\n";
			next;
		}

		my $csr = $DB->{dbh}->prepare("SELECT node_id FROM node WHERE type_nodetype=?");
		$csr->execute($type->{node_id});
		while (my $row = $csr->fetchrow_hashref())
		{
			next if $seen{$row->{node_id}}++;
			my $entry = $this->_hydrate($row->{node_id});
			next unless $entry;
			push @nodes, $entry;
			$per_type{$typename}++;
		}
		$csr->finish();
	}

	# 2) Explicit always-static instances (Guest User, ...).
	foreach my $nid (sort { $a <=> $b } keys %extra_node)
	{
		next if $seen{$nid}++;
		my $entry = $this->_hydrate($nid);
		next unless $entry;
		push @nodes, $entry;
		$per_type{ $entry->{type_title} // "(unknown)" }++;
	}

	# Deterministic ordering -> a stable, diffable committed artifact.
	@nodes = sort { $a->{node_id} <=> $b->{node_id} } @nodes;

	# The bundle IS a flat array of nodes (sorted by node_id): the count is
	# observable as the array length, and we deliberately don't pin the source
	# database name into the committed artifact.
	my $json = JSON->new->canonical(1)->pretty(1)->utf8(1)->encode(\@nodes);

	my $out = $this->{options}->{output};
	make_path(dirname($out));   # be self-sufficient: create the output dir for standalone runs
	open(my $fh, '>', $out) or die "Cannot write $out: $!\n";
	print $fh $json;
	close($fh);

	# Composition summary -- so we can see what's in the bundle and decide on
	# any curation (e.g. if htmlcode/maintenance bloat it).
	print "Hydration cache written: $out\n";
	print "  total nodes: ".scalar(@nodes)."\n";
	foreach my $t (sort { $per_type{$b} <=> $per_type{$a} } keys %per_type)
	{
		printf "  %-22s %d\n", $t, $per_type{$t};
	}
	return;
}

# Produce a JSON-safe, fully-hydrated representation of a node: every MTI-joined
# scalar field, with the circular {type} hashref flattened to a type_title marker
# (CLAUDE.md: never ship $node->{type} -- it's a circular node hashref). Any other
# ref-valued field is dropped defensively; the static_cache types are scalar-field
# nodes, so nothing meaningful is lost (revisit if a bundled type needs a ref field).
sub _hydrate
{
	my ($this, $node_id) = @_;

	my $node = getNodeById($node_id);
	return unless $node;

	my %flat = %$node;
	my $type = delete $flat{type};
	$flat{type_title} = $type ? $type->{title} : undef;

	foreach my $k (keys %flat)
	{
		delete $flat{$k} if ref $flat{$k};
	}

	# Sanitize: never source-control auth secrets. Guest User carries a password
	# hash, password salt, and a session validation token; blank any such field
	# (on every node, defensively) so the committed bundle stays structurally
	# faithful without shipping credentials. These are never needed for the cached
	# core nodes (a guest never authenticates).
	foreach my $secret (qw(passwd salt user_salt validationkey))
	{
		$flat{$secret} = '' if exists $flat{$secret};
	}

	# Int-ify the identity fields so the committed artifact is clean + canonical
	# (MySQL hands these back as strings). Other fields stay as-is.
	$flat{node_id}       = int($flat{node_id})       if defined $flat{node_id};
	$flat{type_nodetype} = int($flat{type_nodetype}) if defined $flat{type_nodetype};

	return \%flat;
}

1;
