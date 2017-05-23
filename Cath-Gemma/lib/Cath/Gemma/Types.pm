package Cath::Gemma::Types;

=head1 NAME

Cath::Gemma::Types - TODOCUMENT

=cut

use Type::Library
	-base,
	-declare => qw(
		CathGemmaExecutables
		CathGemmaMerge
		ComputeProfileBuildTask
	);

use Type::Utils qw/ class_type coerce declare from /;
use Types::Standard -types;

class_type CathGemmaComputeProfileBuildTask, { class => "Cath::Gemma::Compute::ProfileBuildTask" };
class_type CathGemmaComputeWorkBatch,        { class => "Cath::Gemma::Compute::WorkBatch"        };
class_type CathGemmaExecutables,             { class => "Cath::Gemma::Executables"               };
class_type CathGemmaMerge,                   { class => "Cath::Gemma::Merge"                     };

# coerce CathGemmaMerge,
# 	from Str, via { 
# 		require Cath::Gemma::Merge; 
# 		Cath::Gemma::Merge->new_from_string( $_ ) 
# 	};

1;