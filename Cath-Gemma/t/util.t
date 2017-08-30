use strict;
use warnings;

# Core
use FindBin;

use lib $FindBin::Bin . '/../extlib/lib/perl5';

use Test::More tests => 6;

use Cath::Gemma::Util;

is( evalue_window_ceiling( 1.2e-15 ), 1e-10, 'argh ceiling' );

is( evalue_window_floor  ( 1.2e-15 ), 1e-20, 'argh ceiling' );


is_deeply( [ unique_by_hashing( 0                ) ], [ 0    ] );
is_deeply( [ unique_by_hashing( 0, 0, 0          ) ], [ 0    ] );
is_deeply( [ unique_by_hashing( 1, 2             ) ], [ 1, 2 ] );
is_deeply( [ unique_by_hashing( 1, 2, 2, 1, 2, 1 ) ], [ 1, 2 ] );