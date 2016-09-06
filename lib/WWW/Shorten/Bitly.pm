package WWW::Shorten::Bitly;

use warnings;
use strict;
use Carp ();
use File::Spec ();
use File::HomeDir ();
use JSON::MaybeXS ();
use Path::Tiny qw(path);
use Scalar::Util qw(blessed);
use URI ();

use base qw( WWW::Shorten::generic Exporter );
our @EXPORT = qw(new version);
our $VERSION = '1.200';
$VERSION = eval $VERSION;

use constant BASE_BLY => 'https://api.bitly.com';

# _attr (static)
sub _attr {
    my $self = shift;
    my $attr = lc(_trim(shift) || '');
    # attribute list is small enough to just grep each time. meh.
    Carp::croak("Invalid attribute") unless grep {$attr eq $_} @{_attrs()};
    return $self->{$attr} unless @_;
    # unset the access_token if any other field is set
    # this ensures we're always connecting properly.
    $self->{access_token} = undef;
    my $val = shift;
    unless (defined($val)) {
        $self->{$attr} = undef;
        return $self;
    }

    if ($attr eq 'base_url') {
        # coerce to URI
        $val = (blessed($val) && $val->isa('URI'))? $val: URI->new($val);
        #warn "Setting $attr to ". ($val || 'undef');
        $self->{$attr} = $val;
    }
    else {
        # all others are string values
        $val = (ref($val))? undef: $val;
        $self->{$attr} = $val;
    }
    return $self;
}

# _attrs (static, private)
{
    my $attrs; # mimic the state keyword
    sub _attrs {
        return $attrs if $attrs;
        $attrs = [
            qw(username password access_token client_id client_secret),
            qw(base_url),
        ];
        return $attrs;
    }
}

# _parse_config (static, private)
{
    my $config; # mimic the state keyword
    sub _parse_config {
        return $config if $config;
        # only parse the file once, please.
        $config = {};
        my $file = $^O eq 'MSWin32'? '_bitly': '.bitly';
        my $path = path(File::Spec->catfile(File::HomeDir->my_home(), $file));

        if ($path && $path->is_file) {
            my @lines = $path->lines_utf8({chomp => 1});
            my $attrs = _attrs();

            for my $line (@lines) {
                $line = _trim($line) || '';
                next if $line =~ /^\s*[;#]/; # skip comments
                $line =~ s/\s+[;#].*$//gm; # trim off comments
                next unless $line && $line =~ /=/; # make sure we have a =

                my ($key, $val) = split(/(?<![^\\]\\)=/, $line, 2);
                $key = lc(_trim($key) || '');
                $val = _trim($val);
                next unless $key && $val;
                $key = 'username' if $key eq 'user';
                next unless grep {$key eq $_} @{$attrs};
                $config->{$key} = $val;
            }
        }
        return $config;
    }
}

# _trim (private)
sub _trim {
    my $input = shift;
    return $input unless defined $input && !ref($input) && length($input);
    $input =~ s/\A\s*//;
    $input =~ s/\s*\z//;
    return $input;
}

sub new {
    my $class = shift;
    my $args;
    if ( @_ == 1 && ref $_[0] ) {
        my %copy = eval { %{ $_[0] } }; # try shallow copy
        Carp::croak("Argument to $class->new() could not be dereferenced as a hash") if $@;
        $args = \%copy;
    }
    elsif ( @_ % 2 == 0 ) {
        $args = {@_};
    }
    else {
        Carp::croak("$class->new() got an odd number of elements");
    }

    my $attrs = _attrs();
    # start with what's in our config file (if anything)
    my $href = _parse_config();
    # override with anything passed in
    for my $key (%{$args}) {
        my $lc_key = lc($key);
        $lc_key = 'username' if $lc_key eq 'user';
        next unless grep {$lc_key eq $_} @{$attrs};
        $href->{$lc_key} = $args->{$key};
    }
    $href->{base_url} = URI->new($href->{base_url} // BASE_BLY);
    $href->{source} = $args->{source} || "perlteknatusbitly";
    return bless $href, $class;
}

sub access_token { return shift->_attr('access_token', @_); }

sub base_url { return shift->_attr('base_url', @_); }

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

sub client_id { return shift->_attr('client_id', @_); }

sub client_secret { return shift->_attr('client_secret', @_); }

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

sub password { return shift->_attr('password', @_); }

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

sub username { return shift->_attr('username', @_); }

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

sub version { return $WWW::Shorten::Bitly::VERSION }

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

In the non-OO form, L<WWW::Shorten::Bitly> makes the following functions available.

=head2 makeashorterlink

The function C<makeashorterlink> will call the L<http://bitly.com> web site,
passing it your long URL and will return the shorter version.

L<http://bitly.com> requires the use of a user id and API key to shorten links.

=head2 makealongerlink

The function C<makealongerlink> does the reverse. C<makealongerlink>
will accept as an argument either the full URL or just the identifier.

If anything goes wrong, either function will return C<undef>.

=head1 ATTRIBUTES

In the OO form, each L<WWW::Shorten::Bitly> instance makes the following
attributes available. Please note that changing any attribute will unset the
L<WWW::Shorten::Bitly/access_token> attribute and effectively log you out.

=head2 access_token

    my $token = $bitly->access_token;
    $bitly = $bitly->access_token('some_access_token'); # method chaining

Gets or sets the C<access_token>. If the token is set, then we won't try to login.
You can set this ahead of time if you like, or it will be set on the first method
call or on L<WWW::Shorten::Bitly/login>.

=head2 base_url

    my $url = $bitly->base_url;
    $bitly = $bitly->base_url(
        URI->new('https://api.bitly.com')
    ); # method chaining

Gets or sets the C<base_url>. The default is L<https://api.bitly.com>.

=head2 client_id

    my $id = $bitly->client_id;
    $bitly = $bitly->client_id('some_client_id'); # method chaining

Gets or sets the C<client_id>. This is used in the
L<Resource Owner Credentials Grants|https://dev.bitly.com/authentication.html#resource_owner_credentials>
login method along with the L<WWW::Shorten::Bitly/client_secret> attribute.

=head2 client_secret

    my $secret = $bitly->client_secret;
    $bitly = $bitly->client_secret('some_secret'); # method chaining

Gets or sets the C<client_secret>. This is used in the
L<Resource Owner Credentials Grants|https://dev.bitly.com/authentication.html#resource_owner_credentials>
login method along with the L<WWW::Shorten::Bitly/client_id> attribute.

=head2 password

    my $password = $bitly->password;
    $bitly = $bitly->password('some_secret'); # method chaining

Gets or sets the C<password>. This is used in both the
L<Resource Owner Credentials Grants|https://dev.bitly.com/authentication.html#resource_owner_credentials>
and the
L<HTTP Basic Authentication|https://dev.bitly.com/authentication.html#basicauth>
login methods.

=head2 username

    my $username = $bitly->username;
    $bitly = $bitly->username('my_username'); # method chaining

Gets or sets the C<username>. This is used in both the
L<Resource Owner Credentials Grants|https://dev.bitly.com/authentication.html#resource_owner_credentials>
and the
L<HTTP Basic Authentication|https://dev.bitly.com/authentication.html#basicauth>
login methods.

=head1 METHODS

In the OO form, L<WWW::Shorten::Bitly> makes the following methods available.

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
