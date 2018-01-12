#!/usr/bin/env perl

use strict;
use warnings;

# Core
use FindBin;

# Core (test)
use Test::More tests => 46;

# Find non-core external lib directory using FindBin
use lib $FindBin::Bin . '/../extlib/lib/perl5';

# To generate updated list (under tcsh), you can use:
#
#     find lib -iname '*.pm' | sed 's#/#::#g' | env LC_ALL=C sort -uf | sed "s#\.pm#' );#g" | sed "s#^lib::#use_ok( '#g" | column -t

use_ok( 'Cath::Gemma'                                           );
use_ok( 'Cath::Gemma::Compute::Task'                            );
use_ok( 'Cath::Gemma::Compute::Task::BuildTreeTask'             );
use_ok( 'Cath::Gemma::Compute::Task::ProfileBuildTask'          );
use_ok( 'Cath::Gemma::Compute::Task::ProfileScanTask'           );
use_ok( 'Cath::Gemma::Compute::TaskThreadPooler'                );
use_ok( 'Cath::Gemma::Compute::WorkBatch'                       );
use_ok( 'Cath::Gemma::Compute::WorkBatcher'                     );
use_ok( 'Cath::Gemma::Compute::WorkBatcherState'                );
use_ok( 'Cath::Gemma::Compute::WorkBatchList'                   );
use_ok( 'Cath::Gemma::Disk::BaseDirAndProject'                  );
use_ok( 'Cath::Gemma::Disk::Executables'                        );
use_ok( 'Cath::Gemma::Disk::GemmaDirSet'                        );
use_ok( 'Cath::Gemma::Disk::ProfileDirSet'                      );
use_ok( 'Cath::Gemma::Disk::TreeDirSet'                         );
use_ok( 'Cath::Gemma::Executor'                                 );
use_ok( 'Cath::Gemma::Executor::ConfessExecutor'                );
use_ok( 'Cath::Gemma::Executor::HpcExecutor'                    );
use_ok( 'Cath::Gemma::Executor::HpcRunner'                      );
use_ok( 'Cath::Gemma::Executor::HpcRunner::HpcLocalRunner'      );
use_ok( 'Cath::Gemma::Executor::HpcRunner::HpcSgeRunner'        );
use_ok( 'Cath::Gemma::Executor::LocalExecutor'                  );
use_ok( 'Cath::Gemma::Scan::Impl::LinkList'                     );
use_ok( 'Cath::Gemma::Scan::Impl::Links'                        );
use_ok( 'Cath::Gemma::Scan::ScanData'                           );
use_ok( 'Cath::Gemma::Scan::ScansData'                          );
use_ok( 'Cath::Gemma::Scan::ScansDataFactory'                   );
use_ok( 'Cath::Gemma::StartingClustersOfId'                     );
use_ok( 'Cath::Gemma::Tool::Aligner'                            );
use_ok( 'Cath::Gemma::Tool::CompassProfileBuilder'              );
use_ok( 'Cath::Gemma::Tool::CompassScanner'                     );
use_ok( 'Cath::Gemma::Tree::Merge'                              );
use_ok( 'Cath::Gemma::Tree::MergeBundler'                       );
use_ok( 'Cath::Gemma::Tree::MergeBundler::RnnMergeBundler'      );
use_ok( 'Cath::Gemma::Tree::MergeBundler::SimpleMergeBundler'   );
use_ok( 'Cath::Gemma::Tree::MergeBundler::WindowedMergeBundler' );
use_ok( 'Cath::Gemma::Tree::MergeList'                          );
use_ok( 'Cath::Gemma::TreeBuilder'                              );
use_ok( 'Cath::Gemma::TreeBuilder::NaiveHighestTreeBuilder'     );
use_ok( 'Cath::Gemma::TreeBuilder::NaiveLowestTreeBuilder'      );
use_ok( 'Cath::Gemma::TreeBuilder::NaiveMeanOfBestTreeBuilder'  );
use_ok( 'Cath::Gemma::TreeBuilder::NaiveMeanTreeBuilder'        );
use_ok( 'Cath::Gemma::TreeBuilder::PureTreeBuilder'             );
use_ok( 'Cath::Gemma::TreeBuilder::WindowedTreeBuilder'         );
use_ok( 'Cath::Gemma::Types'                                    );
use_ok( 'Cath::Gemma::Util'                                     );
