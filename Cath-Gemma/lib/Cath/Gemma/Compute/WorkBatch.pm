package Cath::Gemma::Compute::WorkBatch;

=head1 NAME

Cath::Gemma::Compute::WorkBatch - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use English            qw/ -no_match_vars   /;
use List::Util         qw/ sum0             /;
use Storable           qw/ thaw             /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Path::Tiny;
use Type::Params       qw/ compile Invocant /;
use Types::Path::Tiny  qw/ Path             /;
use Types::Standard    qw/ ArrayRef Object  /;

# Cath
use Cath::Gemma::Compute::ProfileBuildTask;
use Cath::Gemma::Compute::ProfileScanTask;
use Cath::Gemma::Types qw/
	CathGemmaComputeProfileBuildTask
	CathGemmaComputeProfileScanTask
	CathGemmaDiskExecutables
	/;
use Cath::Gemma::Util;

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

=head2 scan_batches

=cut

has scan_batches => (
	is  => 'ro',
	isa => ArrayRef[CathGemmaComputeProfileScanTask],
	handles_via => 'Array',
	handles     => {
		scan_batches_is_empty => 'is_empty',
		num_scan_batches      => 'count',
		scan_batch_of_index   => 'get',
	}
);


=head2 id

=cut

sub id {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return generic_id_of_clusters( [ map { $ARG->id() } @{ $self->profile_batches() } ] );
}

=head2 num_profiles

=cut

sub num_profiles {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return sum0( map { $ARG->num_profiles(); } @{ $self->profile_batches() } );
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
	state $check = compile( Object, CathGemmaDiskExecutables );
	my ( $self, $exes ) = $check->( @ARG );

	my @results;
	foreach my $profile_batch ( @{ $self->profile_batches() } ) {
		push @results, $profile_batch->execute_task( $exes, $exes->tmp_dir() );
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
	state $check = compile( Invocant, Path, CathGemmaDiskExecutables );
	my ( $proto, $file, $exes ) = $check->( @ARG );

	return $proto->read_from_file( $file )->execute_task( $exes, $exes->tmp_dir() );
}

1;
