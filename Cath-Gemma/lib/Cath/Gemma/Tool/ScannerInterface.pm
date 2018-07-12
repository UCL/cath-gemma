package Cath::Gemma::Tool::ScannerInterface;

=head1 NAME

Cath::Gemma::Tool::ScannerInterface - interface for classes implementing profile scans

=head1 SYNOPSIS

    package My::Scanner;

    use Moo;
    with 'Cath::Gemma::Tool::ScannerInterface';

    sub scan_to_file { }

    1;

=cut

use Moo::Role;

requires qw/ 
    scan_to_file
/;

1;
