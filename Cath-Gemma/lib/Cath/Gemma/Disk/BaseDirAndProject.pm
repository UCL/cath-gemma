package Cath::Gemma::Disk::BaseDirAndProject;

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

TODOCUMENT

=cut

has base_dir => (
	is       => 'ro',
	isa      => Path,
	required => 1,
);

=head2 project

TODOCUMENT

=cut

has project => (
	is      => 'ro',
	isa     => Maybe[Str],
	default => sub { return undef; },
);

=head2 get_project_subdir_of_subdir

TODOCUMENT

=cut

sub get_project_subdir_of_subdir {
	state $check = compile( Object, Str );
	my ( $self, $subdir ) = $check->( @ARG );

	my $project = $self->project();
	return defined( $project ) ? $self->base_dir()->child( $subdir )->child( $project )
	                           : $self->base_dir()->child( $subdir );
}

1;
