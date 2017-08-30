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
use Type::Params      qw/ compile        /;
use Types::Path::Tiny qw/ Path           /;
use Types::Standard   qw/ Object Str     /;

=head2 base_dir

=cut

has base_dir => (
	is       => 'ro',
	isa      => Path,
	required => 1,
);

=head2 project

=cut

has project => (
	is      => 'ro',
	isa     => Str,
	default => sub { Cath::Gemma::Disk::ProfileDirSet->new(); },
);

=head2 get_project_subdir_of_subdir

=cut

sub get_project_subdir_of_subdir {
	state $check = compile( Object, Str );
	my ( $self, $subdir ) = $check->( @ARG );

	return $self->base_dir()->child( $subdir )->child( $self->project() );
}

1;
