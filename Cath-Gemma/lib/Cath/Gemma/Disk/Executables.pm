package Cath::Gemma::Disk::Executables;

=head1 NAME

Cath::Gemma::Disk::Executables - Prepare align/profile-scan executables in a temporary directory that gets automatically cleaned up

This allows the executables to be copied into some fast storage (eg /dev/shm) so they can be run very quickly
without needing to repeatedly access the originals (which may be on a networked drive)

TODOCUMENT - Are there issues with this not always getting cleaned up

=cut

use strict;
use warnings;

# Core
use Carp                qw/ confess        /;
use English             qw/ -no_match_vars /;
use File::Copy          qw/ copy move      /;
use FindBin;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Capture::Tiny       qw/ capture        /;
use Log::Log4perl::Tiny qw/ :easy          /;
use Path::Tiny;
use Type::Params        qw/ compile        /;
use Types::Path::Tiny   qw/ Path           /;
use Types::Standard     qw/ Object Str     /;

# Cath::Gemma
use Cath::Gemma::Types qw/ CathGemmaCompassProfileType /;
use Cath::Gemma::Util;

# HHsuite executables
my $ffindex_build_exe    = path( "$FindBin::Bin/../tools/hhsuite/bin/ffindex_build"                 )->realpath;
my $hhconsensus_exe      = path( "$FindBin::Bin/../tools/hhsuite/bin/hhconsensus"                   )->realpath;
my $hhsearch_exe         = path( "$FindBin::Bin/../tools/hhsuite/bin/hhsearch"                      )->realpath;
my $hhsuite_data_dir     = path( "$FindBin::Bin/../tools/hhsuite/data"                              )->realpath;

# COMPASS executables
my $compass_build_exe    = path( "$FindBin::Bin/../tools/compass/compass_wp_245_fixed"              )->realpath;
my $compass_scan_241_exe = path( "$FindBin::Bin/../tools/compass/compass_db1Xdb2_241"               )->realpath;
my $compass_scan_310_exe = path( "$FindBin::Bin/../tools/compass/compass_db1Xdb2_310"               )->realpath;
my $mk_compass_db_exe    = path( "$FindBin::Bin/../tools/compass/mk_compass_db_310"                 )->realpath;

# MAFFT executables
my $mafft_bin_dir        = path( "$FindBin::Bin/../tools/mafft-6.864-without-extensions/binaries"   )->realpath;
my $mafft_src_exe        = path( "$FindBin::Bin/../tools/mafft-6.864-without-extensions/core/mafft" )->realpath;

=head2 tmp_dir

TODOCUMENT

=cut

has tmp_dir => (
	is      => 'ro',
	isa     => Path,
	default => sub { default_temp_dir(); }
);

=head2 _exes_dir

TODOCUMENT

=head2 ffindex_build

TODOCUMENT

=head2 hhconsensus

TODOCUMENT

=head2 hhsearch

TODOCUMENT

=head2 compass_build

TODOCUMENT

=head2 compass_scan_241

TODOCUMENT

=head2 compass_scan_310

TODOCUMENT

=head2 mafft

TODOCUMENT

=head2 mk_compass_db

TODOCUMENT

=cut


has [ qw/ _exes_dir ffindex_build hhconsensus hhsearch compass_build compass_scan_241 compass_scan_310 mafft mk_compass_db / ] => (
	is  => 'lazy',
	isa => Path,
);


=head2 _prepare_mafft_directories

TODOCUMENT

=cut

sub _prepare_mafft_directories {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $dest_dir = $self->_exes_dir()->child( 'mafft_binaries_dir' );

	my ( $mafft_stdout, $mafft_stderr, $mafft_exit ) = capture {
		system( 'rsync', '-av', "$mafft_bin_dir/", "$dest_dir/" );
	};
	if ( $mafft_stderr || $mafft_exit ) {
		confess "Failed to mirror (rsync) MAFFT binaries from $mafft_bin_dir to $dest_dir";
	}

	$ENV{ MAFFT_BINARIES } = "$dest_dir";
}


=head2 _prepare_hhsuite_directories

TODOCUMENT

=cut

my $ALREADY_PREPARED_HHSUITE_DIRECTORIES=0;

sub _prepare_hhsuite_directories {

	return if $ALREADY_PREPARED_HHSUITE_DIRECTORIES;

	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $base_dir = $self->_exes_dir()->child( 'hhsuite' );
	my $dest_dir = $base_dir->child( 'data' );
	$dest_dir->mkpath;

	my ( $stdout, $stderr, $exit ) = capture {
		system( 'rsync', '-av', "$hhsuite_data_dir/", "$dest_dir/" );
	};
	if ( $stderr || $exit ) {
		confess "Failed to mirror (rsync) HHSuite data from $hhsuite_data_dir to $dest_dir";
	}

	$ENV{ HHLIB } = "$base_dir";

	$ALREADY_PREPARED_HHSUITE_DIRECTORIES++;
}

=head2 _prepare_exe

TODOCUMENT

=cut

sub _prepare_exe {
	state $check = compile( Object, Str, Path );
	my ( $self, $name, $source_file ) = $check->( @ARG );

	my $dest_file = $self->_exes_dir()->child( $source_file->basename() );

	DEBUG "About to copy executable $source_file to $dest_file (and then make it executable)";

	copy ( $source_file, $dest_file )
		or confess "Unable to copy $name executable from \"$source_file\" to \"$dest_file\" : $OS_ERROR";

	$dest_file->chmod( 'a+x' )
		or confess "Unable to chmod $name executable \"$dest_file\" : $OS_ERROR";

	return $dest_file;
}

=head2 _build__exes_dir

TODOCUMENT

=cut

sub _build__exes_dir {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	my $CLEANUP_TMP_FILES = default_cleanup_temp_files();

	if (! $CLEANUP_TMP_FILES) {
		WARN "DEBUG: using /tmp rather than /dev/shm (and NOT cleaning up)";
		return Path::Tiny->tempdir(
			TEMPLATE => "cath_gemma_exes_dir.XXXXXXXX",
			DIR      => '/tmp',
			CLEANUP  => 0,
		);
	}
	else {
		return Path::Tiny->tempdir(
			TEMPLATE => "cath_gemma_exes_dir.XXXXXXXX",
			DIR      => '/dev/shm',
			CLEANUP  => 1,
		);
	}
}

=head2 _build_hhconsensus

TODOCUMENT

=cut

sub _build_hhconsensus {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	$self->_prepare_hhsuite_directories();
	return $self->_prepare_exe( 'hhconsensus', $hhconsensus_exe );
}

=head2 _build_ffindex_build

TODOCUMENT

=cut

sub _build_ffindex_build {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	$self->_prepare_hhsuite_directories();
	return $self->_prepare_exe( 'ffindex_build', $ffindex_build_exe );
}

=head2 _build_hhsearch

TODOCUMENT

=cut

sub _build_hhsearch {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	$self->_prepare_hhsuite_directories();
	return $self->_prepare_exe( 'hhsearch', $hhsearch_exe );
}


=head2 _build_compass_build

TODOCUMENT

=cut

sub _build_compass_build {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return $self->_prepare_exe( 'compass_build', $compass_build_exe );
}

=head2 _build_compass_scan_241

TODOCUMENT

=cut

sub _build_compass_scan_241 {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return $self->_prepare_exe( 'compass_scan_241', $compass_scan_241_exe );
}

=head2 _build_compass_scan_310

TODOCUMENT

=cut

sub _build_compass_scan_310 {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return $self->_prepare_exe( 'compass_scan_310', $compass_scan_310_exe );
}

=head2 _build_mafft

TODOCUMENT

=cut

sub _build_mafft {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	$self->_prepare_mafft_directories();
	return $self->_prepare_exe( 'mafft', $mafft_src_exe );
}

=head2 _build_mk_compass_db

TODOCUMENT

=cut

sub _build_mk_compass_db {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );
	return $self->_prepare_exe( 'mk_compass_db', $mk_compass_db_exe );
}

=head2 prepare_all

TODOCUMENT

=cut

sub prepare_all {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	$self->ffindex_build();
	$self->hhconsensus();
	$self->hhsearch();
	$self->compass_build();
	$self->compass_scan_241();
	$self->compass_scan_310();
	$self->mafft();
	$self->mk_compass_db();
}

1;