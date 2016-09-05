#!perl

use strict;
use warnings;
use Test::More;

BEGIN { use_ok('WWW::Shorten', 'Bitly') or BAIL_OUT("Can't use module"); }

can_ok('main', qw(makealongerlink makeashorterlink));

done_testing();
