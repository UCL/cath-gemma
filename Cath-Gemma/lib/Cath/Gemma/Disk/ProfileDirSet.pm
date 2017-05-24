package Cath::Gemma::Disk::ProfileDirSet;

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars      /;
use v5.10;

# Moo
use Moo;
use strictures 1;

# Non-core (local)
use Type::Params      qw/ compile             /;
use Types::Path::Tiny qw/ Path                /;
use Types::Standard   qw/ ArrayRef Object Str /;

# Cath
use Cath::Gemma::Util;

=head2 starting_cluster_dir

=cut

has starting_cluster_dir => (
	is  => 'ro',
	isa => Path,
);


=head2 aln_dest_dir

=cut

has aln_dir => (
	is  => 'ro',
	isa => Path,
);


=head2 prof_dest_dir

=cut

has prof_dir => (
	is  => 'ro',
	isa => Path,
);


=head2 alignment_filename_of_starting_clusters

=cut

sub alignment_filename_of_starting_clusters {
	state $check = compile( Object, ArrayRef[Str] );
	my ( $self, $starting_clusters ) = $check->( @ARG );

	return $self->aln_dir()->child( alignment_filebasename_of_starting_clusters( $starting_clusters ) );
}

1;
