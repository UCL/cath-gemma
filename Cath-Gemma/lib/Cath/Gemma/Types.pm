package Cath::Gemma::Types;

=head1 NAME

Cath::Gemma::Types - TODOCUMENT

=cut

use Type::Library
	-base,
	-declare => qw(
		CathGemmaDiskExecutables
		CathGemmaTreeMerge
		ComputeProfileBuildTask
	);

use Type::Utils qw/ class_type coerce declare from /;
use Types::Standard -types;

class_type CathGemmaComputeProfileBuildTask, { class => "Cath::Gemma::Compute::ProfileBuildTask" };
class_type CathGemmaComputeProfileScanTask,  { class => "Cath::Gemma::Compute::ProfileScanTask"  };
class_type CathGemmaComputeWorkBatch,        { class => "Cath::Gemma::Compute::WorkBatch"        };
class_type CathGemmaDiskExecutables,         { class => "Cath::Gemma::Disk::Executables"         };
class_type CathGemmaDiskGemmaDirSet,         { class => "Cath::Gemma::Disk::GemmaDirSet"         };
class_type CathGemmaDiskProfileDirSet,       { class => "Cath::Gemma::Disk::ProfileDirSet"       };
class_type CathGemmaScanScanData,            { class => "Cath::Gemma::Scan::ScanData"            };
class_type CathGemmaTreeMerge,               { class => "Cath::Gemma::Tree::Merge"               };

# coerce CathGemmaTreeMerge,
# 	from Str, via { 
# 		require Cath::Gemma::Tree::Merge; 
# 		Cath::Gemma::Tree::Merge->new_from_string( $_ ) 
# 	};

1;