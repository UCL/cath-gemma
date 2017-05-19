package Cath::Gemma::Compute::ProfileBuildTask;

use strict;
use warnings;

# Core
# use English qw/ -no_match_vars /;
# use v5.10;

# Moo
use Moo;
use strictures 1;

# # Non-core (local)
use Path::Tiny;
use Types::Path::Tiny qw/ Path         /;
use Types::Standard   qw/ ArrayRef Str /;

=head2 starting_cluster_lists

=cut

has starting_cluster_lists => (
	is => 'ro',
	isa => ArrayRef[ArrayRef[Str]],
);

=head2 starting_clusters_dir

=cut

has starting_clusters_dir => (
	is => 'ro',
	isa => Path,
);

=head2 alignment_output_dir

=cut

has alignment_output_dir => (
	is => 'ro',
	isa => Path,
);

=head2 profile_dir

=cut

has profile_dir => (
	is => 'ro',
	isa => Path,
);

1;
