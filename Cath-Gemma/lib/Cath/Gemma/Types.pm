package Cath::Gemma::Types;

=head1 NAME

Cath::Gemma::Types - TODOCUMENT

=cut

use Type::Library
	-base,
	-declare => qw(
		CathGemmaCompassProfileType
		CathGemmaNodeOrdering

		CathGemmaComputeProfileBuildTask
		CathGemmaComputeProfileScanTask
		CathGemmaComputeWorkBatch
		CathGemmaDiskExecutables
		CathGemmaDiskGemmaDirSet
		CathGemmaDiskProfileDirSet
		CathGemmaScanScanData
		CathGemmaScanScansData
		CathGemmaTreeMerge
		ComputeProfileBuildTask

		CathGemmaExecutor
		CathGemmaTreeBuilder
	);


use Type::Utils qw/ class_type coerce declare enum from role_type /;
use Types::Standard -types;

enum       CathGemmaCompassProfileType, [ qw/
	compass_wp_dummy_1st
	compass_wp_dummy_2nd
	mk_compass_db
/ ];

enum       CathGemmaNodeOrdering,       [ qw/
	tree_df_ordering
	simple_ordering
/ ];

class_type CathGemmaComputeProfileBuildTask, { class => "Cath::Gemma::Compute::ProfileBuildTask" };
class_type CathGemmaComputeProfileScanTask,  { class => "Cath::Gemma::Compute::ProfileScanTask"  };
class_type CathGemmaComputeWorkBatch,        { class => "Cath::Gemma::Compute::WorkBatch"        };
class_type CathGemmaDiskExecutables,         { class => "Cath::Gemma::Disk::Executables"         };
class_type CathGemmaDiskGemmaDirSet,         { class => "Cath::Gemma::Disk::GemmaDirSet"         };
class_type CathGemmaDiskProfileDirSet,       { class => "Cath::Gemma::Disk::ProfileDirSet"       };
class_type CathGemmaScanScanData,            { class => "Cath::Gemma::Scan::ScanData"            };
class_type CathGemmaScanScansData,           { class => "Cath::Gemma::Scan::ScansData"           };
class_type CathGemmaTreeMerge,               { class => "Cath::Gemma::Tree::Merge"               };

role_type  CathGemmaExecutor,                { role  => "Cath::Gemma::Executor"                  };
role_type  CathGemmaTreeBuilder,             { role  => "Cath::Gemma::TreeBuilder"               };

# coerce CathGemmaTreeMerge,
# 	from Str, via { 
# 		require Cath::Gemma::Tree::Merge; 
# 		Cath::Gemma::Tree::Merge->new_from_string( $_ ) 
# 	};

1;