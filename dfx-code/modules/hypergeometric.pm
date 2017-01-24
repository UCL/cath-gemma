#! /usr/bin/perl -w

# *** This code was last modified by the author, Robert Rentzsch   ***
# *** (robertrentzsch@gmail.com), in 2013; please get in touch if  ***
# *** you have questions, suggestions, or want to use (parts of)   ***
# *** this code, or the produced output, in your own work. Thanks! ***

package hypergeometric;

use strict;

use FindBin qw ($Bin);


#NOTE this code's been ripped from the interweb; only this comment block's been written by me, RR
#NOTE source of code: http://www.perlmonks.org/?node_id=466599
#NOTE make sure to also read all the comments, they're important depending on what you want to do
#NOTE e.g., often you want the probability of x or more successful selections, instead of exactly x
#NOTE see also: http://en.wikipedia.org/wiki/Hypergeometric_distribution
#NOTE read this for the overall logic and how to, e.g., Bonferroni correct:
#NOTE http://www.ncbi.nlm.nih.gov/pubmed/15297299
#NOTE finally, for sanity checking things, enter your specific test values here and compare the result:
#NOTE http://stattrek.com/online-calculator/hypergeometric.aspx


my @logfact;


#NOTE you have to call this once initially
sub init
{

	#DEBUG added hashing; this saves a few seconds per run
	my $logfact_hash = "$Bin/../modules/logfact.hypergeometric.tmp";
	
	if (! -e $logfact_hash)
		{
		foreach (0..1000000)
			{
			push @logfact, logfact($_);
			}
		print "storing hypergeometric distribution logfact hash to reuse later...\n";
		common::write_list(\@logfact, $logfact_hash);		
		}
	else
		{
		@logfact = @{common::load_list($logfact_hash)};
		}

}


#NOTE not called from outside
sub gammln 
{
  
	my $xx = shift;
	my @cof = (76.18009172947146, -86.50532032941677,
			   24.01409824083091, -1.231739572450155,
			   0.12086509738661e-2, -0.5395239384953e-5);
	my $y = my $x = $xx;
	my $tmp = $x + 5.5;
	$tmp -= ($x + .5) * log($tmp);
	my $ser = 1.000000000190015;
	for my $j (0..5) { $ser += $cof[$j]/++$y; }
	return -$tmp + log(2.5066282746310005*$ser/$x);

}


#NOTE not called from outside
sub logfact 
{

	return gammln(shift(@_) + 1.0);

}


#NOTE the actual function you call
sub hypergeometric 
{
	
	# There are m "bad" and n "good" balls in an urn.
	# Pick N of them. The probability of i or more successful selections:
	# (m!n!N!(m+n-N)!)/(i!(n-i)!(m+i-N)!(N-i)!(m+n)!)
	my ($n, $m, $N, $i) = @_;
	
	#print "DEBUG $n	$m	$N	$i\n";

	my $loghyp1 = $logfact[ $m ] + $logfact[ $n ]
				+ $logfact[ $N ] + $logfact[ $m + $n - $N ];
	my $loghyp2 = $logfact[ $i ] + $logfact[ $n - $i ] 
				+ $logfact[ $m + $i - $N ] + $logfact[ $N - $i ] 
				+ $logfact[ $m + $n ];

	return exp($loghyp1 - $loghyp2);

}


#EOF
1;
