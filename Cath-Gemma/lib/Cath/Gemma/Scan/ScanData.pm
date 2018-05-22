package Cath::Gemma::Scan::ScanData;

=head1 NAME

Cath::Gemma::Scan::ScanData - Represent the raw data from a single scan

=cut

use strict;
use warnings;

# Core
use Carp              qw/ confess                           /;
use English           qw/ -no_match_vars                    /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

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

	if ( ! -e $scan_data_file ) {
		confess "No such ScanData file $scan_data_file exists";
	}
	if ( ! -s $scan_data_file ) {
		confess "ScanData file $scan_data_file is empty";
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
	state $check = compile( Invocant, ArrayRef[Str], Int );
	my ( $proto, $output_lines, $expected_num_results ) = $check->( @ARG );

	my %best_score_per_match;
	my $alignment_suffix = alignment_suffix();

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
	my $query_id;
	while ( $line_count < $total_lines ) {
		my $line = $output_lines->[ $line_count++ ];
		if ( $line =~ /^Query\s+(\S+)/ ) {
			$query_id = $1;
		}
		last if $line =~ /^\s+No\s+Hit/;	
	}
	while ( $line_count < $total_lines ) {
		my $line = $output_lines->[ $line_count++ ];
		$line =~ s/^\s+//;
		next unless $line;
		my @cols = split( /\s+/, $line );

		confess "expected 11 columns, got $#cols columns (line: $line_count): '$line'"
			if scalar @cols != 11;

		my ($num, $match_id, $prob, $evalue, $pvalue, $score, $ss, $cols, $query_hmm, $template_hmm, $something)
			= @cols;
		
		my $data = [ $query_id, $match_id, $evalue ];
		$best_score_per_match{$match_id} //= $data;

		if ( $evalue < $best_score_per_match{$match_id}->[2] ) {
			$best_score_per_match{$match_id} = $data;
		}
	}

	my $num_results = scalar keys %best_score_per_match;

	if ( $num_results != $expected_num_results ) {
		WARN "Something wrong whilst parsing HHSuite results: expected to get $expected_num_results results but found $num_results."
	}

	# sort by lowest evalue
	my @outputs = sort { $a->[2] <=> $b->[2] } values %best_score_per_match; 
	return __PACKAGE__->new(
		scan_data => \@outputs
	);
}
1;
