#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

package fasta;

use strict;


sub count_headers_in_faa_file
{

	my $faa_file = shift; 

	#DEBUG could return with error instead
	if (! -e $faa_file) 
		{ die "ERROR file not found: $faa_file!\n"; }

	my $seq_count = 0;

	# count sequences in cluster and count instances of each functional term
	# also denote representative sequences (the hq-annotated ones)
	open my $FAA, "<$faa_file";
	while (<$FAA>) { if (/^\>/) { $seq_count++; } }		
	close $FAA;
	
	return $seq_count;

}


sub load_headers_from_faa_file
{

	my $faa_file = shift; 
	
	#DEBUG could return with error instead
	if (! -e $faa_file) 
		{ die "ERROR file not found: $faa_file!\n"; }

	my $faa_header;
	my @faa_headers = ();
	
	# count sequences in cluster and count instances of each functional term
	# also denote representative sequences (the hq-annotated ones)
	open my $FAA, "<$faa_file";
	while (<$FAA>)		
		{ 
		if (/^\>/) 
			{ 
			# remove ">"
			chomp; $faa_header = substr $_, 1;
			push @faa_headers, $faa_header;  
			} 
		}		
	close $FAA;
	
	my $seq_count = @faa_headers;
		
	return (\@faa_headers, $seq_count);

}


#NOTE relevant is the first column of the header when split by whitespace!
sub filter_mfasta_file_by_seqids
{

	my ($inf, $ouf, $sid_list_ref, $keep_or_omit) = @_;
	
	# default is "omit"
	$keep_or_omit = ($keep_or_omit eq "keep");
	
	my (@cols, $header, $seq_id, $seq, $total, $filtered);

	my %filter_seq_ids = map { $_ => 1 } @{$sid_list_ref};
	
	# print only seqs that have one of the seq_ids (">" does not count!)
	open my $INF, "<$inf" || die "cannot open $inf for reading ($!)";
	open my $OUF, ">$ouf" || die "cannot open $ouf for writing ($!)";
	while (<$INF>)
		{
		
		chomp;
		
		if (/^\>/)
			{ 
			$header = $_; 
			@cols = split /\s+/, $header; 
			$seq_id = substr $cols[0], 1; 
			$total++; 
			}
		
		else 
			{ 
			$seq = $_; 
			if (exists $filter_seq_ids{$seq_id} == $keep_or_omit)
				{ print $OUF "$header\n$seq\n"; } 
			else { $filtered++; } 
			}
		
		}
	close $OUF;
	close $INF;

}


#EOF
1;
