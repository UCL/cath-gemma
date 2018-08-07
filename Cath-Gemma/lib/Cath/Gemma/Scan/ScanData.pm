package Cath::Gemma::Scan::ScanData;

=head1 NAME

Cath::Gemma::Scan::ScanData - Represent the raw data from a single scan

=cut

use strict;
use warnings;

# Core
use Carp              qw/ confess                           /;
use English           qw/ -no_match_vars                    /;
use Sys::Hostname;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 2;

# Non-core (local)
use Type::Params        qw/ compile Invocant                  /;
use Log::Log4perl::Tiny qw/ :easy                    /;
use Types::Path::Tiny   qw/ Path                              /;
use Types::Standard     qw/ ArrayRef Int Num Object Str Tuple /;

# Cath::Gemma
use Cath::Gemma::Util;

=head2 scan_data

TODOCUMENT

=cut

has scan_data => (
	is  => 'ro',
	isa => ArrayRef[Tuple[Str, Str, Num]],
);

=head2 read_from_file

TODOCUMENT

=cut

sub read_from_file {
	state $check = compile( Invocant, Path );
	my ( $proto, $scan_data_file ) = $check->( @ARG );

	# Seems that there are times where the file reports to be missing
	# at this point in the code, but is on the file system when we check.
	#
	# Possible reasons:
	#  - the compute node doesn't have access to the shared area
	#  - there's a race condition that means the file isn't available straight away (eg lustre)
	#
	# I'm adding a loop here to avoid the second issue (we can't do much about the first)
	# https://github.com/UCL/cath-gemma/issues/17
	 
	my $tries = 5;
	while ( $tries-- > 0 ) {
		if ( ! -e $scan_data_file ) {
			WARN "Failed to find ScanData file '$scan_data_file'. Will wait a second then try again (count $retries) ...";
			sleep(1);
		}
		if ( $tries == 0 ) {
			my $host = hostname;
			my $df_sys = "/bin/df '$scan_data_file'";
			my $df_out = `$df_com`;
			confess "Failed to get ScanData file '$scan_data_file'\n"
				. "HOST: $host\n"
				. "Results of `$df_sys`:\n" . $df_out;
		}
	}

	if ( ! -s $scan_data_file ) {
		push @errors, "ScanData file $scan_data_file is empty";
	}

	my $scan_data_data = $scan_data_file->slurp()
		or confess "Unable to read non-empty ScanData file $scan_data_file";
	my @scan_data_lines = split( /\n/, $scan_data_data );
	foreach my $scan_data_line ( @scan_data_lines ) {
		$scan_data_line = [ split( /\s+/, $scan_data_line ) ];
	}

	return __PACKAGE__->new(
		scan_data => \@scan_data_lines,
	);
}

=head2 write_to_file

TODOCUMENT

=cut

sub write_to_file {
	state $check = compile( Object, Path );
	my ( $self, $output_file ) = $check->( @ARG );

	my $the_data = $self->scan_data();

	$output_file->spew(
		join(
			"\n",
			map { join( "\t", @$ARG ); } @$the_data
		) . "\n"
	);
}

=head2 parse_from_raw_compass_scan_output_lines

TODOCUMENT

=cut

sub parse_from_raw_compass_scan_output_lines {
	state $check = compile( Invocant, ArrayRef[Str], Int );
	my ( $proto, $compass_output_lines, $expected_num_results ) = $check->( @ARG );

	my $num_results = 0;

	my ( @outputs, $prev_id1, $prev_id2 );
	my $alignment_suffix = alignment_suffix();
	foreach my $compass_output_line ( @$compass_output_lines ) {
		if ( $compass_output_line =~ /Irregular format in database/ ) {
			confess 'Problem with COMPASS scan data : "' . $compass_output_line . '"';
		}
		if ( $compass_output_line =~ /^Ali1:\s+(\S+)\s+Ali2:\s+(\S+)/ ) {
			if ( defined( $prev_id1 ) || defined( $prev_id2 ) ) {
				confess "Argh:\n\"$compass_output_line\"\n$prev_id1\n$prev_id2  TODOCUMENT\n";
			}
			$prev_id1 = $1;
			$prev_id2 = $2;
			foreach my $prev_id ( \$prev_id1, \$prev_id2 ) {
				if ( $$prev_id =~ /^(.*\/)?(\w+)$alignment_suffix$/ ) {
					$$prev_id = $2;
				}
				else {
					confess "Argh $$prev_id  TODOCUMENT";
				}
			}
		}
		if ( $compass_output_line =~ /\bEvalue (.*)$/ ) {
			++$num_results;
			if ( $1 ne '** not found **' ) {
				if ( $compass_output_line =~ /\bEvalue = (\S+)$/ ) {
					push @outputs, [ $prev_id1, $prev_id2, $1 ];
				}
				else {
					confess "Argh TODOCUMENT";
				}
			}
			if ( ! defined( $prev_id1 ) || ! defined( $prev_id2 ) ) {
				confess "Argh TODOCUMENT";
			}
			$prev_id1 = undef;
			$prev_id2 = undef;
		}
	}

	if ( $num_results != $expected_num_results ) {
		confess "Something wrong whilst parsing COMPASS results: expected to get $expected_num_results results but found $num_results."
	}

	return __PACKAGE__->new(
		scan_data => \@outputs
	);
}


=head2 parse_from_raw_hhsearch_scan_output_lines

TODOCUMENT

=cut

sub parse_from_raw_hhsearch_scan_output_lines {
	state $check = compile( Invocant, ArrayRef[Str], ArrayRef[Str], ArrayRef[Str] );
	my ( $proto, $output_lines, $query_ids, $match_ids ) = $check->( @ARG );

	my %best_score_per_querymatch;

	my $really_bad_score = really_bad_score();
	my $alignment_suffix = alignment_suffix();
	my %query_lookup = map { ($_ => 1) } @$query_ids;
	my %match_lookup = map { ($_ => 1) } @$match_ids;

	# Query         1
	# Match_columns 52
	# No_of_seqs    1 out of 2
	# Neff          1
	# Searched_HMMs 2
	# Date          Fri May 18 18:52:41 2018
	# Command       /tmp/cath_gemma_exes_dir.0nFqYd81/hhsearch -i /cath/homes2/ucbcisi/git/cath-gemma/Cath-Gemma/t/data/1.20.5.200/profiles/1.hhconsensus.a3m -d /tmp/cath-gemma-util.FxeNsNpH/.n0de_37693cfc748049e45d87b8c7d8b9aacd.KG2eHKHjEJF.db 

	#  No Hit                             Prob E-value P-value  Score    SS Cols Query HMM  Template HMM
	#   1 2                               98.5 3.5E-15 1.7E-15   69.1   0.0   49    2-52      2-50  (50)
	#   2 3                               97.4 2.6E-11 1.3E-11   52.0   0.0   46    5-52      1-46  (46)
	#   3 3                                0.0       2    0.98    4.2   0.0    1    1-1       1-1   (46)
	#   4 2                                0.0       2       1    2.2   0.0    1    6-6       1-1   (50)

	my $line_count=0;
	my $total_lines = scalar @$output_lines;

	# search until we hit 'Query'
	# go through the hits

	my $current_query_id;
	my $scan_hits;
	LINE: while ( $line_count < $total_lines ) {
		my $line = $output_lines->[ $line_count++ ];
		if ( $line =~ /^Query\s+(\S+)/ ) {
			$current_query_id = $1;
		}
		if ( $current_query_id && $line =~ /^\s+No\s+Hit/ ) {
			$scan_hits = 1;
			next LINE;
		}
		if ( $scan_hits ) {
			$line =~ s/^\s+//;
			if ( ! $line ) {
				$current_query_id = undef;
				$scan_hits = 0;
				next LINE;
			}

			my @cols = split( /\s+/, $line );

			confess "expected 11 columns in hhsearch 'hit', got " . scalar( @cols ) . " columns (line: $line_count): '$line'"
				if scalar @cols != 11;

			my ($num, $match_id, $prob, $evalue, $pvalue, $score, $ss, $cols, $query_hmm, $template_hmm, $something)
				= @cols;
			
			my $key = join( "__", $current_query_id, $match_id );
			my $data = [ $current_query_id, $match_id, $evalue ];
			$best_score_per_querymatch{$key} //= $data;

			if ( $evalue < $best_score_per_querymatch{$key}->[2] ) {
				$best_score_per_querymatch{$key} = $data;
			}
		}
	}

	my $expected_num_results = scalar @$query_ids * scalar @$match_ids;
	my $num_results = scalar keys %best_score_per_querymatch;

	if ( $num_results != $expected_num_results ) {
		WARN "Something wrong whilst parsing HHSuite results: expected to get $expected_num_results results but found $num_results."
	}

	# sort by lowest evalue
	my @all_scan_data = sort { $a->[2] <=> $b->[2] } values %best_score_per_querymatch; 

	# Make sure we've got the full matrix of scores and that all ids found in the scan match expected

	my $c=0;
	my $debug_scan_lines = join( "", map { sprintf( "%4d| %s\n", ++$c, $_ ) } @$output_lines );

	my %query_match_lookup;
	for my $scandata ( @all_scan_data ) {
		my ($query_id, $match_id, $evalue) = @$scandata;
		confess "Found unexpected query id '$query_id' in scan data:\n$debug_scan_lines" unless exists $query_lookup{ $query_id };
		confess "Found unexpected match id '$match_id' in scan data:\n$debug_scan_lines" unless exists $match_lookup{ $match_id };
		$query_match_lookup{ $query_id } //= {};
		$query_match_lookup{ $query_id }->{ $match_id } = $evalue;
	}

	# figure out what we're missing
	my @missing_scan_data;
	my $count_reverse_hits = 0;
	my $count_max_hits = 0;
	for my $query_id ( @$query_ids ) {
		for my $match_id ( @$match_ids ) {
			if ( ! exists $query_match_lookup{ $query_id }->{ $match_id } ) {
				# if we have b->a then assume this is the same as a->b, otherwise use crap evalue as placeholder
				my $evalue;
				if ( exists $query_match_lookup{ $match_id } && $query_match_lookup{ $match_id }->{ $query_id } ) {
					$evalue = $query_match_lookup{ $match_id }->{ $query_id };
					$count_reverse_hits++;
				}
				else {
					$evalue = $really_bad_score;
					$count_max_hits++;
				}
				push @missing_scan_data, [ $query_id, $match_id, $evalue ];
			}
		}
	}

	WARN "Filling scan matrix with $count_reverse_hits rows of reverse hits and $count_max_hits rows of placeholder hits";
	push @all_scan_data, @missing_scan_data;

	return __PACKAGE__->new(
		scan_data => \@all_scan_data,
	);
}
1;
