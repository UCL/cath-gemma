#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;

# Core (test)
use Test::More tests => 2;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use JSON::MaybeXS;
use Path::Tiny;
use Time::Seconds;

use_ok( 'TimeSecondsToJson' );

subtest 'writes_to_json' => sub {
	my $result = {
		'aln_duration'               => bless( do{\(my $o = '25.536213')}, 'Time::Seconds' ),
		'aln_file_already_present'   => 0,
		'aln_filename'               => bless( [
			'aln_dir/job.faa',
			'aln_dir/job.faa'
		], 'Path::Tiny' ),
		'aln_wrapper_duration'       => bless( do{\(my $o = '0.031884')}, 'Time::Seconds' ),
		'mean_seq_length'            => '285.683908045977',
		'num_sequences'              => 174,
		'prof_duration'              => bless( do{\(my $o = '0.119675')}, 'Time::Seconds' ),
		'prof_file_already_present'  => 0,
		'prof_filename'              => bless( [
			'prof_dir/job.mk_compass_db.prof',
			'prof_dir/job.mk_compass_db.prof',
			'',
			'prof_dir/',
			'job.mk_compass_db.prof'
		], 'Path::Tiny' ),
		'prof_wrapper_duration'     => bless( do{\(my $o = '0.006472')}, 'Time::Seconds' ),
	};

	like(
		JSON::MaybeXS->new( convert_blessed => 1 )->encode( $result ),
		qr/"25.536213s"/,
		'When encoding JSON from a data structure containing a Time::Seconds, it gets converted to a sensible string'
	);
}