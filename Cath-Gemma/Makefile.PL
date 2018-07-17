use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Cath::Gemma',
    AUTHOR              => q{Tony E Lewis <a@b.com>},
    VERSION_FROM        => 'lib/Cath/Gemma.pm',
    ABSTRACT_FROM       => 'lib/Cath/Gemma.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Array::Utils'            => 0,
        'Bio::SeqIO'              => 0,
        'Capture::Tiny'           => 0,
        'Cwd::Guard'              => 0,
        'File::AtomicWrite'       => 0,
        'File::chdir'             => 0,
        'File::Which'             => 0,
        'JSON::MaybeXS'           => 0,
        'List::MoreUtils'         => 0,
        'List::UtilsBy'           => 0,
        'Log::Log4perl::Tiny'     => 0,
        'Moo'                     => 0,
        'MooX::HandlesVia'        => 0,
        'MooX::StrictConstructor' => 0,
        'Object::Util'            => 0,
        'Parallel::Iterator'      => 0,
        'Path::Tiny'              => '0.106',
        'Role::Singleton'         => 0,
        'Switch'                  => 0,
        'Thread::Pool::Simple'    => 0,
        'Try::Tiny'               => 0,
        'Type::Tiny'              => 0,
        'Types::Path::Tiny'       => 0,
    },
    TEST_REQUIRES => {
        'Test::Differences'       => 0,
        'Test::Exception'         => 0,
        'Test::Files'             => 0,
        'Test::More'              => 0,
        'Test::Pod'               => 0,
        'Test::Pod::Coverage'     => 0,
        'Test::Trap'              => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Cath-Gemma-*' },
);
