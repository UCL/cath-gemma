#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;

# Core (test)
use Test::More tests => 47;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# To generate updated list (under tcsh), you can use:
#
#     find lib -iname '*.pm' | sed 's#/#::#g' | env LC_ALL=C sort -uf | sed "s#\.pm#' ) }#g" | sed "s#^lib::#BEGIN{ use_ok( '#g" | column -t

BEGIN{  use_ok(  'Cath::Gemma'                                            )  }
BEGIN{  use_ok(  'Cath::Gemma::Compute::Task'                             )  }
BEGIN{  use_ok(  'Cath::Gemma::Compute::Task::BuildTreeTask'              )  }
BEGIN{  use_ok(  'Cath::Gemma::Compute::Task::ProfileBuildTask'           )  }
BEGIN{  use_ok(  'Cath::Gemma::Compute::Task::ProfileScanTask'            )  }
BEGIN{  use_ok(  'Cath::Gemma::Compute::TaskThreadPooler'                 )  }
BEGIN{  use_ok(  'Cath::Gemma::Compute::WorkBatch'                        )  }
BEGIN{  use_ok(  'Cath::Gemma::Compute::WorkBatcher'                      )  }
BEGIN{  use_ok(  'Cath::Gemma::Compute::WorkBatcherState'                 )  }
BEGIN{  use_ok(  'Cath::Gemma::Compute::WorkBatchList'                    )  }
BEGIN{  use_ok(  'Cath::Gemma::Disk::BaseDirAndProject'                   )  }
BEGIN{  use_ok(  'Cath::Gemma::Disk::Executables'                         )  }
BEGIN{  use_ok(  'Cath::Gemma::Disk::GemmaDirSet'                         )  }
BEGIN{  use_ok(  'Cath::Gemma::Disk::ProfileDirSet'                       )  }
BEGIN{  use_ok(  'Cath::Gemma::Disk::TreeDirSet'                          )  }
BEGIN{  use_ok(  'Cath::Gemma::Executor'                                  )  }
BEGIN{  use_ok(  'Cath::Gemma::Executor::ConfessExecutor'                 )  }
BEGIN{  use_ok(  'Cath::Gemma::Executor::DirectExecutor'                  )  }
BEGIN{  use_ok(  'Cath::Gemma::Executor::SpawnExecutor'                   )  }
BEGIN{  use_ok(  'Cath::Gemma::Executor::SpawnHpcSgeRunner'               )  }
BEGIN{  use_ok(  'Cath::Gemma::Executor::SpawnLocalRunner'                )  }
BEGIN{  use_ok(  'Cath::Gemma::Executor::SpawnRunner'                     )  }
BEGIN{  use_ok(  'Cath::Gemma::Scan::Impl::LinkList'                      )  }
BEGIN{  use_ok(  'Cath::Gemma::Scan::Impl::LinkMatrix'                    )  }
BEGIN{  use_ok(  'Cath::Gemma::Scan::ScanData'                            )  }
BEGIN{  use_ok(  'Cath::Gemma::Scan::ScansData'                           )  }
BEGIN{  use_ok(  'Cath::Gemma::Scan::ScansDataFactory'                    )  }
BEGIN{  use_ok(  'Cath::Gemma::StartingClustersOfId'                      )  }
BEGIN{  use_ok(  'Cath::Gemma::Tool::Aligner'                             )  }
BEGIN{  use_ok(  'Cath::Gemma::Tool::CompassProfileBuilder'               )  }
BEGIN{  use_ok(  'Cath::Gemma::Tool::CompassScanner'                      )  }
BEGIN{  use_ok(  'Cath::Gemma::Tree::Merge'                               )  }
BEGIN{  use_ok(  'Cath::Gemma::Tree::MergeBundler'                        )  }
BEGIN{  use_ok(  'Cath::Gemma::Tree::MergeBundler::RnnMergeBundler'       )  }
BEGIN{  use_ok(  'Cath::Gemma::Tree::MergeBundler::SimpleMergeBundler'    )  }
BEGIN{  use_ok(  'Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler'  )  }
BEGIN{  use_ok(  'Cath::Gemma::Tree::MergeList'                           )  }
BEGIN{  use_ok(  'Cath::Gemma::TreeBuilder'                               )  }
BEGIN{  use_ok(  'Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder'      )  }
BEGIN{  use_ok(  'Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder'       )  }
BEGIN{  use_ok(  'Cath::Gemma::TreeBuilder::NaiveMeanOfBestTreeBuilder'   )  }
BEGIN{  use_ok(  'Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder'         )  }
BEGIN{  use_ok(  'Cath::Gemma::TreeBuilder::PureTreeBuilder'              )  }
BEGIN{  use_ok(  'Cath::Gemma::TreeBuilder::WindowedTreeBuilder'          )  }
BEGIN{  use_ok(  'Cath::Gemma::Types'                                     )  }
BEGIN{  use_ok(  'Cath::Gemma::Util'                                      )  }
BEGIN{  use_ok(  'TimeSecondsToJson'                                      )  }
