package Cath::Gemma::Types;

=head1 NAME

Cath::Gemma::Types - TODOCUMENT

=cut

use Type::Library
	-base,
	-declare => qw(
		CathGemmaCompassProfileType
		CathGemmaComputeBatchingPolicy
		CathGemmaHpcMode
		CathGemmaNodeOrdering

		CathGemmaComputeTaskBuildTreeTask
		CathGemmaComputeTaskProfileBuildTask
		CathGemmaComputeTaskProfileScanTask
		CathGemmaComputeWorkBatch
		CathGemmaComputeWorkBatchList
		CathGemmaDiskExecutables
		CathGemmaDiskGemmaDirSet
		CathGemmaDiskProfileDirSet
		CathGemmaDiskTreeDirSet
		CathGemmaExecutorHpcRunner
		CathGemmaScanScanData
		CathGemmaScanScansData
		CathGemmaTreeMerge
		CathGemmaTreeMergeList
		ComputeProfileBuildTask

		CathGemmaExecutor
		CathGemmaTreeBuilder

		TimeSeconds
	);


use Type::Utils qw/ class_type declare enum from role_type /;
use Types::Standard -types;

enum       CathGemmaCompassProfileType,  [ qw/
	compass_wp_dummy_1st
	compass_wp_dummy_2nd
	mk_compass_db
/ ];

enum       CathGemmaComputeBatchingPolicy,  [ qw/
	permit_empty__forbid_overflow
	allow_overflow_to_ensure_non_empty
/ ];

enum       CathGemmaHpcMode, [ qw/
	hpc_local
	hpc_sge
/ ];

enum       CathGemmaNodeOrdering,        [ qw/
	tree_df_ordering
	simple_ordering
/ ];

class_type CathGemmaComputeTaskBuildTreeTask,    { class => "Cath::Gemma::Compute::Task::BuildTreeTask"    };
class_type CathGemmaComputeTaskProfileBuildTask, { class => "Cath::Gemma::Compute::Task::ProfileBuildTask" };
class_type CathGemmaComputeTaskProfileScanTask,  { class => "Cath::Gemma::Compute::Task::ProfileScanTask"  };
class_type CathGemmaComputeWorkBatch,            { class => "Cath::Gemma::Compute::WorkBatch"              };
class_type CathGemmaComputeWorkBatcher,          { class => "Cath::Gemma::Compute::WorkBatcher"            };
class_type CathGemmaComputeWorkBatchList,        { class => "Cath::Gemma::Compute::WorkBatchList"          };
class_type CathGemmaDiskBaseDirAndProject,       { class => "Cath::Gemma::Disk::BaseDirAndProject"         };
class_type CathGemmaDiskExecutables,             { class => "Cath::Gemma::Disk::Executables"               };
class_type CathGemmaDiskGemmaDirSet,             { class => "Cath::Gemma::Disk::GemmaDirSet"               };
class_type CathGemmaDiskProfileDirSet,           { class => "Cath::Gemma::Disk::ProfileDirSet"             };
class_type CathGemmaDiskTreeDirSet,              { class => "Cath::Gemma::Disk::TreeDirSet"                };

class_type CathGemmaScanScanData,                { class => "Cath::Gemma::Scan::ScanData"                  };
class_type CathGemmaScanScansData,               { class => "Cath::Gemma::Scan::ScansData"                 };
class_type CathGemmaTreeMerge,                   { class => "Cath::Gemma::Tree::Merge"                     };
class_type CathGemmaTreeMergeList,               { class => "Cath::Gemma::Tree::MergeList"                 };

role_type  CathGemmaComputeTask,                 { role  => "Cath::Gemma::Compute::Task"                   };
role_type  CathGemmaExecutor,                    { role  => "Cath::Gemma::Executor"                        };
role_type  CathGemmaExecutorHpcRunner,           { role  => "Cath::Gemma::Executor::HpcRunner"             };
role_type  CathGemmaTreeBuilder,                 { role  => "Cath::Gemma::TreeBuilder"                     };

class_type TimeSeconds,                          { class => "Time::Seconds"                                };

# coerce CathGemmaTreeMerge,
# 	from Str, via { 
# 		require Cath::Gemma::Tree::Merge; 
# 		Cath::Gemma::Tree::Merge->new_from_string( $_ ) 
# 	};

1;

