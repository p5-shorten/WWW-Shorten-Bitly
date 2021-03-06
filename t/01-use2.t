#!perl

use strict;
use warnings;
use Test::More;

BEGIN { use_ok('WWW::Shorten', 'Bitly') or BAIL_OUT("Can't use module"); }

can_ok('main', qw(makealongerlink makeashorterlink));
can_ok('WWW::Shorten::Bitly', qw(access_token client_id client_secret));
can_ok('WWW::Shorten::Bitly', qw(password username));

done_testing();
