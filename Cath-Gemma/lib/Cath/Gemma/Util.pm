package Cath::Gemma::Util;

=head1 NAME

Cath::Gemma::Util - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp           qw/ confess                                                        /;
use Digest::MD5    qw/ md5_hex                                                        /;
use English        qw/ -no_match_vars                                                 /;
use Exporter       qw/ import                                                         /;
use List::Util     qw/ min                                                            /;
use POSIX          qw/ ceil floor log10                                               /;
use Storable       qw/ dclone                                                         /;
use Sys::Hostname;
use Time::HiRes    qw/ gettimeofday tv_interval                                       /;
use Time::Seconds;
use v5.10;

our @EXPORT = qw/
	alignment_filebasename_of_starting_clusters
	alignment_profile_suffix
	batch_into_n
	cluster_name_spaceship
	cluster_name_spaceship_sort
	combine_starting_cluster_names
	compass_profile_suffix
	compass_scan_suffix
	default_compass_profile_build_type
	default_temp_dir
	evalue_window_ceiling
	evalue_window_floor
	generic_id_of_clusters
	get_starting_clusters_of_starting_cluster_dir
	guess_if_running_on_sge
	has_seg_exes
	has_sge_enviroment_variables
	id_of_starting_clusters
	make_atomic_write_file
	mergee_is_starting_cluster
	min_time_seconds
	prof_file_of_prof_dir_and_aln_file
	prof_file_of_prof_dir_and_cluster_id
	raw_sequences_filename_of_starting_clusters
	run_and_time_filemaking_cmd
	scan_filebasename_of_cluster_ids
	scan_filename_of_dir_and_cluster_ids
	time_seconds_to_sge_string
	time_fn
	unique_by_hashing
	/;

# Non-core (local)
use File::AtomicWrite;
use File::Which       qw/ which                                                       /;
use List::MoreUtils   qw/ all natatime                                                /;
use Path::Tiny;
use Try::Tiny;
use Type::Params      qw/ compile                                                     /;
use Types::Path::Tiny qw/ Path                                                        /;
use Types::Standard   qw/ ArrayRef Bool CodeRef HashRef Maybe Num Optional slurpy Str /;

# Cath
use Cath::Gemma::Types qw/
	CathGemmaCompassProfileType
	CathGemmaNodeOrdering
	TimeSeconds
/;

=head2 time_fn

TODOCUMENT

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

TODOCUMENT

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
			                  ? make_atomic_write_file( { file => "$out_file" } )
			                  : undef;

			my $result = time_fn( $operation, defined( $atomic_file ) ? ( $atomic_file ) : ( ) );

			if ( ! defined( $result ) || ref( $result ) ne 'HASH' || ! defined( $result->{ result } ) || ref( $result->{ result } ) ne 'HASH' ) {
				confess "ARGH";
			}

			if ( defined( $atomic_file ) ) {
				try {
					$atomic_file->commit();
				}
				catch {
					my $error = $ARG;
					while ( chomp( $error ) ) {}
					confess
						   'Caught error when trying to atomically commit write of temporary file "'
						 . $atomic_file->filename()
						 . '" (which now has -s of '
						 . ( ( -s $atomic_file->filename() ) // 'undef' )
						 . ') to "'
						 . $out_file
						 . '" (the parent of which now has -s of '
						 . ( ( -s $out_file->parent() ) // 'undef' )
						 . '), original error message: "'
						 . $error
						 . '".';
				};
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

TODOCUMENT

=cut

sub mergee_is_starting_cluster {
	my $mergee = shift;
	return ! ref( $mergee );
}

=head2 min_time_seconds

TODOCUMENT

=cut

sub min_time_seconds {
	return Time::Seconds->new( min(
		map { $ARG->seconds(); } @ARG
	) );
}

=head2 batch_into_n

TODOCUMENT

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

=head2 cluster_name_spaceship

TODOCUMENT

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

=head2 cluster_name_spaceship_sort

Perform a sort (with the same syntax & semantics as sort) except using the
cluster_name_spaceship as the sort criterion

=cut

sub cluster_name_spaceship_sort {
	return sort { cluster_name_spaceship( $a, $b ) } @ARG;
}

=head2 combine_starting_cluster_names

TODOCUMENT

=cut

sub combine_starting_cluster_names {
	state $check = compile( ArrayRef[Str], ArrayRef[Str], Optional[CathGemmaNodeOrdering] );
	my ( $starting_clusters_a, $starting_clusters_b, $clusts_ordering ) = $check->( @ARG );

	my $result = ( $clusts_ordering && ( $clusts_ordering eq 'tree_df_ordering' ) )
		? [                              @$starting_clusters_a, @$starting_clusters_b   ]
		: [ cluster_name_spaceship_sort( @$starting_clusters_a, @$starting_clusters_b ) ];

	return $result;
}

=head2 generic_id_of_clusters

TODOCUMENT

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

TODOCUMENT

=cut

sub get_starting_clusters_of_starting_cluster_dir {
	state $check = compile( Path );
	my ( $dir ) = $check->( @ARG );

	return [ sort { cluster_name_spaceship( $a, $b ) } map { $ARG->basename( '.faa' ); } $dir->children ];
}

=head2 guess_if_running_on_sge

TODOCUMENT

=cut

sub guess_if_running_on_sge {
	my $has_sge_enviroment_variables = has_sge_enviroment_variables();
	my $has_seg_exes                 = has_seg_exes();

	if ( $has_sge_enviroment_variables != $has_seg_exes ) {
		confess
			'Contradictory data about whether running on SGE : has_sge_enviroment_variables is '
			. ( $has_sge_enviroment_variables // 'undef' )
			. ' but has_seg_exes is '
			. ( $has_seg_exes // 'undef' )
			. ' ';
	}
	return ( $has_seg_exes )
}

=head2 has_seg_exes

TODOCUMENT

=cut

sub has_seg_exes {
	return all { which( $ARG ) } ( qw/ qalter qconf qdel qrsh qstat qsub / );
}

=head2 has_sge_enviroment_variables

TODOCUMENT

=cut

sub has_sge_enviroment_variables {
	return all { defined( $ENV{ $ARG } ); } ( qw/ SGE_ROOT SGE_ARCH SGE_CELL / );
}

=head2 make_atomic_write_file

TODOCUMENT

=cut

sub make_atomic_write_file {
	state $check = compile( HashRef );
	my ( $params ) = $check->( @ARG );

	my $hostname = hostname();
	$hostname =~ s/[^\w\-\.]//g;

	# If a template hasn't been specified, add one that includes the host name and process ID to further reduce the chance of clashes
	if ( ! defined( $params->{ template } ) ) {
		$params->{ template } =   '.atmc_write.host_'
		                        . $hostname
		                        . '.pid_'
		                        . $PID
		                        . '.XXXXXXXXXX';
	}

	# Create a File::AtomicWrite
	my $atomic_file = File::AtomicWrite->new( $params );

	# Check it isn't using a temporary file that already has non-zero size
	if ( -s $atomic_file->filename() ) {
		confess 'AtomicFile for ' . $params->{ file } . ' has been assigned a temporary file ("' . $atomic_file->filename() . '") that already exists and has non-zero size';
	}

	# Return the result
	return $atomic_file;
}

=head2 id_of_starting_clusters

TODOCUMENT

=cut

sub id_of_starting_clusters {
	my $starting_clusters = shift;

	if ( ref( $starting_clusters ) ne 'ARRAY' ) {
		confess "Argh";
	}

	if ( scalar( @$starting_clusters ) == 0 ) {
		confess "Cannot calculate an ID for an empty list of starting clusters";
	}
	if ( scalar( @$starting_clusters ) == 1 ) {
		return $starting_clusters->[ 0 ]
	}
	return 'n0de_' . generic_id_of_clusters( $starting_clusters );
}


=head2 id_of_nodelist

TODOCUMENT

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

TODOCUMENT

=cut

sub compass_profile_suffix {
	return '.prof';
}

=head2 default_compass_profile_build_type

TODOCUMENT

=cut

sub default_compass_profile_build_type {
	return 'mk_compass_db';
}


=head2 default_temp_dir

TODOCUMENT

=cut

sub default_temp_dir {
	return path( '/dev/shm' );
}

=head2 evalue_window_ceiling

TODOCUMENT

=cut

sub evalue_window_ceiling {
	state $check = compile( Num );
	my ( $evalue ) = $check->( @ARG );

	( 10 ** ( ceil( log10( $evalue ) / 10 ) * 10 ) );
}

=head2 evalue_window_floor

TODOCUMENT

=cut

sub evalue_window_floor {
	state $check = compile( Num );
	my ( $evalue ) = $check->( @ARG );

	( 10 ** ( floor( log10( $evalue ) / 10 ) * 10 ) );
}

=head2 compass_scan_suffix

TODOCUMENT

=cut

sub compass_scan_suffix {
	return '.scan';
}

=head2 alignment_profile_suffix

TODOCUMENT

=cut

sub alignment_profile_suffix {
	return '.faa';
}

=head2 alignment_filebasename_of_starting_clusters

TODOCUMENT

=cut

sub alignment_filebasename_of_starting_clusters {
	my $starting_clusters = shift;
	return id_of_starting_clusters( $starting_clusters ) . alignment_profile_suffix();
}

=head2 prof_file_of_prof_dir_and_aln_file

TODOCUMENT

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

TODOCUMENT

=cut

sub prof_file_of_prof_dir_and_cluster_id {
	state $check = compile( Path, Str, CathGemmaCompassProfileType );
	my ( $prof_dir, $cluster_id, $compass_profile_build_type ) = $check->( @ARG );

	return $prof_dir->child( $cluster_id . '.' . $compass_profile_build_type . compass_profile_suffix() );
}

=head2 raw_sequences_filename_of_starting_clusters

TODOCUMENT

=cut

sub raw_sequences_filename_of_starting_clusters {
	my $starting_clusters = shift;
	return id_of_starting_clusters( $starting_clusters ) . '.fa';
}

=head2 scan_filebasename_of_cluster_ids

TODOCUMENT

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

TODOCUMENT

=cut

sub scan_filename_of_dir_and_cluster_ids {
	state $check = compile( Path, ArrayRef[Str], ArrayRef[Str], CathGemmaCompassProfileType );
	my ( $dir, $query_ids, $match_ids, $compass_profile_build_type ) = $check->( @ARG );

	return $dir->child( scan_filebasename_of_cluster_ids( $query_ids, $match_ids, $compass_profile_build_type ) );
}



=head2 time_seconds_to_sge_string

TODOCUMENT

=cut

sub time_seconds_to_sge_string {
	state $check = compile( TimeSeconds );
	my ( $time_seconds ) = $check->( @ARG );

	my $hours   = int( ( $time_seconds                                 )->hours()   );
	my $minutes = int( ( $time_seconds - 3600 * $hours                 )->minutes() );
	my $seconds = int( ( $time_seconds - 3600 * $hours - 60 * $minutes )->seconds() );

	return join(
		':',
		sprintf( '%02d', $hours   ),
		sprintf( '%02d', $minutes ),
		sprintf( '%02d', $seconds ),
	);
}

=head2 unique_by_hashing

TODOCUMENT

=cut

sub unique_by_hashing {
	sort( keys( %{ { map { ( $ARG, 1 ) } @ARG } } ) );
}

1;
