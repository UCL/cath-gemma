package Cath::Gemma::Disk::Executables;

use strict;
use warnings;

# Core
use Carp              qw/ confess        /;
use English           qw/ -no_match_vars /;
use File::Copy        qw/ copy move      /;
use FindBin;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Capture::Tiny     qw/ capture        /;
use Path::Tiny;
use Type::Params      qw/ compile        /;
use Types::Path::Tiny qw/ Path           /;
use Types::Standard   qw/ Object Str     /;

# Cath
use Cath::Gemma::Types qw/ CathGemmaCompassProfileType /;
use Cath::Gemma::Util;

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

=cut


=head2 compass_build

TODOCUMENT

=cut


=head2 compass_scan_241

TODOCUMENT

=cut


=head2 compass_scan_310

TODOCUMENT

=cut


=head2 mafft

TODOCUMENT

=cut


=head2 mk_compass_db

TODOCUMENT

=cut



has [ qw/ _exes_dir compass_build compass_scan_241 compass_scan_310 mafft mk_compass_db / ] => (
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

=head2 _prepare_exe

TODOCUMENT

=cut

sub _prepare_exe {
	state $check = compile( Object, Str, Path );
	my ( $self, $name, $source_file ) = $check->( @ARG );

	my $dest_file = $self->_exes_dir()->child( $source_file->basename() );

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

	return Path::Tiny->tempdir(
		TEMPLATE => "cath_gemma_exes_dir.XXXXXXXX",
		DIR      => '/dev/shm',
	);
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

	$self->compass_build();
	$self->compass_scan_241();
	$self->compass_scan_310();
	$self->mafft();
	$self->mk_compass_db();
}

1;