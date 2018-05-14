package Cath::Gemma::Tool::ProfileBuilderInterface;

use Moo::Role;

requires qw/ 
    build_profile
    build_profile_in_dir
    build_alignment_and_profile
/;

1;
