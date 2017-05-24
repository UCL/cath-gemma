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
        'Capture::Tiny'       => 0,
        'File::AtomicWrite'   => 0,
        'JSON::MaybeXS'       => 0,
        'List::MoreUtils'     => 0,
        'Log::Log4perl::Tiny' => 0,
        'Moo'                 => 0,
        'MooX::HandlesVia'    => 0,
        'Path::Tiny'          => 0,
        'Try::Tiny'           => 0,
        'Type::Tiny'          => 0,
        'Types::Path::Tiny'   => 0,
    },
    TEST_REQUIRES => {
        'Test::More'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Cath-Gemma-*' },
);
