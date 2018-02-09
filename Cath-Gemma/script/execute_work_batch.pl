#!/usr/bin/env perl

use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use Cwd;
use English             qw/ -no_match_vars /;
use FindBin;
use Sys::Hostname; # ***** TEMPORARY *****
use v5.10;

# Find non-core external lib directory using FindBin
use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;
use Type::Params        qw/ compile        /;
use Types::Path::Tiny   qw/ Path           /;

# Find Gemma lib directory using FindBin (and tidy using Path::Tiny)
use lib path( "$FindBin::Bin/../lib" )->realpath()->stringify();

# Cath::Gemma
use Cath::Gemma::Compute::WorkBatch;
use Cath::Gemma::Disk::Executables;
use Cath::Gemma::Executor::SpawnExecutor;
use TimeSecondsToJson;

Log::Log4perl->easy_init( {
	level => $DEBUG,
} );

WARN "Starting $PROGRAM_NAME on ".hostname;

state $check = compile( Path );
my ( $batch_file ) = $check->( @ARGV );

if ( ! -s $batch_file ) {
	confess "No non-empty work batch file \"$batch_file\"";
}

INFO "Processing batch file $batch_file";

my $sge_submission_dir = Path::Tiny->tempdir(
	CLEANUP => 0,
	DIR     => $ENV{ SGE_STDERR_PATH }
	           ? path( $ENV{ SGE_STDERR_PATH } )->realpath()->parent()
	           : path( cwd() ),
);
INFO __PACKAGE__ . ' has deduced this is genuinely running on SGE and will launch child jobs with an SpawnExecutor (running in ' . $sge_submission_dir . ')';
my $result = Cath::Gemma::Compute::WorkBatch->execute_from_file(
	$batch_file,
	Cath::Gemma::Disk::Executables->new(),
	Cath::Gemma::Executor::SpawnExecutor->new( submission_dir => $sge_submission_dir ),
);

# Consider using Tree::Simple::VisitorFactory (or Data::Traverse or Data::Visitor?) if this breaks
foreach my $result_level1 ( @$result ) {
	foreach my $result_level2 ( @$result_level1 ) {
		if ( ref( $result_level2 ) eq 'HASH' && defined( $result_level2->{ 'result' } ) ) {
			delete $result_level2->{ 'result' };
		}
	}
}

use Data::Dumper;
warn Dumper( {
	execute_work_batch__result => $result,
} ). ' ';

use JSON::MaybeXS;
my $json = JSON::MaybeXS->new( convert_blessed => 1 );
my $results_file = $batch_file->parent()->child( $batch_file->basename() . '.results' );
$results_file->spew( $json->encode( $result ) );

INFO "Completed processing batch file $batch_file";
