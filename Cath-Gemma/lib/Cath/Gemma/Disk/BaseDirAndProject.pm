package Cath::Gemma::Disk::BaseDirAndProject;

=head1 NAME

Cath::Gemma::Disk::BaseDirAndProject - Store a base directory for files and optionally a sub-project

This is used in DirSets as an easy way to determine the standard directories for alignments, profiles etc.

=cut

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars /;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Type::Params      qw/ compile          /;
use Types::Path::Tiny qw/ Path             /;
use Types::Standard   qw/ Object Maybe Str /;

=head2 base_dir

The base directory for files

=cut

has base_dir => (
	is       => 'ro',
	isa      => Path,
	required => 1,
);

=head2 project

An optional project string (or undef)

=cut

has project => (
	is      => 'ro',
	isa     => Maybe[Str],
	default => sub { return undef; },
);

=head2 get_project_subdir_of_subdir

Get the specified subdirectory associated with this base_dir, ie:

`/base_dir/argument`

...or, if a project has been specified, then:

`/base_dir/argument/project`

=cut

sub get_project_subdir_of_subdir {
	state $check = compile( Object, Str );
	my ( $self, $subdir ) = $check->( @ARG );

	my $project = $self->project();
	return defined( $project ) ? $self->base_dir()->child( $subdir )->child( $project )
	                           : $self->base_dir()->child( $subdir );
}

1;
