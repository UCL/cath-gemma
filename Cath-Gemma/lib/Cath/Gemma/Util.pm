package Cath::Gemma::Util;

=head1 NAME

Cath::Gemma::Util - Utility functions used throughout Cath::Gemma

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess                                                        /;
use Digest::MD5         qw/ md5_hex                                                        /;
use English             qw/ -no_match_vars                                                 /;
use Exporter            qw/ import                                                         /;
use List::Util          qw/ any min                                                        /;
use POSIX               qw/ ceil floor log10                                               /;
use Storable            qw/ dclone                                                         /;
use Sys::Hostname;
use Time::HiRes         qw/ gettimeofday tv_interval                                       /;
use Time::Seconds;
use v5.10;
use Scalar::Util        qw/ blessed                                                        /;

our @EXPORT = qw/
	alignment_filebasename_of_starting_clusters
	alignment_suffix
	batch_into_n
	build_alignment_and_profile
	check_all_profile_files_exist
	cluster_name_spaceship
	cluster_name_spaceship_sort
	combine_starting_cluster_names
	compass_profile_suffix
	default_clusts_ordering
	default_profile_build_type
	default_temp_dir
	default_cleanup_temp_files
	evalue_window_ceiling
	evalue_window_floor
	generic_id_of_clusters
	get_starting_clusters_of_starting_cluster_dir
	guess_if_running_on_sge
	hhsuite_profile_suffix
	hhsuite_ffdb_suffix
	hhsuite_ffdata_suffix
	hhsuite_ffindex_suffix
	id_of_clusters
	make_atomic_write_file
	mergee_is_starting_cluster
	prof_file_of_prof_dir_and_aln_file
	prof_file_of_prof_dir_and_cluster_id
	profile_builder_class_from_type
	profile_scanner_class_from_type
	raw_sequences_filename_of_starting_clusters
	run_and_time_filemaking_cmd
	scan_filebasename_of_cluster_ids
	scan_filename_of_dir_and_cluster_ids
	scandata_suffix
	sequences_suffix
	time_fn
	time_seconds_to_sge_string
	unique_by_hashing
	/;

# Non-core (local)
use File::AtomicWrite;
use File::Which         qw/ which                                                       /;
use File::Copy          qw/ copy                                                        /;
use List::MoreUtils     qw/ all natatime                                                /;
use Log::Log4perl::Tiny qw/ :easy                                                       /;
use Path::Tiny;
use Try::Tiny;
use Type::Params        qw/ compile                                                     /;
use Types::Path::Tiny   qw/ Path                                                        /;
use Types::Standard     qw/ ArrayRef Bool ClassName CodeRef HashRef Maybe Num Optional slurpy Str /;

# Cath::Gemma
use Cath::Gemma::Types qw/
	CathGemmaDiskExecutables
	CathGemmaDiskProfileDirSet
	CathGemmaProfileType
	CathGemmaCompassProfileType
	CathGemmaHHSuiteProfileType
	CathGemmaNodeOrdering
	TimeSeconds
/;

my $CLEANUP_TMP_FILES = 1;

####

=head2 scandata_suffix

Return the filename suffix to use for scan data (hhsearch or compass) result files

=head2 alignment_suffix

Return the filename suffix to use for alignment files

=head2 hhsuite_ffdb_suffix

Return the default suffix for a HH-suite DB

=head2 hhsuite_ffdata_suffix

Return the default suffix for a HH-suite DB ffdata file

=head2 hhsuite_ffindex_suffix

Return the default suffix for a HH-suite DB ffindex file

=head2 hhsuite_profile_suffix

Return the default suffix for a HH-suite profile file

=head2 compass_profile_suffix

Return the default suffix for a COMPASS profile file

=head2 sequences_suffix

Return the filename suffix to use for files containing unaligned sequences

=head2 default_profile_build_type

Return the default profile_build_type

The previous DFX code was using an earlier version of the COMPASS code
which sometimes gave inconsistent results on different machines and which
sometimes gave inconsistent results depending on whether a model was built
as the first or second of a pair (with a dummy as the other).

In this work, we've performed a comparison of results and agreed that we're
all happy to move to mk_compass_db which avoids these issues.

UPDATE: default profile type is now 'hhconsensus'

=cut

sub hhsuite_ffdb_suffix        { '.db' }
sub hhsuite_ffdata_suffix      { '.db_a3m.ffdata' }
sub hhsuite_ffindex_suffix     { '.db_a3m.ffindex' }
sub hhsuite_profile_suffix     { '.a3m' }
sub compass_profile_suffix     { '.prof' }
sub scandata_suffix            { '.scan' }
sub alignment_suffix           { '.aln' }
sub sequences_suffix           { '.faa' }

sub default_profile_build_type { 'hhconsensus' }

=head2 default_cleanup_temp_files 

Whether or not to cleanup temporary files

=cut

sub default_cleanup_temp_files { $CLEANUP_TMP_FILES }

=head2 time_fn

Time the duration of the specified function being called by the specified arguments

The result is a hashref with keys-values:
	duration => the duration as a Time::Seconds object
	result   => the return value from the function call

=cut

sub time_fn {
	state $check = compile( CodeRef, slurpy ArrayRef );
	my ( $operation, $arguments ) = $check->( @ARG );

	my $t0     = [ gettimeofday() ];
	my $result = $operation->( @$arguments );
	return {
		duration => Time::Seconds->new( tv_interval( $t0, [ gettimeofday() ] ) ),
		result   => $result,
	};
}

=head2 run_and_time_filemaking_cmd

Run and time the specified function.

If an out_file is specified, make an atomic version of that file and pass that to the function.

Use the specified name in any error messages

=cut

sub run_and_time_filemaking_cmd {
	state $check = compile( Str, Maybe[Path], CodeRef );
	my ( $name, $out_file, $operation ) = $check->( @ARG );

	my $outer_result = time_fn(
		sub {

			if ( defined( $out_file ) ) {
				if ( -s "$out_file" ) {
					return { out_filename => $out_file };
				}

				if ( -e $out_file ) {
					my $remove_return = $out_file->remove();
					if ( ! $remove_return && -e $out_file ) {
						confess "Unable to remove $name output file \"$out_file\" : $OS_ERROR";
					}
				}

				my $out_dir = $out_file->parent();
				if ( ! -d $out_dir ) {
					my $mkpath_return = $out_dir->mkpath();
					if ( $mkpath_return == 0 && ! -d $out_dir ) {
						confess "Unable to make $name output directory \"$out_dir\" : $OS_ERROR";
					}
				}
			}

			my $atomic_file = defined( $out_file )
			                  ? make_atomic_write_file( { file => "$out_file" } )
			                  : undef;

			my $result = time_fn( $operation, defined( $atomic_file ) ? ( $atomic_file ) : ( ) );

			if ( ! defined( $result ) || ref( $result ) ne 'HASH' || ! defined( $result->{ result } ) || ref( $result->{ result } ) ne 'HASH' ) {
				confess "Invalid result returned by function passed to run_and_time_filemaking_cmd()";
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

Perform a sort (with the same syntax & semantics as Perl's `sort()`) except using the
cluster_name_spaceship as the sort criterion

=cut

sub cluster_name_spaceship_sort {
	return sort { cluster_name_spaceship( $a, $b ) } @ARG;
}

=head2 combine_starting_cluster_names

Combine the two specified lists of starting clusters according to the specified
CathGemmaNodeOrdering (which defaults to simple_ordering)

=cut

sub combine_starting_cluster_names {
	state $check = compile( ArrayRef[Str], ArrayRef[Str], Optional[CathGemmaNodeOrdering] );
	my ( $starting_clusters_a, $starting_clusters_b, $clusts_ordering ) = $check->( @ARG );

	$clusts_ordering //= default_clusts_ordering();

	my $result = ( $clusts_ordering eq 'tree_df_ordering' )
		? [                              @$starting_clusters_a, @$starting_clusters_b   ]
		: [ cluster_name_spaceship_sort( @$starting_clusters_a, @$starting_clusters_b ) ];

	return $result;
}

=head2 generic_id_of_clusters

Get the generic ID for the specified (reference to an) array of clusters

If leave_singletons is specified and evaluates to true and there is a single
input ID, then the result is that ID

TODOCUMENT more clearly: the relationship between id_of_clusters() and generic_id_of_clusters()

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

Get a list of the starting clusters in the specified directory
sorted according to `cluster_name_spaceship_sort()`

=cut

sub get_starting_clusters_of_starting_cluster_dir {
	state $check = compile( Path );
	my ( $dir ) = $check->( @ARG );

	my @starting_clusters = cluster_name_spaceship_sort(
		map { $ARG->basename( '.faa' ); } $dir->children
	);

	if ( any { $ARG =~ /^\./ } @starting_clusters ) {
		WARN 'Ignoring starting cluster(s) '
			. join(
				', ',
				map {
					"'$ARG'";
				}
				grep {
					$ARG =~ /^\./
				} @starting_clusters
			) . ' because it/they start(s) with dot characters';
		@starting_clusters = grep { $ARG !~ /^\./ } @starting_clusters;
	}

	return \@starting_clusters;
}

=head2 guess_if_running_on_sge

Guess whether the code is currently running in an SGE environment

=cut

sub guess_if_running_on_sge {
	my $has_sge_enviroment_variables = _has_sge_enviroment_variables();
	my $has_seg_exes                 = _has_seg_exes();

	if ( $has_sge_enviroment_variables != $has_seg_exes ) {
		confess
			'Contradictory data about whether running on SGE : _has_sge_enviroment_variables is '
			. ( $has_sge_enviroment_variables // 'undef' )
			. ' but _has_seg_exes is '
			. ( $has_seg_exes // 'undef' )
			. ' ';
	}
	return ( $has_seg_exes )
}

=head2 _has_seg_exes

Private implementation function

Return whether a few key SGE executables are visible by `which()`

=cut

sub _has_seg_exes {
	return all { which( $ARG ) } ( qw/ qalter qconf qdel qrsh qstat qsub / );
}

=head2 _has_sge_enviroment_variables

Private implementation function

Return whether all of a few key SGE environment variables are defined

=cut

sub _has_sge_enviroment_variables {
	return all { defined( $ENV{ $ARG } ); } ( qw/ SGE_ROOT SGE_ARCH SGE_CELL / );
}

=head2 make_atomic_write_file

Call the File::AtomicWrite constructor with the parameters in the specified (reference to) hash

Provide a descriptive filename template as the default (which can still be overridden)
containing the hostname and process ID to help with traceability

This was partly motivated by some indications that there might be clashes between concurrent threads.
The combination of hostname and process ID should make that impossible.
Further, this performs a check that the new filename doesn't already exist with a non-zero size.

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

=head2 id_of_clusters

This calculates an ID for a non-empty node list in a way that leaves
individual nodes' IDs alone but makes clear when there is a list of nodes

TODOCUMENT more clearly: the relationship between id_of_clusters() and generic_id_of_clusters()

TODOCUMENT: What's the reason for 'n0de_' - to do with the cluster names
            having distinctive patterns and getting sorted correctly.

=cut

sub id_of_clusters {
	state $check = compile( ArrayRef );
	my ( $starting_clusters ) = $check->( @ARG );

	if ( scalar( @$starting_clusters ) == 0 ) {
		confess "Cannot calculate an ID for an empty list of starting clusters";
	}
	if ( scalar( @$starting_clusters ) == 1 ) {
		return $starting_clusters->[ 0 ]
	}
	return 'n0de_' . generic_id_of_clusters( $starting_clusters );
}


=head2 _id_of_nodelist

Private implementation function.

This calculates an ID for a non-empty node list in a way that leaves
individual nodes' IDs alone but makes clear when there is a list of nodes

TODOCUMENT: What's the reason for 'l1st_' - to do with the cluster names
            having distinctive patterns and getting sorted correctly.

=cut

sub _id_of_nodelist {
	my $clusters = shift;
	if ( scalar( @$clusters ) == 0 ) {
		confess "Cannot calculate an ID for an empty list of clusters";
	}
	if ( scalar( @$clusters ) == 1 ) {
		return $clusters->[ 0 ]
	}
	return 'l1st_' . generic_id_of_clusters( $clusters );
}


=head2 suffix_for_profile_type

=cut

sub suffix_for_profile_type {
	state $check = compile( CathGemmaProfileType );
	my ( $profile_type ) = $check->( @ARG );
	return 
		CathGemmaCompassProfileType->check( $profile_type ) ? compass_profile_suffix() :
		CathGemmaHHSuiteProfileType->check( $profile_type ) ? hhsuite_profile_suffix() :
		confess "Failed to recognise profile type $profile_type";
}

=head2 default_temp_dir

Return the default temporary directory to use as a scratch space

IMPORTANT: This currently uses /dev/shm which treats the memory as a disk.
This should keep stuff very fast. However it does mean that code must:
 * avoid putting really large amounts of stuff in there
 * ensure it cleans up after itself

=cut

sub default_temp_dir {
	my $base_path = '/dev/shm'; # /tmp 
	my $CLEANUP_TMP_FILES = default_cleanup_temp_files();
	my $tmp_dir = Path::Tiny->tempdir( TEMPLATE => 'cath-gemma-util.XXXXXXXX', DIR => $base_path, CLEANUP => $CLEANUP_TMP_FILES );
	return $tmp_dir;
}

=head2 evalue_window_ceiling

Return the ceiling of the relevant evalue window (where the edges of each window are integer powers of 10^10)
(ie evalue_window_ceiling( 1.2e-15 ) is 1e-10)

=cut

sub evalue_window_ceiling {
	state $check = compile( Num );
	my ( $evalue ) = $check->( @ARG );

	( 10 ** ( ceil( log10( $evalue ) / 10 ) * 10 ) );
}

=head2 evalue_window_floor

Return the floor of the relevant evalue window (where the edges of each window are integer powers of 10^10)
(ie evalue_window_floor( 1.2e-15 ) is 1e-20)

=cut

sub evalue_window_floor {
	state $check = compile( Num );
	my ( $evalue ) = $check->( @ARG );

	( 10 ** ( floor( log10( $evalue ) / 10 ) * 10 ) );
}


=head2 default_clusts_ordering

Return the default clusts_ordering value

=cut

sub default_clusts_ordering {
	return 'simple_ordering';
}

=head2 alignment_filebasename_of_starting_clusters

Get the basename of the file in which the alignment should be stored for the specified starting clusters

=cut

sub alignment_filebasename_of_starting_clusters {
	my $starting_clusters = shift;
	return id_of_clusters( $starting_clusters ) . alignment_suffix();
}

=head2 prof_file_of_prof_dir_and_aln_file

Return the filename of the file in which the profile should be stored for the specified profile directory,
corresponding alignment file and profile_build_type

=cut

sub prof_file_of_prof_dir_and_aln_file {
	state $check = compile( Path, Path, CathGemmaProfileType );
	my ( $prof_dir, $aln_file, $profile_build_type ) = $check->( @ARG );

	return prof_file_of_prof_dir_and_cluster_id(
		$prof_dir,
		$aln_file->basename( alignment_suffix() ),
		$profile_build_type,
	);
}

=head2 prof_file_of_prof_dir_and_cluster_id

Return the filename of the file in which the profile should be stored for the specified profile directory,
cluster ID and profile_build_type

=cut

sub prof_file_of_prof_dir_and_cluster_id {
	state $check = compile( Path, Str, CathGemmaProfileType );
	my ( $prof_dir, $cluster_id, $profile_build_type ) = $check->( @ARG );

	my $suffix = suffix_for_profile_type( $profile_build_type );

	return $prof_dir->child( $cluster_id . '.' . $profile_build_type . $suffix );
}

=head2 raw_sequences_filename_of_starting_clusters

Return the basename of the file in which the raw sequences for the specified starting clusters should be stored

=cut

sub raw_sequences_filename_of_starting_clusters {
	my $starting_clusters = shift;
	return id_of_clusters( $starting_clusters ) . '.fa';
}

=head2 scan_filebasename_of_cluster_ids

Get the basename of the file in which the scan results should be stored for the specified query IDs,
match IDs and profile_build_type

=cut

sub scan_filebasename_of_cluster_ids {
	state $check = compile( ArrayRef[Str], ArrayRef[Str], CathGemmaProfileType );
	my ( $query_cluster_ids, $match_cluster_ids, $profile_build_type ) = $check->( @ARG );

	return
		  _id_of_nodelist( $query_cluster_ids )
		. '.'
		. _id_of_nodelist( $match_cluster_ids )
		. '.'
		. $profile_build_type
		. scandata_suffix()
}

=head2 scan_filename_of_dir_and_cluster_ids

Get the filename in which the scan results should be stored for the specified directory, query IDs,
match IDs and $profile_build_type

=cut

sub scan_filename_of_dir_and_cluster_ids {
	state $check = compile( Path, ArrayRef[Str], ArrayRef[Str], CathGemmaProfileType );
	my ( $dir, $query_ids, $match_ids, $profile_build_type ) = $check->( @ARG );

	return $dir->child( scan_filebasename_of_cluster_ids( $query_ids, $match_ids, $profile_build_type ) );
}

=head2 time_seconds_to_sge_string

Return a string summarising the specified Time::Seconds value in a format
usable in SGE compute clusters (eg an hour is '01:00:00')

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

Return (a reference to) an array of the uniqued (and sorted) values in the specified
(reference to) array

TODOCUMENT: why is this needed above using `uniq( sort() )` (with `uniq()`
from List::Util)?

=cut

sub unique_by_hashing {
	sort( keys( %{ { map { ( $ARG, 1 ) } @ARG } } ) );
}

=head2 check_all_profile_files_exist

TODOCUMENT

=cut

sub check_all_profile_files_exist {
	state $check = compile( Path, ArrayRef[Str], ArrayRef[Str], CathGemmaProfileType );
	my ( $profile_dir, $query_cluster_ids, $match_cluster_ids, $profile_build_type ) = $check->( @ARG );

	foreach my $cluster_id ( @$query_cluster_ids, @$match_cluster_ids ) {
		my $profile_file = prof_file_of_prof_dir_and_cluster_id( $profile_dir, $cluster_id, $profile_build_type );
		DEBUG "Profile file exists: $profile_file";
		if ( ! -s $profile_file ) {
			confess "Unable to find non-empty profile file $profile_file for cluster $cluster_id when scanning queries ("
			        . join( ', ', @$query_cluster_ids )
			        . ') against matches ('
			        . join( ', ', @$match_cluster_ids )
			        . ')';
		}
	}
}

=head2 build_alignment_and_profile

TODOCUMENT

=cut

sub build_alignment_and_profile {
	# allow this function to be called from an instance or class context (or neither)
	my $maybe_class = shift if ($ARG[0] =~ /^Cath::Gemma::/ || blessed $ARG[0] =~ /^Cath::Gemma::/ );
	state $check = compile( CathGemmaDiskExecutables, ArrayRef[Str], CathGemmaDiskProfileDirSet, CathGemmaProfileType, Optional[Bool] );
	my ( $exes, $starting_clusters, $profile_dir_set, $profile_build_type, $skip_profile_build ) = $check->( @ARG );

	$skip_profile_build //= 0;

	my $aln_file = $profile_dir_set->alignment_filename_of_starting_clusters( $starting_clusters );
	my $temp_aln_dir = Path::Tiny->tempdir( TEMPLATE => "aln_tempdir.XXXXXXXXXXX", DIR => $exes->tmp_dir() );
	my $alignment_result = 
		( -s $aln_file )
		? {
			out_filename         => $aln_file,
			file_already_present => 1,
		}
		: Cath::Gemma::Tool::Aligner->make_alignment_file(
			$exes,
			$starting_clusters,
			$profile_dir_set,
		);

	my $built_aln_file   = $alignment_result->{ out_filename  };
	my $profile_result   = {};
	if ( ! $skip_profile_build ) {
		my $builder_class = 
		    CathGemmaCompassProfileType->check( $profile_build_type ) ? "Cath::Gemma::Tool::CompassProfileBuilder" :
		    CathGemmaHHSuiteProfileType->check( $profile_build_type ) ? "Cath::Gemma::Tool::HHSuiteProfileBuilder" :
			confess "Unknown profile build type $profile_build_type";
		
		$profile_result = $builder_class->build_profile(
			$exes,
			$built_aln_file,
			$profile_dir_set,
			$profile_build_type
		);
	}

	if ( "$built_aln_file" ne "$aln_file" ) {
		my $aln_atomic_file   = File::AtomicWrite->new( { file => "$aln_file" } );
		my $atom_tmp_aln_file = path( $aln_atomic_file->filename );

		move( $built_aln_file, $atom_tmp_aln_file )
			or confess "Cannot move built alignment file \"$built_aln_file\" to atomic temporary \"$atom_tmp_aln_file\" : $OS_ERROR";

		try {
			$aln_atomic_file->commit();
		}
		catch {
			my $error = $ARG;
			while ( chomp( $error ) ) {}
			confess
				   'Caught error when trying to atomically commit write of temporary file "'
				 . $aln_atomic_file->filename()
				 . '" to "'
				 . $aln_file
				 . '", original error message: "'
				 . $error
				 . '".';
		};
	}

	return {
		( defined( $alignment_result->{ duration             } ) ? ( aln_duration              => $alignment_result->{ duration             } ) : () ),
		( defined( $alignment_result->{ mean_seq_length      } ) ? ( mean_seq_length           => $alignment_result->{ mean_seq_length      } ) : () ),
		( defined( $alignment_result->{ num_sequences        } ) ? ( num_sequences             => $alignment_result->{ num_sequences        } ) : () ),
		( defined( $alignment_result->{ wrapper_duration     } ) ? ( aln_wrapper_duration      => $alignment_result->{ wrapper_duration     } ) : () ),
		( defined( $alignment_result->{ file_already_present } ) ? ( aln_file_already_present  => $alignment_result->{ file_already_present } ) : () ),

		( defined( $profile_result  ->{ duration             } ) ? ( prof_duration             => $profile_result  ->{ duration             } ) : () ),
		( defined( $profile_result  ->{ wrapper_duration     } ) ? ( prof_wrapper_duration     => $profile_result  ->{ wrapper_duration     } ) : () ),
		( defined( $profile_result  ->{ file_already_present } ) ? ( prof_file_already_present => $profile_result  ->{ file_already_present } ) : () ),
		aln_filename  => $aln_file,
		prof_filename => $profile_result->{ out_filename  },
	};
}

=head2 profile_builder_class_from_type

Return the class name of the appropriate profile builder based on the given C<profile_build_type>

=cut

sub profile_builder_class_from_type {
	# allow this function to be called from an instance or class context (or neither)
	my $maybe_class;
	$maybe_class = shift if ($ARG[0] =~ /^Cath::Gemma::/ || blessed $ARG[0] =~ /^Cath::Gemma::/ );
	my $profile_build_type = shift;
	my $builder_class = 
		CathGemmaCompassProfileType->check( $profile_build_type ) ? "Cath::Gemma::Tool::CompassProfileBuilder" :
		CathGemmaHHSuiteProfileType->check( $profile_build_type ) ? "Cath::Gemma::Tool::HHSuiteProfileBuilder" :
		confess "Unknown profile build type $profile_build_type";
	return $builder_class;
}

=head2 profile_scanner_class_from_type

Return the class name of the appropriate profile scanner based on the given C<profile_build_type>

=cut

sub profile_scanner_class_from_type {
	# allow this function to be called from an instance or class context (or neither)
	my $maybe_class;
	$maybe_class = shift if ($ARG[0] =~ /^Cath::Gemma::/ || blessed $ARG[0] =~ /^Cath::Gemma::/ );
	my $profile_build_type = shift;
	my $scanner_class = 
		CathGemmaCompassProfileType->check( $profile_build_type ) ? 'Cath::Gemma::Tool::CompassScanner' : 
		CathGemmaHHSuiteProfileType->check( $profile_build_type ) ? 'Cath::Gemma::Tool::HHSuiteScanner' : 
		confess "! Error: not able to get scanner class for profile build type '$profile_build_type'";
	return $scanner_class;
}



1;
