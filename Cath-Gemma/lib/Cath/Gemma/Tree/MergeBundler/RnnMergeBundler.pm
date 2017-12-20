package Cath::Gemma::Tree::MergeBundler::RnnMergeBundler;

use strict;
use warnings;

# Core
# use Carp               qw/ confess                 /;
# use List::Util         qw/ min                     /;
# use v5.10;
use English            qw/ -no_match_vars          /;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# # Non-core (local)
# use Log::Log4perl::Tiny qw/ :easy /;
# use Object::Util;
# # use Path::Tiny;
# # use Type::Params       qw/ compile Invocant        /;
# # use Types::Path::Tiny  qw/ Path                    /;
# # use Types::Standard    qw/ ArrayRef Int Object Str /;
# use Types::Standard    qw/ ArrayRef Object Optional Str /;

# Cath::Gemma
# use Cath::Gemma::Disk::ProfileDirSet;
# use Cath::Gemma::Tool::CompassProfileBuilder;

# use Cath::Gemma::Executor::LocalExecutor;
# use Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder;
# use Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder;
# use Cath::Gemma::TreeBuilder::NaiveMeanOfBestTreeBuilder;
# use Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder;
# use Cath::Gemma::TreeBuilder::PureTreeBuilder;
# use Cath::Gemma::TreeBuilder::WindowedTreeBuilder;
# use Cath::Gemma::Types qw/
# 	CathGemmaCompassProfileType
# 	CathGemmaDiskGemmaDirSet
# 	CathGemmaDiskProfileDirSet
# 	CathGemmaDiskTreeDirSet
# 	CathGemmaNodeOrdering
# 	CathGemmaTreeBuilder
# /;
# # CathGemmaExecutor
# # use Cath::Gemma::Util;

with ( 'Cath::Gemma::Tree::MergeBundler' );

# =head2 tree_builder

# TODOCUMENT

# =cut

# has tree_builder => (
# 	is          => 'ro',
# 	isa         => CathGemmaTreeBuilder,
# 	required    => 1,
# );

# =head2 id

# TODOCUMENT

# =cut

# sub id {
# 	my $self = shift;
# 	return generic_id_of_clusters( [
# 		$self->tree_builder()->name(),
# 		$self->compass_profile_build_type(),
# 		$self->clusts_ordering(),
# 		map { id_of_starting_clusters( $ARG ) } @{ $self->starting_cluster_lists() },
# 	] );
# }

=head2 get_execution_bundle

TODOCUMENT

=cut

sub get_execution_bundle {

}

=head2 get_ordered_merges

TODOCUMENT

=cut

sub get_ordered_merges {

}

1;
