#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;

use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy                   /;
use Path::Tiny;

use lib path( "$FindBin::Bin/../lib" )->realpath()->stringify();

# Cath
use Cath::Gemma::Disk::GemmaDirSet;
use Cath::Gemma::Executor::LocalExecutor; # ***** TEMPORARY (use factory) *****
use Cath::Gemma::TreeBuilder::WindowedTreeBuilder;

use Type::Tiny;
$Error::TypeTiny::StackTrace = 1;

my $data_base_dir = path( $FindBin::Bin )->child( '../t/data/3.30.70.1470/' )->realpath();
my $gemma_dir_set = Cath::Gemma::Disk::GemmaDirSet->make_gemma_dir_set_of_base_dir( $data_base_dir );

my $executor = Cath::Gemma::Executor::LocalExecutor->new();

my $tree_builder = Cath::Gemma::TreeBuilder::WindowedTreeBuilder->new();
my $merge_list = $tree_builder->build_tree(
	$executor,
	$gemma_dir_set->get_starting_clusters(),
	$gemma_dir_set,
);
warn $merge_list->to_tracefile_string();

__END__

=head1 NAME

build_tree.pl - Build a tree - for testing/profiling etc

=head1 SYNOPSIS

build_tree.pl

=head1 DESCRIPTION

Build a tree - for testing/profiling etc

=cut
