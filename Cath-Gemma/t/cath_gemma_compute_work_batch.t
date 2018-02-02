#!/usr/bin/env perl

use strict;
use warnings;

# Core
use English qw/ -no_match_vars /;
use FindBin;
use Storable qw/ freeze thaw /;

# Core (test)
use Test::More tests => 1;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use JSON::MaybeXS;
use Path::Tiny;

# my $bootstrap_tests = $ENV{ BOOTSTRAP_TESTS } // 0;
# my $test_basename   = path( $PROGRAM_NAME )->basename( '.t' );
my $data_dir        = path( 'data' );

BEGIN{ use_ok( 'Cath::Gemma::Compute::WorkBatch' ) }

# done_testing();
