use strict;
use warnings;

# Core
use English qw/ -no_match_vars /;
use FindBin;
use Storable qw/ freeze thaw /;

use lib $FindBin::Bin . '/../extlib/lib/perl5';

use Test::More tests => 1;

# Non-core (local)
use JSON::MaybeXS;
use Path::Tiny;

# my $bootstrap_tests = $ENV{ BOOTSTRAP_TESTS } // 0;
# my $test_basename   = path( $PROGRAM_NAME )->basename( '.t' );
my $data_dir        = path( 'data' );

use_ok( 'Cath::Gemma::Compute::WorkBatch' );

# done_testing();
