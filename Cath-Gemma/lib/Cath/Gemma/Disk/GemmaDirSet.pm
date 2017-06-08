package Cath::Gemma::Disk::GemmaDirSet;

use strict;
use warnings;

# Core
use English            qw/ -no_match_vars             /;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Type::Params       qw/ compile                    /;
use Types::Path::Tiny  qw/ Path                       /;
use Types::Standard    qw/ ArrayRef Object Str        /;

# Cath
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
	CathGemmaDiskProfileDirSet
/;
use Cath::Gemma::Util;

=head2 profile_dir_set

=cut

has profile_dir_set => (
	is      => 'ro',
	isa     => CathGemmaDiskProfileDirSet,
	default => sub { Cath::Gemma::Disk::ProfileDirSet->new(); },
	handles => {
		starting_cluster_dir => 'starting_cluster_dir',
		aln_dir              => 'aln_dir',
		prof_dir             => 'prof_dir',
	},
);

=head2 scan_dir

=cut

has scan_dir => (
	is  => 'ro',
	isa => Path,
);

=head2 is_set

=cut

sub is_set {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return (
		$self->profile_dir_set->is_set()
		&&
		$self->scan_dir()
	);
}

=head2 scan_filename_of_cluster_ids

=cut

sub scan_filename_of_cluster_ids {
	state $check = compile( Object, ArrayRef[Str], ArrayRef[Str], CathGemmaCompassProfileType );
	my ( $self, $query_ids, $match_ids, $compass_profile_build_type ) = $check->( @ARG );

	return scan_filename_of_dir_and_cluster_ids(
		$self->scan_dir(),
		$query_ids,
		$match_ids,
		$compass_profile_build_type,
	);
}

1;
