package Cath::Gemma::Executor::HpcExecutor;

=head1 NAME

Cath::Gemma::Executor::HpcExecutor - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars /;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Types::Path::Tiny qw/ Path           /;
use Log::Log4perl::Tiny qw/ :easy        /; # ***** TEMPORARY ******

# Cath
use Cath::Gemma::Compute::WorkBatcher;

with ( 'Cath::Gemma::Executor' );

=head2 submission_dir

=cut

has submission_dir => (
	is       => 'ro',
	isa      => Path,
	required => 1,
);

=head2 execute

=cut

sub execute {
	my ( $self, $build_tasks, $scan_tasks ) = @ARG;

	my $work_batcher = Cath::Gemma::Compute::WorkBatcher->new();

	foreach my $build_task ( @$build_tasks ) {
		$work_batcher->add_profile_build_work( $build_task );
	}
	ERROR 'Should do $work_batcher->add_profile_scan_work( ... ) but it isn\'t implemented';
	# foreach my $scan_task ( @$scan_tasks ) {
	# 	$work_batcher->add_profile_scan_work( $scan_task );
	# }

	$work_batcher->submit_to_compute_cluster( $self->submission_dir()->realpath() );
}

1;