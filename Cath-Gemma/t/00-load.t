#!perl

use Test::More tests => 1;

use FindBin;
use lib "$FindBin::Bin/../extlib/lib/perl5";

BEGIN {
    use_ok( 'Cath::Gemma' ) || print "Bail out!\n";
}

diag( "Testing Cath::Gemma $Cath::Gemma::VERSION, Perl $], $^X" );
