use 5.008003;
use strict;
use warnings;

my $conflict = 0;
my $existing;

BEGIN {
    eval 'use KinoSearch;';
    if ( !$@ ) {
        $existing = eval $KinoSearch::VERSION;
        if ( $existing < 0.20 ) {
            $conflict = 1;
        }
    }
}

use lib 'buildlib';
use KinoSearch::Build;
use File::Spec::Functions qw( curdir );

if ( $conflict and !$ENV{KINO_DEBUG} ) {
    print <<END_WARNING;

*** WARNING ***
An existing installation of KinoSearch version $existing has been detected.
This release breaks backwards compatibility with versions of KinoSearch prior
to 0.20.  Both the file format and the API have changed.

END_WARNING

    my $response = Module::Build->y_n("Continue? (y/n) ");
    exit unless $response;
}

my $builder = KinoSearch::Build->new(
    module_name       => 'KinoSearch',
    license           => 'perl',
    dist_author       => 'Marvin Humphrey <marvin at rectangular dot com>',
    dist_version_from => 'lib/KinoSearch.pm',
    requires          => {
        'Compress::Zlib'         => 0,
        'Lingua::Stem::Snowball' => 0.94,
        'Lingua::StopWords'      => 0.06,
        'HTML::Parser'           => 3,
    },
    build_requires => {
        'ExtUtils::CBuilder' => 0,
        'ExtUtils::ParseXS'  => 0,
    },
    create_makefile_pl => 'passthrough',
    add_to_cleanup     => [ 'MANIFEST.bak', 'perltidy.ERR', ],
);

$builder->create_build_script();
