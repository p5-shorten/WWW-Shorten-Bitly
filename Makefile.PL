use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'WWW::Shorten::Bitly',
    AUTHOR              => 'Pankaj Jain <pjain@cpan.org>',
    VERSION_FROM        => 'lib/WWW/Shorten/Bitly.pm',
    ABSTRACT_FROM       => 'lib/WWW/Shorten/Bitly.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'   => 0,
        'WWW::Shorten' => 1.90,
        'XML::Simple'  => 2.18,
        'JSON::Any'    => 1.18
    },
    PREREQ_PRINT        => 1,
    EXE_FILES           => ['bin/bitly_url'],
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-Shorten-Bitly-*' },
);
