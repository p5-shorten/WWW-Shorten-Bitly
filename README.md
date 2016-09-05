# NAME

WWW::Shorten::Bitly - Interface to shortening URLs using [http://bitly.com](http://bitly.com)

# SYNOPSIS

[WWW::Shorten::Bitly](https://metacpan.org/pod/WWW::Shorten::Bitly) provides an easy interface for shortening URLs using
[http://bitly.com](http://bitly.com). In addition to shortening URLs, you can pull statistics
that [http://bitly.com](http://bitly.com) gathers regarding each shortened URL.

[WWW::Shorten::Bitly](https://metacpan.org/pod/WWW::Shorten::Bitly) provides two interfaces. The first is the common
`makeashorterlink` and `makealongerlink` that [WWW::Shorten](https://metacpan.org/pod/WWW::Shorten) provides.
However, due to the way the [http://bitly.com](http://bitly.com) API works, additional arguments
are required. The second provides a better way of retrieving additional
information and statistics about a [http://bitly.com](http://bitly.com) URL.

    use WWW::Shorten::Bitly;

    my $url = "http://www.example.com";

    my $tmp = makeashorterlink($url, 'MY_BITLY_USERNAME', 'MY_BITLY_API_KEY');
    my $tmp1 = makealongerlink($tmp, 'MY_BITLY_USERNAME', 'MY_BITLY_API_KEY');

or

    use WWW::Shorten::Bitly;

    my $url = "http://www.example.com";
    my $bitly = WWW::Shorten::Bitly->new(
        URL => $url,
        USER => "my_user_id",
        APIKEY => "my_api_key"
    );

    $bitly->shorten(URL => $url);
    print "shortened URL is $bitly->{bitlyurl}\n";

    $bitly->expand(URL => $bitly->{bitlyurl});
    print "expanded/original URL is $bitly->{longurl}\n";

    my $info = $bitly->info();
    say "Title of the page is " . $info->{title};
    say "Created by " . $info->{created_by};

    my $clicks = $bitly->clicks();
    say "Total number of clicks received: " . $clicks->{user_clicks};
    say "Total number of global clicks received are: " . $clicks->{global_clicks};

Please remember to check out `http://code.google.com/p/bitly-api/wiki/ApiDocumentation#/v3/info` for more details on V3 of the Bitly.com API

# FUNCTIONS

## new

Create a new object instance using your [http://bitly.com](http://bitly.com) user id and API key.

    my $bitly = WWW::Shorten::Bitly->new(
        URL => "http://www.example.com/this_is_one_example.html",
        USER => "bitly_user_id",
        APIKEY => "bitly_api_key"
    );

To use [http://bitly.com](http://bitly.com)'s new [http://j.mp](http://j.mp) service, just construct the
instance like this:

    my $bitly = WWW::Shorten::Bitly->new(
        URL => "http://www.example.com/this_is_one_example.html",
        USER => "bitly_user_id",
        APIKEY => "bitly_api_key",
        jmp => 1
    );

## makeashorterlink

The function `makeashorterlink` will call the [http://bitly.com](http://bitly.com) web site,
passing it your long URL and will return the shorter version.

[http://bitly.com](http://bitly.com) requires the use of a user id and API key to shorten links.

## makealongerlink

The function `makealongerlink` does the reverse. `makealongerlink`
will accept as an argument either the full URL or just the identifier.

If anything goes wrong, either function will return `undef`.

## shorten

Shorten a URL using [http://bitly.com](http://bitly.com). Calling the `shorten` method will
return the shorter URL, but will also store it in this instance until the next
call is made.

    my $url = "http://www.example.com";
    my $shortstuff = $bitly->shorten(URL => $url);

    print "biturl is " . $bitly->{bitlyurl} . "\n";

or

    print "biturl is $shortstuff\n";

## expand

Expands a shorter URL to the original long URL.

## info

Get info about a shorter URL. By default, the method will use the value that's
stored in `$bitly->{bitlyurl}`. To be sure you're getting info on the correct
URL, it's a good idea to set this value before getting any info on it.

    $bitly->{bitlyurl} = "http://bitly.com/jmv6";
    my $info = $bitly->info();

    say "Title of the page is " . $info->{title};
    say "Created by " . $info->{created_by};

## clicks

Get click-thru information for a shorter URL. By default, the method will use
the value that's stored in `$bitly->{bitlyurl}`. To be sure you're getting
info on the correct URL, it's a good idea to set this value before getting
any info on it.

    $bitly->{bitlyurl} = "http://bitly.com/jmv6";
    my $clicks = $bitly->clicks();

    say "Total number of clicks received: " . $clicks->{user_clicks};
    say "Total number of global clicks received are: " . $clicks->{global_clicks};

## errors

## version

Gets the module version number

## referrers

Returns an array of hashes

    my @ref = $bitly->referrers();
    say "Referrers for " . $bitly->{bitlyurl};
    foreach my $r (@ref) {
        foreach my $f (@{$r}) {
            say $f->{clicks} . ' from ' . $f->{referrer};
        }
    }

## countries

Returns an array of hashes

    my @countries = $bitly->countries();
    foreach my $r (@countries) {
        foreach my $f (@{$r}) {
            say $f->{clicks} . ' from ' . $f->{country};
        }
    }

## clicks\_by\_day

Returns an array of hashes

    my @c = $bitly->clicks_by_day();
    say "Clicks by Day for " . $bitly->{bitlyurl};
    foreach my $r (@c) {
        foreach my $f (@{$r}) {
            say $f->{clicks} . ' on ' . $f->{day_start};
        }
    }

`day_start` is the time code as specified by [http://bitly.com](http://bitly.com). You can use
the following to turn it into a [DateTime](https://metacpan.org/pod/DateTime) object:

    use DateTime;
    $dt = DateTime->from_epoch( epoch => $epoch );

## qr\_code

Returns the URL for the QR Code

## validate

For any given a [http://bitly.com](http://bitly.com) user login and API key, you can validate that the pair is active.

## bitly\_pro\_domain

Will return true or false whether the URL specified is a [http://bitly.com](http://bitly.com) Pro Domain

    my $bpd = $bitly->bitly_pro_domain(url => 'http://nyti.ms');
    say "This is a Bitly Pro Domain: " . $bpd;

    my $bpd2 = $bitly->bitly_pro_domain(url => 'http://example.com');
    say "This is a Bitly Pro Domain: " . $bpd2;

## lookup

## clicks\_by\_minute

This part of the [http://bitly.com](http://bitly.com) API isn't being implemented because it's
virtually impossible to know exactly which minute a clicks is attributed to.
Ya know, network lag, etc. I'll implement this when Bitly puts some sort of a
time code into the results.

# FILES

`$HOME/.bitly` or `_bitly` on Windows Systems.

You may omit `USER` and `APIKEY` in the constructor if you set them in the
config file on separate lines using the syntax:

    USER=username
    APIKEY=apikey

# AUTHOR

Pankaj Jain <`pjain@cpan.org`>

# CONTRIBUTORS

- Chase Whitener <`capoeirab@cpan.org`>
- Joerg Meltzer <`joerg@joergmeltzer.de`>
- Mizar <`mizar.jp@gmail.com`>
- Peter Edwards <`pedwards@cpan.org`>
- Thai Thanh Nguyen <`thai@thaiandhien.com`>

# COPYRIGHT & LICENSE

Copyright (c) 2009 Pankaj Jain, All Rights Reserved [http://blog.pjain.me](http://blog.pjain.me).

Copyright (c) 2009 Teknatus Solutions LLC, All Rights Reserved [http://teknatus.com](http://teknatus.com).

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
