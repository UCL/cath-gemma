package Cath::Gemma::Scan::ScanData;

use strict;
use warnings;

# Core
# use List::Util        qw/ sum                           /;
use Carp              qw/ confess                       /;
use English           qw/ -no_match_vars                /;
use v5.10;

# Moo
use Moo;
use MooX::HandlesVia;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
# use Path::Tiny;
# use Types::Standard    qw/ ArrayRef Bool ClassName Object Optional Str /;
use Type::Params      qw/ compile Invocant              /;
use Types::Path::Tiny qw/ Path                          /;
use Types::Standard   qw/ ArrayRef Num Object Str Tuple /;

# Cath
# use Cath::Gemma::Tool::CompassProfileBuilder;
# use Cath::Gemma::Tool::CompassScanner;
# use Cath::Gemma::Disk::Executables;
# use Cath::Gemma::Types qw/ CathGemmaDiskExecutables /;
use Cath::Gemma::Util;

=head2 scan_data

=cut

has scan_data => (
	is  => 'ro',
	isa => ArrayRef[Tuple[Str, Str, Num]],
);

=head2 read_from_file

=cut

sub read_from_file {
	state $check = compile( Invocant, Path );
	my ( $proto, $scan_data_file ) = $check->( @ARG );

	my $scan_data_data = $scan_data_file->slurp();
	my @scan_data_lines = split( /\n/, $scan_data_data );
	foreach my $scan_data_line ( @scan_data_lines ) {
		$scan_data_line = [ split( /\s+/, $scan_data_line ) ];
	}

	return __PACKAGE__->new(
		scan_data => \@scan_data_lines,
	);
}

=head2 write_to_file

=cut

sub write_to_file {
	state $check = compile( Object, Path );
	my ( $self, $output_file ) = $check->( @ARG );

	my $the_data = $self->scan_data();

	$output_file->spew(
		join(
			"\n",
			map { join( "\t", @$ARG ); } @$the_data
		) . "\n"
	);
}

=head2 parse_from_raw_compass_scan_output_lines

=cut

sub parse_from_raw_compass_scan_output_lines {
	state $check = compile( Invocant, ArrayRef[Str] );
	my ( $proto, $compass_output_lines ) = $check->( @ARG );

	my ( @outputs, $prev_id1, $prev_id2 );
	my $alignment_profile_suffix = alignment_profile_suffix();
	foreach my $compass_output_line ( @$compass_output_lines ) {
		if ( $compass_output_line =~ /^Ali1:\s+(\S+)\s+Ali2:\s+(\S+)/ ) {
			if ( defined( $prev_id1 ) || defined( $prev_id2 ) ) {
				confess "Argh:\n\"$compass_output_line\"\n$prev_id1\n$prev_id2\n";
			}
			$prev_id1 = $1;
			$prev_id2 = $2;
			foreach my $prev_id ( \$prev_id1, \$prev_id2 ) {
				if ( $$prev_id =~ /^(.*\/)?(\w+)$alignment_profile_suffix$/ ) {
					$$prev_id = $2;
				}
				else {
					confess "Argh $$prev_id";
				}
			}
		}
		if ( $compass_output_line =~ /\bEvalue (.*)$/ ) {
			if ( $1 ne '** not found **' ) {
				if ( $compass_output_line =~ /\bEvalue = (\S+)$/ ) {
					push @outputs, [ $prev_id1, $prev_id2, $1 ];
				}
				else {
					confess "Argh";
				}
			}
			if ( ! defined( $prev_id1 ) || ! defined( $prev_id2 ) ) {
				confess "Argh";
			}
			$prev_id1 = undef;
			$prev_id2 = undef;
		}
	}

	return __PACKAGE__->new(
		scan_data => \@outputs
	);
}

1;