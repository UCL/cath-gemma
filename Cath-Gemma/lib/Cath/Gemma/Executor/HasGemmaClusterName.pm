package Cath::Gemma::Executor::HasGemmaClusterName;

=head1 NAME

Cath::Gemma::Executor::HasGemmaClusterName - role that provide details on the cluster environment

=cut

use strict;
use warnings;

# Core
use English           qw/ -no_match_vars                /;
use v5.10;

# Moo
use Moo::Role;
use strictures 2;

# Non-core (local)
use Type::Params      qw/ compile                       /;
use Types::Path::Tiny qw/ Path                          /;
use Types::Standard   qw/ ArrayRef Int Maybe Object Str /;

# Cath::Gemma
use Cath::Gemma::Types  qw/
	TimeSeconds
	/;

=head2 get_cluster_name( assume_local_if_undefined=0 )

Provides access to the environment variable GEMMA_CLUSTER_NAME (eg 'myriad')

The option C<assume_local_if_undefined> controls the behaviour if this environment variable is not defined.
If set, it will return C<'local'>, otherwise it will die (default).

Defaults 

=cut

sub get_cluster_name {
	my $self = shift;
    my %params = @_;
    my $assume_local_if_not_set = $params{assume_local_if_undefined} //= 0;

	my $cluster_name = $ENV{ GEMMA_CLUSTER_NAME };

    if ( ! defined $cluster_name ) {
        if ( $assume_local_if_not_set ) {
            $cluster_name = 'local';
        }
        else {
            die "! Error: failed to get cluster name (ENV{ GEMMA_CLUSTER_NAME } is not defined)" 
        }
    }

	return $cluster_name;
}


=head2 get_cluster_submit_host

Return the hostname of the submit node for this cluster (eg 'myriad.rc.ucl.ac.uk')
based on the value of L<get_cluster_name>.

Will throw an exception if this is not found in the list of expected names.

=cut

sub get_cluster_submit_host {
	my $self = shift;

	my $cluster_name = $self->get_cluster_name;

	return 
		$cluster_name =~ /chuckle/   ? 'bchuckle.cs.ucl.ac.uk' :
		$cluster_name =~ /^legion/   ? 'legion.rc.ucl.ac.uk' : 
		$cluster_name =~ /^myriad/   ? 'myriad.rc.ucl.ac.uk' :
		die "Error: failed to get submit host from cluster name: $cluster_name";
}

1;
