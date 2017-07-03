#!/usr/bin/env perl

# perl -I extlib/lib/perl5 get_ec_codes_by_starting_cluster.pl

# strict + warnings
use strict;
use warnings;

# Core
use English         qw/ -no_match_vars    /;
use Scalar::Util    qw/ looks_like_number /;

# Non-core
use JSON::MaybeXS;
use List::MoreUtils qw/ natatime          /;
use Log::Log4perl   qw/ :easy             /;
use Path::Tiny;
use Sort::Versions;

# Cath
use Cath::Schema::Biomap;

# Params
my $oracle_db_in_batch_size    = 1000;
my $biomap_db_str              = 'V4_0_0';
my $starting_clusters_root_dir = path( '/cath/people2/ucbctnl/GeMMA/v4_0_0/starting_clusters' );
my @superfamilies              = (
	'3.40.10.10',   #  10 starting clusters, enzyme_sfs_with_catalytic_doms
	# '1.10.150.120', #  45 starting clusters
	# '3.20.20.20',   #  63 starting clusters, enzyme_sfs_with_catalytic_doms
	# '3.20.20.110',  # 108 starting clusters, enzyme_sfs_with_catalytic_doms
	# '3.20.20.120',  # 614 starting clusters, enzyme_sfs_with_catalytic_doms
);


WARN 'About to attempt to connect to Biomap DB ' . $biomap_db_str;
my $db = Cath::Schema::Biomap->connect_by_version( $biomap_db_str );

process_superfamilies( $db, \@superfamilies );

sub process_superfamilies {
	my $db            = shift;
	my $superfamilies = shift;

	foreach my $superfamily ( @superfamilies ) {
		my $starting_clusters_dir = $starting_clusters_root_dir->child( $superfamily );

		my $ec_codes_of_starting_clusters = get_ec_codes_of_starting_clusters_with_alignments_in_dir(
			$starting_clusters_dir,
			$db
		);

		# Spew the data structure out to a JSON file
		my $out_json_file = path( $superfamily . '.ec_codes_of_starting_clusters.json' );
		INFO "Writing results to $out_json_file";
		my $json = JSON::MaybeXS->new( pretty => 1 );
		$out_json_file->spew( $json->encode( $ec_codes_of_starting_clusters ) );

	}

	INFO "All done";
}

=head2 get_ec_codes_of_starting_clusters_with_alignments_in_dir

=cut

sub get_ec_codes_of_starting_clusters_with_alignments_in_dir {
	my $starting_cluster_aln_dir = shift;
	my $db                       = shift;

	return { starting_clusters => [
		map {
			my $starting_cluster_aln_file = $ARG;
			my $sc_basename               = $starting_cluster_aln_file->basename('.faa');
			INFO 'Getting EC codes for starting cluster in file ' . $sc_basename;

			if ( looks_like_number( $sc_basename ) ) {
				$sc_basename += 0;
			}

			{
				cluster_name => $sc_basename,
				ec_codes     => get_ec_codes_of_starting_cluster_alignment( $starting_cluster_aln_file, $db ),
			};
		} sort {
			versioncmp( $a, $b );
		} grep {
			$ARG->is_file();
		} $starting_cluster_aln_dir->children()
	] };
}

=head2 get_ec_codes_of_starting_cluster_alignment

=cut

sub get_ec_codes_of_starting_cluster_alignment {
	my $starting_cluster_aln_file = shift;
	my $db                        = shift;

	my @alignment_lines = split( /\n+/, $starting_cluster_aln_file->slurp() );
	while ( chomp( @alignment_lines ) ) {};
	my @header_lines = grep { /^>/ } @alignment_lines;
	map { s/^>//g } @header_lines;

	my @funfam_to_ec_results = $db->resultset('FunfamToEc')->search(
		{
			# Batch up because Oracle doesn't like IN ( ... ) having > 1000 entries
			-or => [
				map {
					{ member_id => { IN => $ARG } };
				} batch_into_n( $oracle_db_in_batch_size, @header_lines )
			],
		},
		{
			select => 'ec_code',
			as     => 'ec_code',
		}
	)->all();

	my %ec_codes;
	foreach my $result ( @funfam_to_ec_results ) {
		my $ec_code = $result->get_column( 'ec_code' );
		$ec_codes{ $ec_code }++;
	}

	return \%ec_codes;
}

=head2 batch_into_n

A convenience wrapper for List::MoreUtils' natatime that returns back an
array of array(ref)s rather than an iterator
(so it can be used in directly in map, grep etc)

=cut

sub batch_into_n {
	my $n        = shift;
	my @the_list = @ARG;

	my @result;
	my $it = natatime $n, @the_list;
	while ( my @batch = $it->() ) {
		push @result, \@batch;
	}

	return @result;
}

