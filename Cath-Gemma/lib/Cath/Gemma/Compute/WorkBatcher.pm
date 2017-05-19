package Cath::Gemma::Compute::WorkBatcher;

=head1 NAME

Cath::Gemma::Compute::WorkBatcher - TODOCUMENT

=cut

use strict;
use warnings;

# # Core
# use English            qw/ -no_match_vars               /;
# use v5.10;

# # Moo
# use Moo;
# use strictures 1;

# # Non-core (local)
# use Path::Tiny;
# use Type::Params       qw/ compile                      /;
# use Types::Standard    qw/ Bool Num Object Optional Str /;

# # Cath
# use Cath::Gemma::Types qw/ CathGemmaMerge               /;
# use Cath::Gemma::Util;

=head2 profile_batch_size

=cut

has profile_batch_size => (
	is      => 'rwp',
	isa     => Int,
	default => 10,
);

=head2 profile_batches

=cut

has profile_batches => (
	is  => 'rwp',
	isa => ArrayRef[WorkBatch],
);

=head2 add_profile_build_work

=cut

sub add_profile_build_work {
	state $check = compile( Object, CathGemmaComputeProfileBuildTask );
	my ( $self, $profile_task ) = $check->( @ARG );

	my $profile_batches = $self->profile_batches();

	my $num_profiles_in_new_task = $profile_task->count();

	my $num_available_profiles_in_last_batch =
		( scalar( @$profile_batches ) > 0 )
		? $num_profiles_in_new_task - $profile_batches->[ scalar( @$profile_batches ) ]->num_profiles()
		: 0;

	# $num_profiles_in_new_task;
}

1;
