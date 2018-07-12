package Cath::Gemma::Tool::ProfileBuilderInterface;

=head1 NAME

Cath::Gemma::Tool::ProfileBuilderInterface - interface for classes implementing profile build

=head1 SYNOPSIS

    package My::ProfileBuilder;

    use Moo;
    with 'Cath::Gemma::Tool::ProfileBuilderInterface';

    sub build_profile { }
    sub build_profile_in_dir { }
    sub build_alignment_and_profile { }

    1;

=cut
use Moo::Role;

requires qw/ 
    build_profile
    build_profile_in_dir
    build_alignment_and_profile
/;

1;
