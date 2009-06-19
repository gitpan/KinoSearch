# This file is used by the test_valgrind build target to generate a list of
# suppressions.
use strict;
use warnings;
use Time::HiRes;
use Lingua::Stem::Snowball;    # triggers XSLoader/DynaLoader

