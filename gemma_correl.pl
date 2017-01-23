#!/usr/bin/env perl

use strict;
use warnings;

use Carp                       qw/ confess                              /;
use Data::Dumper;
use English                    qw/ -no_match_vars                       /;
use feature                    qw/ say                                  /;
use Path::Class                qw/ dir file                             /;

# use Getopt::Long;
# use IPC::Run3;
use List::Util                 qw/ max maxstr min minstr                /;
# use Moose;
# use MooseX::Params::Validate;
use MooseX::Types::Path::Class qw/ Dir File                             /;
# use Params::Util               qw/_INSTANCE _ARRAY _ARRAY0 _HASH _HASH0 /;


my $root_dir                         = dir( 'GeMMA_folders_and_datasets', 'v4.1_dataset', '2.20.100.10' );
my $all_singletons_blast_results_dir = $root_dir->subdir( 'all_singletons_blast_results' );
my $singleton_mapping_file           = $root_dir->file  ( 'all_singletons.mapping.txt'   );
my $singleton_seqs_file              = $root_dir->file  ( 'all_singletons.fa'            );
my $singleton_seqs_root_dir          = $root_dir->subdir( 'starting-clusters'            );

my %gemma_id_of_md5id;
my @mapping_lines = $singleton_mapping_file->slurp();
while (chomp(@mapping_lines)) {}
foreach my $mapping_line ( @mapping_lines ) {
	my @line_parts = split ( /\s+/, $mapping_line );
	$gemma_id_of_md5id{ $line_parts[ 1 ] } = $line_parts[ 0 ];
}


my %results_of_ltid_gtid;
while ( my $blast_result_base = $all_singletons_blast_results_dir->next ) {
	if ( $blast_result_base eq '.' || $blast_result_base eq '..' ) {
		next;
	}

	die $blast_result_base . ' ';
	my $blast_result_file = $blast_result_base->file( $blast_result_base );

	my @blast_result_lines = $blast_result_file->slurp();
	while ( chomp ( @blast_result_lines ) ) {}
	foreach my $blast_result_line ( @blast_result_lines ) {
		my @blast_results_line_parts = split ( /\s+/, $blast_result_line );

		my ($id1, $id2, $seq_id, $aligned_length, $length1, $length2) = @blast_results_line_parts;

		if ( $id1 eq $id2 ) {
			next;
		}

		my $first_id            = min( $id1, $id2 );
		my $second_id           = max( $id1, $id2 );
		my $overlap_over_longer = 100.0 * $aligned_length / max( $length1, $length2 );

		$data->{$first_id}->{$second_id} = [ undef, $seq_id, $overlap_over_longer ];
	}
	confess Dumper( \%results_of_ltid_gtid ) . ' ';
}


# while ()
# warn Dumper( \%results_of_ltid_gtid );

