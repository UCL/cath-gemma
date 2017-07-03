package Cath::Gemma::Compute::WorkBatcher;

=head1 NAME

Cath::Gemma::Compute::WorkBatcher - TODOCUMENT

=cut

use strict;
use warnings;

# Core
use Carp               qw/ confess             /;
use English            qw/ -no_match_vars      /;
use List::Util         qw/ min                 /;
use Storable           qw/ freeze              /;
use v5.10;

# Moo
use Moo;
use MooX::StrictConstructor;
use strictures 1;

# Non-core (local)
use Capture::Tiny       qw/ capture             /;
use Object::Util;
use Log::Log4perl::Tiny qw/ :easy               /;
use Path::Tiny;
use Type::Params        qw/ compile             /;
use Types::Path::Tiny   qw/ Path                /;
use Types::Standard     qw/ ArrayRef Int Object /;

# Cath
use Cath::Gemma::Compute::WorkBatch;
use Cath::Gemma::Types qw/
	CathGemmaComputeProfileBuildTask
	CathGemmaComputeWorkBatch
	/;
use Cath::Gemma::Util;

=head2 profile_batch_size

=cut

has profile_batch_size => (
	is      => 'rwp',
	isa     => Int,
	default => 150,
);

=head2 profile_batches

=cut

has profile_batches => (
	is  => 'rwp',
	isa => ArrayRef[CathGemmaComputeWorkBatch],
	default => sub { [] },
);

=head2 id

=cut

sub id {
	state $check = compile( Object );
	my ( $self ) = $check->( @ARG );

	return generic_id_of_clusters( [ map { $ARG->id() } @{ $self->profile_batches() } ] );
}

=head2 add_profile_build_work

=cut

sub add_profile_build_work {
	state $check = compile( Object, CathGemmaComputeProfileBuildTask );
	my ( $self, $profile_task ) = $check->( @ARG );

	my $num_new_profiles = $profile_task->num_profiles();

	my $profile_batches = $self->profile_batches();

	my $num_profiles_in_new_task = $profile_task->num_profiles();

	my $num_free_profiles_in_last_batch =
		( scalar( @$profile_batches ) > 0 )
		? $self->profile_batch_size() - $profile_batches->[ -1 ]->num_profiles()
		: 0;

	if ( scalar( @$profile_batches ) > 0 ) {
		my @bob = map { $ARG->num_profiles(); } @$profile_batches;
	}

	my $num_in_fillup_batch = min( $num_free_profiles_in_last_batch, $num_new_profiles );

	if ( $num_in_fillup_batch > 0 ) {
		my $prev_last_profile_batch = pop @$profile_batches;
		push
			@{ $profile_batches },
			Cath::Gemma::Compute::WorkBatch->new(
				profile_batches => [
					@{ $prev_last_profile_batch->profile_batches() },
					$profile_task->$_clone(
						starting_cluster_lists => [ @{ $profile_task->starting_cluster_lists() }[ 0 .. ( $num_in_fillup_batch - 1 ) ] ],
					)
				]
			);
	}

	my $num_remaining_profiles = $num_new_profiles - $num_in_fillup_batch;
	my $num_remaining_batches  = (    int( $num_remaining_profiles / $self->profile_batch_size() )
	                               + ( ( ( $num_remaining_profiles % $self->profile_batch_size() ) > 0 ) ? 1 : 0 ) );
	for (my $batch_ctr = 0; $batch_ctr < $num_remaining_batches; ++$batch_ctr) {
		my $batch_begin_index        =      $num_in_fillup_batch + (   $batch_ctr       * $self->profile_batch_size() );
		my $batch_one_past_end_index = min( $num_in_fillup_batch + ( ( $batch_ctr + 1 ) * $self->profile_batch_size() ), $num_new_profiles );
		push
			@{ $profile_batches },

			Cath::Gemma::Compute::WorkBatch->new(
				profile_batches => [
					$profile_task->$_clone(
						starting_cluster_lists => [ @{ $profile_task->starting_cluster_lists() }[ $batch_begin_index .. ( $batch_one_past_end_index - 1 ) ] ],
					),
				]
			);
	}
}

# =head2 add_profile_scan_work

# =cut

# sub add_profile_scan_work {
# 	state $check = compile( Object, CathGemmaComputeProfileScanTask );
# 	my ( $self, $profile_task ) = $check->( @ARG );

# 	my $num_new_profiles = $profile_task->num_profiles();

# 	my $profile_batches = $self->profile_batches();

# 	my $num_profiles_in_new_task = $profile_task->num_profiles();

# 	my $num_free_profiles_in_last_batch =
# 		( scalar( @$profile_batches ) > 0 )
# 		? $self->profile_batch_size() - $profile_batches->[ -1 ]->num_profiles()
# 		: 0;

# 	if ( scalar( @$profile_batches ) > 0 ) {
# 		my @bob = map { $ARG->num_profiles(); } @$profile_batches;
# 	}

# 	my $num_in_fillup_batch = min( $num_free_profiles_in_last_batch, $num_new_profiles );

# 	if ( $num_in_fillup_batch > 0 ) {
# 		my $prev_last_profile_batch = pop @$profile_batches;
# 		push
# 			@{ $profile_batches },
# 			Cath::Gemma::Compute::WorkBatch->new(
# 				profile_batches => [
# 					@{ $prev_last_profile_batch->profile_batches() },
# 					Cath::Gemma::Compute::ProfileBuildTask->new(
# 						starting_cluster_lists => [ @{ $profile_task->starting_cluster_lists() }[ 0 .. ( $num_in_fillup_batch - 1 ) ] ],
# 						dir_set                => $profile_task->dir_set(),
# 					)
# 				]
# 			);
# 	}

# 	my $num_remaining_profiles = $num_new_profiles - $num_in_fillup_batch;
# 	my $num_remaining_batches  = (    int( $num_remaining_profiles / $self->profile_batch_size() )
# 	                               + ( ( ( $num_remaining_profiles % $self->profile_batch_size() ) > 0 ) ? 1 : 0 ) );
# 	for (my $batch_ctr = 0; $batch_ctr < $num_remaining_batches; ++$batch_ctr) {
# 		my $batch_begin_index        =      $num_in_fillup_batch + (   $batch_ctr       * $self->profile_batch_size() );
# 		my $batch_one_past_end_index = min( $num_in_fillup_batch + ( ( $batch_ctr + 1 ) * $self->profile_batch_size() ), $num_new_profiles );
# 		push
# 			@{ $profile_batches },

# 			Cath::Gemma::Compute::WorkBatch->new(
# 				profile_batches => [
# 					Cath::Gemma::Compute::ProfileBuildTask->new(
# 						starting_cluster_lists => [ @{ $profile_task->starting_cluster_lists() }[ $batch_begin_index .. ( $batch_one_past_end_index - 1 ) ] ],
# 						dir_set                => $profile_task->dir_set(),
# 					),
# 				]
# 			);
# 	}
# }

=head2 submit_to_compute_cluster

=cut

sub submit_to_compute_cluster {
	state $check = compile( Object, Path );
	my ( $self, $job_dir ) = $check->( @ARG );

	if ( ! -d $job_dir ) {
		$job_dir->mkpath()
			or confess "Unable to make compute cluster submit directory \"$job_dir\" : $OS_ERROR";
	}

	my $id = $self->id();

	my @profile_batch_files;
	foreach my $profile_batch ( @{ $self->profile_batches() } ) {
		my $work_freeze_file = $job_dir->child( $id . '.' . 'batch_' . $profile_batch->id() . '.freeze' );
		$work_freeze_file->spew( freeze( $profile_batch ) );
		push @profile_batch_files, "$work_freeze_file";
	}

	my $batch_files_file = $job_dir->child( $id . '.' . 'job_batch_files' );
	$batch_files_file->spew( join( "\n", @profile_batch_files ) . "\n" );

	my $execute_batch_script = path( "$FindBin::Bin" )->child( 'execute_work_batch.pl' ) . "";

	my $num_batches = scalar( @{ $self->profile_batches() } );

	my $submit_script = $job_dir->child( $id . '.' . 'job_script.bash' );
	$submit_script->spew( <<"EOF" );
#!/bin/bash -l

# Where a compute-cluster provides a more recent perl through the module system, this will pick it up
( ( module avail perl ) 2>&1 | grep -q perl ) && module load perl

BATCH_FILES_FILE=$batch_files_file
echo BATCH_FILES_FILE : \$BATCH_FILES_FILE
echo SGE_TASK_ID      : \$SGE_TASK_ID

BATCH_FILE=\$(awk "NR==\$SGE_TASK_ID" \$BATCH_FILES_FILE)
echo BATCH_FILE       : \$BATCH_FILE

$execute_batch_script \$BATCH_FILE

EOF

	$submit_script->chmod( 'a+x' )
		or confess "Unable to chmod submit script \"$submit_script\" to be executable : $OS_ERROR";

	my $submit_host = ( defined( $ENV{SGE_CLUSTER_NAME} ) && $ENV{SGE_CLUSTER_NAME} =~ /leg/i )
	                  ? 'legion.rc.ucl.ac.uk'
	                  : 'bchuckle.cs.ucl.ac.uk';

	my $stderr_file_stem   = $job_dir->child( $id );
	my $stdout_file_stem   = $job_dir->child( $id );
	my $stderr_file_suffix = '.stderr';
	my $stdout_file_suffix = '.stdout';

	my @qsub_command = (
		'ssh', $submit_host,
		'qsub',
		'-l', 'vf=1G,h_vmem=1G,h_rt=00:30:00',
		'-N', 'CathGemma'.$id,
		'-e', $stderr_file_stem . '.job_\$JOB_ID.task_\$TASK_ID' . $stderr_file_suffix,
		'-o', $stdout_file_stem . '.job_\$JOB_ID.task_\$TASK_ID' . $stdout_file_suffix,
		'-v', 'PATH', # Ensure that the PATH is passed through to the job (so that, in particular, it picks up the right Perl)
		#'-v', 'PATH=/share/apps/perl/bin:$PATH', # Ensure that the shared Perl is used on the CS cluster (with login node "bchuckle")
		'-S', '/bin/bash',
		'-t', '1-'.$num_batches,
		"$submit_script",
		# -hold_jid
		# -hold_jid_ad
	);

	my ( $qsub_stdout, $qsub_stderr, $qsub_exit ) = capture {
		system( @qsub_command );
	};


	my $job_id;
	if ( $qsub_stdout =~ /Your job-array (\d+)\.\d+\-\d+:\d+.* has been submitted/ ) {
		$job_id = $1;
	}
	else {
		use Data::Dumper;
		confess Dumper( [ \@qsub_command, $qsub_stdout, $qsub_stderr, $qsub_exit ] );
	}
	INFO "Submitted compute-cluster job $job_id with $num_batches batches";

	return $job_id;

	# warn "$job_dir";

	# # $job_dir;

	# # my $submit_script        = $job_dir->child();
	# # my $work_batch_file_list = $job_dir->child();

	# my $script = Path::Tiny->tempfile( DIR => $tmp_dir, TEMPLATE => '.compass_dummy.XXXXXXXXXXX', SUFFIX => alignment_profile_suffix(), CLEANUP => 1 );
	# my $tmp_dummy_aln_file = Path::Tiny->tempfile( DIR => $tmp_dir, TEMPLATE => '.compass_dummy.XXXXXXXXXXX', SUFFIX => alignment_profile_suffix(), CLEANUP => 1 );
	# my 
	# $job_dir->child( 'job.' );

}

1;
