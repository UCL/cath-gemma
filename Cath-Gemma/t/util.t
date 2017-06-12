use strict;
use warnings;

# Core
use FindBin;

use lib $FindBin::Bin . '/../extlib/lib/perl5';

use Test::More tests => 2;

use Cath::Gemma::Util;

is( evalue_window_ceiling( 1.2e-15 ), 1e-10, 'argh ceiling' );

is( evalue_window_floor  ( 1.2e-15 ), 1e-20, 'argh ceiling' );
