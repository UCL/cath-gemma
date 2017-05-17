package Cath::Gemma::Util;

=head1 NAME

Cath::Gemma::Util - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp              qw/ confess                           /;
use Digest::MD5       qw/ md5_hex                           /;
use English           qw/ -no_match_vars                    /;
use Exporter          qw/ import                            /;
use Time::HiRes       qw/ gettimeofday tv_interval          /;
use v5.10;

our @EXPORT = qw/
	alignment_filename_of_starting_clusters
	alignment_profile_suffix
	cluster_name_spaceship
	compass_profile_suffix
	compass_scan_suffix
	id_of_starting_clusters
	mergee_is_starting_cluster
	raw_sequences_filename_of_starting_clusters
	run_and_time_filemaking_cmd
	scan_filename_of_cluster_ids
	time_fn
	/;

# Non-core (local)
use Type::Params      qw/ compile                           /;
use Types::Path::Tiny qw/ Path                              /;
use Types::Standard   qw/ ArrayRef CodeRef Maybe slurpy Str /;

=head2 time_fn

=cut

sub time_fn {
	state $check = compile( CodeRef, slurpy ArrayRef );
	my ( $operation, $arguments ) = $check->( @ARG );

	my $t0 = [ gettimeofday() ];
	my $result = $operation->( @$arguments );
	my $duration = tv_interval( $t0, [ gettimeofday() ] );
	return {
		duration => $duration,
		result   => $result,
	};
}

=head2 run_something

=cut

sub run_and_time_filemaking_cmd {
	state $check = compile( Str, Maybe[Path], CodeRef );
	my ( $name, $out_file, $operation ) = $check->( @ARG );

	if ( defined( $out_file ) ) {
		if ( -s $out_file ) {
			return { out_filename => $out_file };
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
	return 'n0de_' . md5_hex( @$starting_clusters );
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
	return 'l1st_' . md5_hex( @$clusters );
}


=head2 compass_profile_suffix

=cut

sub compass_profile_suffix {
	return '.prof';
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

=head2 alignment_filename_of_starting_clusters

=cut

sub alignment_filename_of_starting_clusters {
	my $starting_clusters = shift;
	return id_of_starting_clusters( $starting_clusters ) . alignment_profile_suffix();
}

=head2 raw_sequences_filename_of_starting_clusters

=cut

sub raw_sequences_filename_of_starting_clusters {
	my $starting_clusters = shift;
	return id_of_starting_clusters( $starting_clusters ) . '.fa';
}

=head2 scan_filename_of_cluster_ids

=cut

sub scan_filename_of_cluster_ids {
	state $check = compile( ArrayRef[Str], ArrayRef[Str] );
	my ( $query_cluster_ids, $match_cluster_ids ) = $check->( @ARG );

	return
		  id_of_nodelist( $query_cluster_ids )
		. '.'
		. id_of_nodelist( $match_cluster_ids )
		. '.scan';
}

1;
