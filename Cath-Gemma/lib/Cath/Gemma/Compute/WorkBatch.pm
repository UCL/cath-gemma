package Cath::Gemma::Compute::WorkBatch;

=head1 NAME

Cath::Gemma::Compute::WorkBatcher - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use English            qw/ -no_match_vars           /;
use List::Util         qw/ sum0                     /;
use v5.10;

# Moo
use Moo;
use strictures 1;

# Non-core (local)
use Path::Tiny;
use Type::Params       qw/ compile Invocant         /;
use Types::Path::Tiny  qw/ Path                     /;
use Types::Standard    qw/ ArrayRef Object Optional /;

# Cath
use Cath::Gemma::Types qw/
	CathGemmaComputeProfileBuildTask
	CathGemmaExecutables
	/;

=head2 profile_batches

=cut

has profile_batches => (
	is  => 'ro',
	isa => ArrayRef[CathGemmaComputeProfileBuildTask],
	handles_via => 'Array',
	handles     => {
		profile_batches_is_empty => 'is_empty',
		num_profile_batches      => 'count',
		profile_batch_of_index   => 'get',
	}
);

=head2 num_profiles

=cut

sub num_profiles {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return sum0( map { $ARG->count(); } @{ $self->profile_batches() } );
}

=head2 total_num_starting_clusters_in_profiles

=cut

sub total_num_starting_clusters_in_profiles {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return sum0( map { $ARG->total_num_starting_clusters(); } @{ $self->profile_batches() } );
}

=head2 execute_task

=cut

sub execute_task {
	state $check = compile( Object, CathGemmaExecutables, Optional[Path] );
	my ( $self, $exes, $tmp_dir ) = $check->( @ARG );

	my @results;
	foreach my $profile_batch ( @{ $self->profile_batches() } ) {
		push @results, { $profile_batch->execute_task() };
	}
	return \@results;
}

=head2 write_to_file

=cut

sub write_to_file {
	state $check = compile( Object, Path );
	my ( $self, $file ) = $check->( @ARG );
	$file->spew( freeze( $self ) );
}

=head2 read_from_file

=cut

sub read_from_file {
	state $check = compile( Invocant, Path );
	my ( $proto, $file ) = $check->( @ARG );

	return thaw( $file->slurp() );
}

=head2 execute_from_file

=cut

sub execute_from_file {
	state $check = compile( Invocant, Path );
	my ( $proto, $file ) = $check->( @ARG );

	return $proto->read_from_file( $file )->execute_task();
}

1;
