#!/usr/bin/env perl

use strict;
use warnings;

# Core
use Carp    qw/ confess        /;
use English qw/ -no_match_vars /;
use FindBin;
use Getopt::Long;

# Find non-core external lib directory using FindBin
use lib "$FindBin::Bin/../extlib/lib/perl5";

# Non-core
# use DDP colored => 1;
use DBI;
use Log::Log4perl::Tiny qw/ :easy /;
use Path::Tiny;

# Database connection details
my $dsn        = "dbi:Oracle:host=odb.cs.ucl.ac.uk;sid=cathora1";
my $user       = "orengoreader";
my $pass       = "orengoreader";
my $tablespace = 'gene3d_16';

my $cath_node_id;
my $suffix = ".$tablespace.uniprot_accs__ids__seqs";
my $use_full_sequence = 0;

my $USAGE = <<"_USAGE";

$PROGRAM_NAME --cath=[<node_id>|ALL] [--suffix=<string>] [--full_sequence]

Queries the Gene3D database and writes sequences to file (one file per CATH
superfamily).

  --cath       <node_id>   Specify the root cath node (eg. '1.10' or 'ALL')

  --suffix     <string>    Specify the suffix for output files
                           (default: '$suffix')

  --tablespace <string>    Gene3D tablespace to use for queries
                           (default: '$tablespace')

  --full_sequence          Output the full UniProtKB sequence (rather than just
                           the CATH domain sequence)

_USAGE

die $USAGE unless @ARGV;

GetOptions(
	'cath|c=s' => \$cath_node_id,
	'suffix|s=s' => \$suffix,
	'full_sequence|f' => \$use_full_sequence,
	'tablespace|t=s' => \$tablespace,
);

# Grab command line options
die $USAGE if scalar( @ARGV ) > 0;

$cath_node_id = $cath_node_id eq 'ALL' ? '' : $cath_node_id;

die "! Error: string '$tablespace' does not look like a valid tablespace"
	unless $tablespace =~ /^[a-zA-Z0-9_]+$/;

# Check the CATH node is valid and convert it into a suitable 'LIKE' string
if ( $cath_node_id !~ /^(\d+(\.\d+){0,3})?$/ ) {
	die "Not a valid CATH node : \"$cath_node_id\"\n";
}
my $cath_node_id_like_str =
	$cath_node_id
	 . ( split( /\./, $cath_node_id ) < 4 ? '.' : '' )
	 . '%';

# Connect to the database
my $dbh = DBI->connect( $dsn, $user, $pass, { LongReadLen => 100000000 })
	or die "! Error: failed to connect to database: $OS_ERROR";

# Grab the superfamily IDs within the specified CATH node
INFO "Getting list of superfamilies within $cath_node_id from the database";
my $superfamily_ids_sql = <<"_SQL";
SELECT
  SUPERFAMILY
FROM
  $tablespace.CATH_DOMAIN_PREDICTIONS
WHERE
  SUPERFAMILY LIKE ?
GROUP BY
  SUPERFAMILY
ORDER BY
  SUPERFAMILY
_SQL
my $superfamily_ids_sth = $dbh->prepare( $superfamily_ids_sql )
	or die "! Error: failed to prepare statement: " . $dbh->err;
$superfamily_ids_sth->execute( $cath_node_id_like_str )
	or die "! Error: failed to execute statement: " . $superfamily_ids_sth->err;
my @superfamily_ids;
while ( my $row = $superfamily_ids_sth->fetchrow_hashref ) {
	push @superfamily_ids, $row->{ SUPERFAMILY };
}

# NOTE [IS: 2018/03/01]
# the _EXTRA tables contain only the redundant sequences
# so we need to search both. Ideally we could do this via
# a UNION, however aa_sequence is stored as CLOB and you
# can't do a UNION on CLOBs (apparently)

my $sequences_extra_for_superfamily_sql = <<"_SQL";
SELECT
  u.accession                         AS uniprot_acc,
  c.sequence_md5 || '/' || c.resolved AS domain_id,
  s.aa_sequence                       AS sequence
FROM
  $tablespace.CATH_DOMAIN_PREDICTIONS_EXTRA c
INNER JOIN
  $tablespace.SEQUENCES_EXTRA         s ON c.sequence_md5 = s.sequence_md5
INNER JOIN
  $tablespace.UNIPROT_PRIM_ACC        u ON c.sequence_md5 = u.sequence_md5
WHERE
  c.superfamily = ?
  AND
  s.source = 'uniref90'
  AND
  c.independent_evalue < 0.001
_SQL

my $sequences_extra_for_superfamily_sth = $dbh->prepare( $sequences_extra_for_superfamily_sql )
		or die "! Error: failed to prepare statement: " . $dbh->err;

my $sequences_for_superfamily_sql = <<"_SQL";
SELECT
  u.accession                         AS uniprot_acc,
  c.sequence_md5 || '/' || c.resolved AS domain_id,
  s.aa_sequence                       AS sequence
FROM
  $tablespace.CATH_DOMAIN_PREDICTIONS c
INNER JOIN
  $tablespace.SEQUENCES               s ON c.sequence_md5 = s.sequence_md5
INNER JOIN
  $tablespace.UNIPROT_PRIM_ACC        u ON c.sequence_md5 = u.sequence_md5
WHERE
  c.superfamily = ?
  AND
  c.independent_evalue < 0.001
_SQL

my $sequences_for_superfamily_sth = $dbh->prepare( $sequences_for_superfamily_sql )
		or die "! Error: failed to prepare statement: " . $dbh->err;

# Loop over the superfamily IDs
foreach my $superfamily_id ( @superfamily_ids ) {
	INFO "Getting information from the database for superfamily \"$superfamily_id\"";
	# Grab the sequences for the superfamily

	my @results;

	$sequences_for_superfamily_sth->execute( $superfamily_id )
		or die "! Error: failed to execute statement: " . $sequences_for_superfamily_sth->err;
	while ( my $row = $sequences_for_superfamily_sth->fetchrow_hashref() ) {
		push @results, get_result_from_row( $row );
	}

  $sequences_extra_for_superfamily_sth->execute( $superfamily_id )
    or die "! Error: failed to execute statement: " . $sequences_extra_for_superfamily_sth->err;
  while ( my $row = $sequences_extra_for_superfamily_sth->fetchrow_hashref() ) {
    push @results, get_result_from_row( $row );
  }

	# Write the results to a file
	path( $superfamily_id . $suffix )->spew(
		join (
			'',
			map {
				join( "\t", @$ARG ) . "\n";
			} @results
		)
	);

}

sub get_result_from_row {
	my $row = shift;

  my $domain_id = $row->{ DOMAIN_ID };
  $domain_id =~ s/,/_/g; # / Convert commas to underscores

	$domain_id =~ m{/([0-9\-_]+)$}g
		or die "! Error: failed to parse segment information from domain id '$domain_id'";

	my $segment_info = $1;
	my @segments = map {
			my ($a, $z) = split(/\-/, $_);
			{ start => $a, end => $z, length => $z - $a + 1 };
		}
		split(/_/, $segment_info);

	my $full_sequence = $row->{ SEQUENCE };
	my $domain_sequence = '';
	my $domain_length = 0;
	map { $domain_length += $_->{length} } @segments;

	for my $seg ( @segments ) {
		$domain_sequence .= substr( $full_sequence, $seg->{start} - 1, $seg->{length} );
	}

	if ( $domain_length != length( $domain_sequence ) ) {
		die "! Error: expected domain length $domain_length from segment info '$segment_info', actually got " . length($domain_sequence) . " (seq: $domain_sequence)";
	}

	return [
      $row->{ UNIPROT_ACC },
      $domain_id,
      $use_full_sequence ? $full_sequence : $domain_sequence,
  ];
}
