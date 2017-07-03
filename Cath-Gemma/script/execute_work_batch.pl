#!/usr/bin/env perl

use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use English             qw/ -no_match_vars /;
use FindBin;
use Sys::Hostname; # ***** TEMPORARY *****

use v5.10;

use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core (local)
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;
use Type::Params        qw/ compile        /;
use Types::Path::Tiny   qw/ Path           /;

use lib "$FindBin::Bin/../lib";

# Cath
use Cath::Gemma::Compute::WorkBatch;
use Cath::Gemma::Disk::Executables;

WARN "Starting $PROGRAM_NAME on ".hostname;

state $check = compile( Path );
my ( $batch_file ) = $check->( @ARGV );

if ( ! -s $batch_file ) {
	confess "No non-empty work batch file \"$batch_file\"";
}

INFO "Processing batch file $batch_file";

my $exes = Cath::Gemma::Disk::Executables->new()
	or confess "Unable to create new Cath::Gemma::Disk::Executables";;

my $result = Cath::Gemma::Compute::WorkBatch->execute_from_file(
	$batch_file,
	$exes,
);

# use JSON::MaybeXS;
# my $json = JSON::MaybeXS->new( convert_blessed => 1 );
# say $json->encode( $result );
