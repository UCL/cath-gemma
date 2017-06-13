package Cath::Gemma::Util;

=head1 NAME

Cath::Gemma::Util - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp              qw/ confess                                             /;
use Digest::MD5       qw/ md5_hex                                             /;
use English           qw/ -no_match_vars                                      /;
use Exporter          qw/ import                                              /;
use POSIX             qw/ ceil floor log10                                    /;
use Time::HiRes       qw/ gettimeofday tv_interval                            /;
use Time::Seconds;
use v5.10;

our @EXPORT = qw/
	alignment_filebasename_of_starting_clusters
	alignment_profile_suffix
	cluster_name_spaceship
	compass_profile_suffix
	compass_scan_suffix
	default_compass_profile_build_type
	default_temp_dir
	evalue_window_ceiling
	evalue_window_floor
	generic_id_of_clusters
	get_starting_clusters_of_starting_cluster_dir
	id_of_starting_clusters
	mergee_is_starting_cluster
	ordered_cluster_name_pair
	prof_file_of_prof_dir_and_aln_file
	prof_file_of_prof_dir_and_cluster_id
	raw_sequences_filename_of_starting_clusters
	run_and_time_filemaking_cmd
	scan_filebasename_of_cluster_ids
	scan_filename_of_dir_and_cluster_ids
	time_fn
	/;

# Non-core (local)
use Path::Tiny;
use Type::Params      qw/ compile                                             /;
use Types::Path::Tiny qw/ Path                                                /;
use Types::Standard   qw/ ArrayRef Bool CodeRef Maybe Num Optional slurpy Str /;

# Cath
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
/;

=head2 time_fn

=cut

sub time_fn {
	state $check = compile( CodeRef, slurpy ArrayRef );
	my ( $operation, $arguments ) = $check->( @ARG );

	my $t0     = [ gettimeofday() ];
	my $result = $operation->( @$arguments );
	return {
		duration => Time::Seconds->new( tv_interval( $t0, [ gettimeofday() ] ) ),
		duration => tv_interval( $t0, [ gettimeofday() ] ),
		result   => $result,
	};
}

=head2 run_and_time_filemaking_cmd

=cut

sub run_and_time_filemaking_cmd {
	state $check = compile( Str, Maybe[Path], CodeRef );
	my ( $name, $out_file, $operation ) = $check->( @ARG );

	my $outer_result = time_fn(
		sub {

			if ( defined( $out_file ) ) {
				# warn "Checking for output file \"$out_file\"";
				if ( -s "$out_file" ) {
					# warn "Returning...";
					return { out_filename => $out_file };
				}

				if ( "$out_file" eq 'temporary_example_data/output/1.10.150.120/n0de_9e4d22ff9a44d049cefaa240aae7e01d.l1st_9557d2b7962844e9ccaf3c8f2e8d6ab7.scan' ) {
					sleep 1000;
				}

				if ( -e $out_file ) {
					$out_file->remove()
						or confess "Unable to remove $name output file \"$out_file\" : $OS_ERROR";
				}

				my $out_dir = $out_file->parent();
				if ( ! -d $out_dir ) {
					$out_dir->mkpath()
						or confess "Unable to make $name output directory \"$out_dir\" : $OS_ERROR";
				}
			}

			my $atomic_file = defined( $out_file )
			                  ? File::AtomicWrite->new( { file => "$out_file" } )
			                  : undef;

			my $result = time_fn( $operation, defined( $atomic_file ) ? ( $atomic_file ) : ( ) );

			if ( ! defined( $result ) || ref( $result ) ne 'HASH' || ! defined( $result->{ result } ) || ref( $result->{ result } ) ne 'HASH' ) {
				confess "ARGH";
			}

			if ( defined( $atomic_file ) ) {
				$atomic_file->commit();
			}

			$result->{ result }->{ duration     } = $result->{ duration };
			$result->{ result }->{ out_filename } = $out_file;

			return $result->{ result };


		}
	);

	$outer_result->{ result }->{ duration } //= 0;
	$outer_result->{ result }->{ wrapper_duration } = ( $outer_result->{ duration } - $outer_result->{ result }->{ duration } );

	return $outer_result->{ result };
}

=head2 mergee_is_starting_cluster

=cut

sub mergee_is_starting_cluster {
	my $mergee = shift;
	return ! ref( $mergee );
}

=head2 cluster_name_spaceship

=cut

sub cluster_name_spaceship {
	my $a = shift;
	my $b = shift;

	if ( $a =~ /^(\D*)([\d]+)(\D*)$/ ) {
		my $prefix   = $1;
		my $number_a = $2;
		my $suffix   = $3;

		if ( $b =~ /^$prefix([\d]+)$suffix$/ ) {
			my $number_b = $1;
			return ( $number_a <=> $number_b );
		}
		else {
			return -1;
		}
	}

	return
		( $b =~ /^(\D*)([\d]+)(\D*)$/ )
		? 1
		: ( $a cmp $b );
}

=head2 ordered_cluster_name_pair

=cut

sub ordered_cluster_name_pair {
	my $a = shift;
	my $b = shift;

	if ( cluster_name_spaceship( $a, $b ) > 0 ) {
		return [ $b, $a ];
	}
	return [ $a, $b ];
}

=head2 generic_id_of_clusters

=cut

sub generic_id_of_clusters {
	state $check = compile( ArrayRef[Str], Optional[Bool] );
	my ( $clusters, $leave_singletons ) = $check->( @ARG );

	if ( $leave_singletons && scalar( @$clusters ) == 1 ) {
		return $clusters->[0];
	}

	return md5_hex( @$clusters );
}

=head2 get_starting_clusters_of_starting_cluster_dir

=cut

sub get_starting_clusters_of_starting_cluster_dir {
	state $check = compile( Path );
	my ( $dir ) = $check->( @ARG );

	return [ map { $ARG->basename( '.faa' ); } $dir->children ];
}

=head2 id_of_starting_clusters

=cut

sub id_of_starting_clusters {
	my $starting_clusters = shift;
	if ( scalar( @$starting_clusters ) == 0 ) {
		confess "Cannot calculate an ID for an empty list of starting clusters";
	}
	if ( scalar( @$starting_clusters ) == 1 ) {
		return $starting_clusters->[ 0 ]
	}
	return 'n0de_' . generic_id_of_clusters( $starting_clusters );
}


=head2 id_of_nodelist

=cut

sub id_of_nodelist {
	my $clusters = shift;
	if ( scalar( @$clusters ) == 0 ) {
		confess "Cannot calculate an ID for an empty list of clusters";
	}
	if ( scalar( @$clusters ) == 1 ) {
		return $clusters->[ 0 ]
	}
	return 'l1st_' . generic_id_of_clusters( $clusters );
}


=head2 compass_profile_suffix

=cut

sub compass_profile_suffix {
	return '.prof';
}

=head2 default_compass_profile_build_type

=cut

sub default_compass_profile_build_type {
	return 'compass_wp_dummy_1st';
}


=head2 default_temp_dir

=cut

sub default_temp_dir {
	return path( '/dev/shm' );
}

=head2 evalue_window_ceiling

=cut

sub evalue_window_ceiling {
	state $check = compile( Num );
	my ( $evalue ) = $check->( @ARG );

	( 10 ** ( ceil( log10( $evalue ) / 10 ) * 10 ) );
}

=head2 evalue_window_floor

=cut

sub evalue_window_floor {
	state $check = compile( Num );
	my ( $evalue ) = $check->( @ARG );

	( 10 ** ( floor( log10( $evalue ) / 10 ) * 10 ) );
}

=head2 compass_scan_suffix

=cut

sub compass_scan_suffix {
	return '.scan';
}

=head2 alignment_profile_suffix

=cut

sub alignment_profile_suffix {
	return '.faa';
}

=head2 alignment_filebasename_of_starting_clusters

=cut

sub alignment_filebasename_of_starting_clusters {
	my $starting_clusters = shift;
	return id_of_starting_clusters( $starting_clusters ) . alignment_profile_suffix();
}

=head2 prof_file_of_prof_dir_and_aln_file

=cut

sub prof_file_of_prof_dir_and_aln_file {
	state $check = compile( Path, Path, CathGemmaCompassProfileType );
	my ( $prof_dir, $aln_file, $compass_profile_build_type ) = $check->( @ARG );

	return prof_file_of_prof_dir_and_cluster_id(
		$prof_dir,
		$aln_file->basename( alignment_profile_suffix() ),
		$compass_profile_build_type,
	);
}

=head2 prof_file_of_prof_dir_and_cluster_id

=cut

sub prof_file_of_prof_dir_and_cluster_id {
	state $check = compile( Path, Str, CathGemmaCompassProfileType );
	my ( $prof_dir, $cluster_id, $compass_profile_build_type ) = $check->( @ARG );

	return $prof_dir->child( $cluster_id . '.' . $compass_profile_build_type . compass_profile_suffix() );
}

=head2 raw_sequences_filename_of_starting_clusters

=cut

sub raw_sequences_filename_of_starting_clusters {
	my $starting_clusters = shift;
	return id_of_starting_clusters( $starting_clusters ) . '.fa';
}

=head2 scan_filebasename_of_cluster_ids

=cut

sub scan_filebasename_of_cluster_ids {
	state $check = compile( ArrayRef[Str], ArrayRef[Str], CathGemmaCompassProfileType );
	my ( $query_cluster_ids, $match_cluster_ids, $compass_profile_build_type ) = $check->( @ARG );

	return
		  id_of_nodelist( $query_cluster_ids )
		. '.'
		. id_of_nodelist( $match_cluster_ids )
		. '.'
		. $compass_profile_build_type
		. '.scan';
}

=head2 scan_filename_of_dir_and_cluster_ids

=cut

sub scan_filename_of_dir_and_cluster_ids {
	state $check = compile( Path, ArrayRef[Str], ArrayRef[Str], CathGemmaCompassProfileType );
	my ( $dir, $query_ids, $match_ids, $compass_profile_build_type ) = $check->( @ARG );

	return $dir->child( scan_filebasename_of_cluster_ids( $query_ids, $match_ids, $compass_profile_build_type ) );
}

1;
