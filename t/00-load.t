#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'WWW::Shorten::Bitly' );
}

diag( "Testing WWW::Shorten::Bitly $WWW::Shorten::Bitly::VERSION, Perl $], $^X" );
