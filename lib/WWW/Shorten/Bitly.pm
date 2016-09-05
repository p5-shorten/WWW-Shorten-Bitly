package WWW::Shorten::Bitly;

use warnings;
use strict;
use base qw( WWW::Shorten::generic Exporter );
our $VERSION = '1.200';
$VERSION = eval $VERSION;

use Carp ();
use File::Spec ();
use JSON::MaybeXS ();

our @EXPORT = qw(new version);


use constant BASE_JMP => 'http://api.j.mp';
use constant BASE_BLY => 'http://api.bitly.com';

sub new {
    my ($class) = shift;
    my %args = @_;
    $args{source} ||= "perlteknatusbitly";
    $args{jmp} ||= 0;

    my $bitlyrc = $^O =~/Win32/i ? File::Spec->catfile($ENV{HOME}, "_bitly") : File::Spec->catfile($ENV{HOME}, ".bitly");
    if (-r $bitlyrc){
        open my $fh, "<", $bitlyrc or die "can't open .bitly file $!";
        while(<$fh>){
            $args{USER} ||= $1 if m{^USER=(.*)};
            $args{APIKEY} ||= $1 if m{^APIKEY=(.*)};
        }
        close $fh;
    }
    if (!defined $args{USER} || !defined $args{APIKEY}) {
        carp("USER and APIKEY are both required parameters.\n");
        return -1;
    }
    my $bitly;
    $bitly->{USER} = $args{USER};
    $bitly->{APIKEY} = $args{APIKEY};
    if ($args{jmp} == 1) {
        $bitly->{BASE} = BASE_JMP;
    } else {
        $bitly->{BASE} = BASE_BLY;
    }
    $bitly->{json} = JSON::Any->new;
    $bitly->{browser} = LWP::UserAgent->new(agent => $args{source});
    $bitly->{xml} = new XML::Simple(SuppressEmpty => 1);
    my ($self) = $bitly;
    bless $self, $class;
}

sub bitly_pro_domain {
    my $self = shift;
    my %args = @_;
    $self->{USER} ||= $args{user};
    $self->{APIKEY} ||= $args{apikey};
    if ($args{url} !~ /bit\.ly/ || $args{url} !~ /j\.mp/) {
        my @foo = split(/\//, $args{url});
        my $domain = $foo[2];
        $self->{response} = $self->{browser}->get($self->{BASE} . '/v3/bitly_pro_domain?domain=' . $domain . '&login=' . $self->{USER} . '&apiKey=' . $self->{APIKEY});
        $self->{response}->is_success || die 'Failed to get bitly.com link: ' . $self->{response}->status_line;
        $self->{$args{url}}->{content} = $self->{json}->jsonToObj($self->{response}->{_content});
        if ($self->{$args{url}}->{content}->{status_code} == 200 ) {
            $self->{$args{url}}->{bitly_pro_domain} = $self->{$args{url}}->{content}->{data}->{bitly_pro_domain};
            return $self->{$args{url}}->{bitly_pro_domain};
        } else {
            return;
        }
    } else {
        return 1;
    }
}

sub clicks {
    my $self = shift;
    $self->{response} = $self->{browser}->get($self->{BASE} . '/v3/clicks?shortUrl=' . $self->{bitlyurl} . '&login=' . $self->{USER} . '&apiKey=' . $self->{APIKEY});
    $self->{response}->is_success || die 'Failed to get bitly.com link: ' . $self->{response}->status_line;
    $self->{$self->{bitlyurl}}->{content} = $self->{json}->jsonToObj($self->{response}->{_content});

    if ($self->{$self->{bitlyurl}}->{content}->{status_code} == 200 ) {
        $self->{$self->{bitlyurl}}->{clicks} = $self->{$self->{bitlyurl}}->{content}->{data}->{clicks}[0];
        return $self->{$self->{bitlyurl}}->{clicks};
    } else {
        return;
    }
}

sub clicks_by_day {
    my $self = shift;
    $self->{response} = $self->{browser}->get($self->{BASE} . '/v3/clicks_by_day?shortUrl=' . $self->{bitlyurl} . '&login=' . $self->{USER} . '&apiKey=' . $self->{APIKEY});
    $self->{response}->is_success || die 'Failed to get bitly.com link: ' . $self->{response}->status_line;
    $self->{$self->{bitlyurl}}->{content} = $self->{json}->jsonToObj($self->{response}->{_content});
    if ($self->{$self->{bitlyurl}}->{content}->{status_code} == 200 ) {
        $self->{$self->{bitlyurl}}->{clicks_by_day} = $self->{$self->{bitlyurl}}->{content}->{data}->{clicks_by_day}[0]->{clicks};
        return $self->{$self->{bitlyurl}}->{clicks_by_day};
    } else {
        return;
    }
}

sub countries {
    my $self = shift;
    $self->{response} = $self->{browser}->get($self->{BASE} . '/v3/countries?shortUrl=' . $self->{bitlyurl} . '&login=' . $self->{USER} . '&apiKey=' . $self->{APIKEY});
    $self->{response}->is_success || die 'Failed to get bitly.com link: ' . $self->{response}->status_line;
    $self->{$self->{bitlyurl}}->{content} = $self->{json}->jsonToObj($self->{response}->{_content});
    if ($self->{$self->{bitlyurl}}->{content}->{status_code} == 200 ) {
        $self->{$self->{bitlyurl}}->{countries} = $self->{$self->{bitlyurl}}->{content}->{data}->{countries};
        return $self->{$self->{bitlyurl}}->{countries};
    } else {
        return;
    }
}

sub errors {
    my $self = shift;
    warn "errors - deprecated from BitLy API. It will no longer be supported" if (1.14 > $WWW::Shorten::Bitly::VERSION);
    return;
    $self->{response} = $self->{browser}->post($self->{BASE} . '/v3/errors', [
        'version' => '3.0.0',
        'login'   => $self->{USER},
        'apiKey'  => $self->{APIKEY},
    ]);
    $self->{response}->is_success || die 'Failed to get bitly.com link: ' . $self->{response}->status_line;
    $self->{$self->{bitlyurl}}->{content} = $self->{xml}->XMLin($self->{response}->{_content});
    $self->{$self->{bitlyurl}}->{errorCode} = $self->{$self->{bitlyurl}}->{content}->{status_txt};
    if ($self->{$self->{bitlyurl}}->{status_code} == 200 ) {
        $self->{$self->{bitlyurl}}->{clicks} = $self->{$self->{bitlyurl}}->{content}->{results};
        return $self->{$self->{bitlyurl}}->{clicks};
    } else {
        return;
    }
}

sub expand {
    my $self = shift;
    my %args = @_;
    if (!defined $args{URL}) {
        croak("URL is required.\n");
        return -1;
    }
    $self->{response} = $self->{browser}->post($self->{BASE} . '/v3/expand', [
        'history'  => '1',
        'version'  => '3.0.0',
        'shortUrl' => $args{URL},
        'login'    => $self->{USER},
        'apiKey'   => $self->{APIKEY},
    ]);
    $self->{response}->is_success || die 'Failed to get bitly.com link: ' . $self->{response}->status_line;
    return undef if ( $self->{json}->jsonToObj($self->{response}->{_content})->{status_code} != 200 );
    $self->{longurl} = $self->{json}->jsonToObj($self->{response}->{_content})->{data}->{expand}[0]->{long_url};
    return $self->{longurl} if ( $self->{json}->jsonToObj($self->{response}->{_content})->{status_code} == 200 );
}

sub info {
    my $self = shift;
    $self->{response} = $self->{browser}->get($self->{BASE} . '/v3/info?shortUrl=' . $self->{bitlyurl} . '&login=' . $self->{USER} . '&apiKey=' . $self->{APIKEY});
    $self->{response}->is_success || die 'Failed to get bitly.com link: ' . $self->{response}->status_line;
    $self->{$self->{bitlyurl}}->{content} = $self->{json}->jsonToObj($self->{response}->{_content});
    if ($self->{$self->{bitlyurl}}->{content}->{status_code} == 200 ) {
        $self->{$self->{bitlyurl}}->{info} = $self->{$self->{bitlyurl}}->{content}->{data}->{info}[0];
        return $self->{$self->{bitlyurl}}->{info};
    } else {
        return;
    }
}

sub lookup {
    my $self = shift;
}

sub makeashorterlink {
    my $url = shift or croak('No URL passed to makeashorterlink');
    my ($user, $apikey) = @_ or croak('No username or apikey passed to makeshorterlink');
    if (!defined $url || !defined $user || !defined $apikey ) {
        croak("url, user and apikey are required for shortening a URL with bitly.com - in that specific order");
        &help();
    }
    my $ua = __PACKAGE__->ua();
    my $bitly;
    $bitly->{json} = JSON::Any->new;
    $bitly->{xml} = new XML::Simple(SuppressEmpty => 1);
    my $biturl = BASE_BLY . '/v3/shorten';
    $bitly->{response} = $ua->post($biturl, [
        'format'  => 'json',
        'history' => '1',
        'version' => '3.0.0',
        'longUrl' => $url,
        'login' => $user,
        'apiKey' => $apikey,
    ]);
    $bitly->{response}->is_success || die 'Failed to get bitly.com link: ' . $bitly->{response}->status_line;
    $bitly->{bitlyurl} = $bitly->{json}->jsonToObj($bitly->{response}->{_content})->{data}->{url};
    return unless $bitly->{response}->is_success;
    return $bitly->{bitlyurl};
}

sub makealongerlink {
    my $url = shift or croak('No shortened bitly.com URL passed to makealongerlink');
    my ($user, $apikey) = @_ or croak('No username or apikey passed to makealongerlink');
    my $ua = __PACKAGE__->ua();
    my $bitly;
    my @foo = split(/\//, $url);
    $bitly->{json} = JSON::Any->new;
    $bitly->{xml} = new XML::Simple(SuppressEmpty => 1);
    $bitly->{response} = $ua->post(BASE_BLY . '/v3/expand', [
        'version'  => '3.0.0',
        'shortUrl' => $url,
        'login' => $user,
        'apiKey' => $apikey,
    ]);
    $bitly->{response}->is_success || die 'Failed to get bitly.com link: ' . $bitly->{response}->status_line;
    $bitly->{longurl} = $bitly->{json}->jsonToObj($bitly->{response}->{_content})->{data}->{long_url};
    return undef unless $bitly->{response}->is_success;
    my $content = $bitly->{response}->content;
    return $bitly->{longurl};
}

sub qr_code {
    my $self = shift;
    my %args = @_;
    $self->{bitlyurl} ||= $args{shorturl};
    return $self->{bitlyurl} . '.qrcode';
}

sub referrers {
    my $self = shift;
    $self->{response} = $self->{browser}->get($self->{BASE} . '/v3/referrers?shortUrl=' . $self->{bitlyurl} . '&login=' . $self->{USER} . '&apiKey=' . $self->{APIKEY});
    $self->{response}->is_success || die 'Failed to get bitly.com link: ' . $self->{response}->status_line;
    $self->{$self->{bitlyurl}}->{content} = $self->{json}->jsonToObj($self->{response}->{_content});
    if ($self->{$self->{bitlyurl}}->{content}->{status_code} == 200 ) {
        $self->{$self->{bitlyurl}}->{referrers} = $self->{$self->{bitlyurl}}->{content}->{data}->{referrers};
        return $self->{$self->{bitlyurl}}->{referrers};
    } else {
        return;
    }
}

sub shorten {
    my $self = shift;
    my %args = @_;
    if (!defined $args{URL}) {
        croak("URL is required.\n");
        return -1;
    }
    $self->{response} = $self->{browser}->post($self->{BASE} . '/v3/shorten', [
        'history' => '1',
        'version' => '3.0.0',
        'longUrl' => $args{URL},
        'login' => $self->{USER},
        'apiKey' => $self->{APIKEY},
    ]);
    $self->{response}->is_success || die 'Failed to get bitly.com link: ' . $self->{response}->status_line;
    return undef if ( $self->{json}->jsonToObj($self->{response}->{_content})->{status_code} != 200 );
    $self->{bitlyurl} = $self->{json}->jsonToObj($self->{response}->{_content})->{data}->{url};
    return $self->{bitlyurl} if ( $self->{json}->jsonToObj($self->{response}->{_content})->{status_code} == 200 );
}

sub validate {
    my $self = shift;
    my %args = @_;
    $self->{USER} ||= $args{user};
    $self->{APIKEY} ||= $args{apikey};

    $self->{response} = $self->{browser}->get($self->{BASE} . '/v3/validate?x_login=' . $self->{USER} . '&x_apiKey=' . $self->{APIKEY}. '&login=' . $self->{USER} . '&apiKey=' . $self->{APIKEY});
    $self->{response}->is_success || die 'Failed to get bitly.com link: ' . $self->{response}->status_line;
    $self->{$self->{USER}}->{content} = $self->{json}->jsonToObj($self->{response}->{_content});
    if ($self->{json}->jsonToObj($self->{response}->{_content})->{data}->{valid} == 1) {
        $self->{$self->{USER}}->{valid} = $self->{$self->{USER}}->{content}->{data}->{valid};
            return $self->{$self->{USER}}->{valid};
    } else {
        return;
    }
}

sub version {
    my $self = shift;
    my($version) = shift;# not sure why $version isn't being set. need to look at it
    warn "Version $version is later then $WWW::Shorten::Bitly::VERSION. It may not be supported" if (defined ($version) && ($version > $WWW::Shorten::Bitly::VERSION));
    return $WWW::Shorten::Bitly::VERSION;
}

1; # End of WWW::Shorten::Bitly
__END__

=head1 NAME

WWW::Shorten::Bitly - Interface to shortening URLs using L<http://bitly.com>

=head1 SYNOPSIS

L<WWW::Shorten::Bitly> provides an easy interface for shortening URLs using
L<http://bitly.com>. In addition to shortening URLs, you can pull statistics
that L<http://bitly.com> gathers regarding each shortened URL.

L<WWW::Shorten::Bitly> provides two interfaces. The first is the common
C<makeashorterlink> and C<makealongerlink> that L<WWW::Shorten> provides.
However, due to the way the L<http://bitly.com> API works, additional arguments
are required. The second provides a better way of retrieving additional
information and statistics about a L<http://bitly.com> URL.

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

Please remember to check out C<http://code.google.com/p/bitly-api/wiki/ApiDocumentation#/v3/info> for more details on V3 of the Bitly.com API

=head1 FUNCTIONS

=head2 new

Create a new object instance using your L<http://bitly.com> user id and API key.

    my $bitly = WWW::Shorten::Bitly->new(
        URL => "http://www.example.com/this_is_one_example.html",
        USER => "bitly_user_id",
        APIKEY => "bitly_api_key"
    );

To use L<http://bitly.com>'s new L<http://j.mp> service, just construct the
instance like this:

    my $bitly = WWW::Shorten::Bitly->new(
        URL => "http://www.example.com/this_is_one_example.html",
        USER => "bitly_user_id",
        APIKEY => "bitly_api_key",
        jmp => 1
    );

=head2 makeashorterlink

The function C<makeashorterlink> will call the L<http://bitly.com> web site,
passing it your long URL and will return the shorter version.

L<http://bitly.com> requires the use of a user id and API key to shorten links.

=head2 makealongerlink

The function C<makealongerlink> does the reverse. C<makealongerlink>
will accept as an argument either the full URL or just the identifier.

If anything goes wrong, either function will return C<undef>.

=head2 shorten

Shorten a URL using L<http://bitly.com>. Calling the C<shorten> method will
return the shorter URL, but will also store it in this instance until the next
call is made.

    my $url = "http://www.example.com";
    my $shortstuff = $bitly->shorten(URL => $url);

    print "biturl is " . $bitly->{bitlyurl} . "\n";

or

    print "biturl is $shortstuff\n";

=head2 expand

Expands a shorter URL to the original long URL.

=head2 info

Get info about a shorter URL. By default, the method will use the value that's
stored in C<< $bitly->{bitlyurl} >>. To be sure you're getting info on the correct
URL, it's a good idea to set this value before getting any info on it.

    $bitly->{bitlyurl} = "http://bitly.com/jmv6";
    my $info = $bitly->info();

    say "Title of the page is " . $info->{title};
    say "Created by " . $info->{created_by};

=head2 clicks

Get click-thru information for a shorter URL. By default, the method will use
the value that's stored in C<< $bitly->{bitlyurl} >>. To be sure you're getting
info on the correct URL, it's a good idea to set this value before getting
any info on it.

    $bitly->{bitlyurl} = "http://bitly.com/jmv6";
    my $clicks = $bitly->clicks();

    say "Total number of clicks received: " . $clicks->{user_clicks};
    say "Total number of global clicks received are: " . $clicks->{global_clicks};

=head2 errors

=head2 version

Gets the module version number

=head2 referrers

Returns an array of hashes

    my @ref = $bitly->referrers();
    say "Referrers for " . $bitly->{bitlyurl};
    foreach my $r (@ref) {
        foreach my $f (@{$r}) {
            say $f->{clicks} . ' from ' . $f->{referrer};
        }
    }

=head2 countries

Returns an array of hashes

    my @countries = $bitly->countries();
    foreach my $r (@countries) {
        foreach my $f (@{$r}) {
            say $f->{clicks} . ' from ' . $f->{country};
        }
    }

=head2 clicks_by_day

Returns an array of hashes

    my @c = $bitly->clicks_by_day();
    say "Clicks by Day for " . $bitly->{bitlyurl};
    foreach my $r (@c) {
        foreach my $f (@{$r}) {
            say $f->{clicks} . ' on ' . $f->{day_start};
        }
    }

C<day_start> is the time code as specified by L<http://bitly.com>. You can use
the following to turn it into a L<DateTime> object:

    use DateTime;
    $dt = DateTime->from_epoch( epoch => $epoch );


=head2 qr_code

Returns the URL for the QR Code

=head2 validate

For any given a L<http://bitly.com> user login and API key, you can validate that the pair is active.

=head2 bitly_pro_domain

Will return true or false whether the URL specified is a L<http://bitly.com> Pro Domain

    my $bpd = $bitly->bitly_pro_domain(url => 'http://nyti.ms');
    say "This is a Bitly Pro Domain: " . $bpd;

    my $bpd2 = $bitly->bitly_pro_domain(url => 'http://example.com');
    say "This is a Bitly Pro Domain: " . $bpd2;

=head2 lookup

=head2 clicks_by_minute

This part of the L<http://bitly.com> API isn't being implemented because it's
virtually impossible to know exactly which minute a clicks is attributed to.
Ya know, network lag, etc. I'll implement this when Bitly puts some sort of a
time code into the results.

=cut

=head1 FILES

C<$HOME/.bitly> or C<_bitly> on Windows Systems.

You may omit C<USER> and C<APIKEY> in the constructor if you set them in the
config file on separate lines using the syntax:

    USER=username
    APIKEY=apikey

=head1 AUTHOR

Pankaj Jain <F<pjain@cpan.org>>

=head1 CONTRIBUTORS

=over

=item *

Chase Whitener <F<capoeirab@cpan.org>>

=item *

Joerg Meltzer <F<joerg@joergmeltzer.de>>

=item *

Mizar <F<mizar.jp@gmail.com>>

=item *

Peter Edwards <F<pedwards@cpan.org>>

=item *

Thai Thanh Nguyen <F<thai@thaiandhien.com>>

=back


=head1 COPYRIGHT & LICENSE

Copyright (c) 2009 Pankaj Jain, All Rights Reserved L<http://blog.pjain.me>.

Copyright (c) 2009 Teknatus Solutions LLC, All Rights Reserved L<http://teknatus.com>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
