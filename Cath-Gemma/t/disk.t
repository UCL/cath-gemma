use strict;
use warnings;

# Core (test)
use Test::More tests => 8;

# Core
use FindBin;

# Find non-core lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# Non-core (local)
use Path::Tiny;

# Find Cath::Gemma lib directory using FindBin
use lib $FindBin::Bin . '/lib';

my $base_dir = path( '/some/base/path' );
my $project  = 'some_project';

BEGIN { use_ok( 'Cath::Gemma::Disk::BaseDirAndProject' ) }
BEGIN { use_ok( 'Cath::Gemma::Disk::GemmaDirSet'       ) }
BEGIN { use_ok( 'Cath::Gemma::Disk::ProfileDirSet'     ) }
BEGIN { use_ok( 'Cath::Gemma::Disk::TreeDirSet'        ) }

# Cath::Gemma::Disk::BaseDirAndProject
{
	my $bdap_no_proj = new_ok( 'Cath::Gemma::Disk::BaseDirAndProject' => [ base_dir => $base_dir                      ] );
	my $bdap_wi_proj = new_ok( 'Cath::Gemma::Disk::BaseDirAndProject' => [ base_dir => $base_dir, project => $project ] );

	is( $bdap_no_proj->get_project_subdir_of_subdir( 'child' ), path( '/some/base/path/child'              ), 'Subdir is correct with no project' );
	is( $bdap_wi_proj->get_project_subdir_of_subdir( 'child' ), path( '/some/base/path/child/some_project' ), 'Subdir is correct with a project'  );
}

# # Cath::Gemma::Disk::ProfileDirSet
# {

# }

# # Cath::Gemma::Disk::GemmaDirSet
# {

# }

# # Cath::Gemma::Disk::TreeDirSet
# {

# }
