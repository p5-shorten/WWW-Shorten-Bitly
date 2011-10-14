# $Id: Bitly.pm 110 2009-03-22 21:04:27Z pankaj $
# $Author: pankaj $
# $Date: 2009-03-23 02:34:27 +0530 (Mon, 23 Mar 2009) $
# Author: <a href=mailto:pjain@cpan.org>Pankaj Jain</a>
################################################################################################################################
package WWW::Shorten::Bitly;

use warnings;
use strict;
use Carp;

use base qw( WWW::Shorten::generic Exporter );
use JSON::Any;

require XML::Simple;
require Exporter;

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(new version);

my @ISA = qw(Exporter);

use vars qw( @ISA @EXPORT );

use constant BASE_JMP => 'http://api.j.mp';
use constant BASE_BLY => 'http://api.bitly.com';

=head1 NAME

WWW::Shorten::Bitly - Interface to shortening URLs using L<http://bitly.com>

=head1 VERSION

$Revision: 1.17 $

=cut

BEGIN {
    our $VERSION = do { my @r = (q$Revision: 1.17 $ =~ /\d+/g); sprintf "%1d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker
    $WWW::Shorten::Bitly::VERBOSITY = 2;
}

# ------------------------------------------------------------


=head1 SYNOPSIS

WWW::Shorten::Bitly provides an easy interface for shortening URLs using http://bitly.com. In addition to shortening URLs, you can pull statistics that bitly.com gathers regarding each shortened
WWW::Shorten::Bitly uses XML::Simple to convert the xml response and JSON::Any to convert JSON responses for the meta info and click stats to create a hashref of the results.

WWW::Shorten::Bitly provides two interfaces. The first is the common C<makeashorterlink> and C<makealongerlink> that WWW::Shorten provides. However, due to the way the bitly.com API works, additional arguments are required. The second provides a better way of retrieving additional information and statistics about a bitly.com URL.

use WWW::Shorten::Bitly;

my $url = "http://www.example.com";

my $tmp = makeashorterlink($url, 'MY_BITLY_USERNAME', 'MY_BITLY_API_KEY');
my $tmp1 = makealongerlink($tmp, 'MY_BITLY_USERNAME', 'MY_BITLY_API_KEY');

or

use WWW::Shorten::Bitly;

my $url = "http://www.example.com";
my $bitly = WWW::Shorten::Bitly->new(URL => $url,
USER => "my_user_id",
APIKEY => "my_api_key");

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

Create a new bitly.com object using your bitly.com user id and bitly.com api key.

my $bitly = WWW::Shorten::Bitly->new(URL => "http://www.example.com/this_is_one_example.html",
USER => "bitly_user_id",
APIKEY => "bitly_api_key");

to use bitly.com's new j.mp service, just construct the bitly object like this:
my $bitly = WWW::Shorten::Bitly->new(URL => "http://www.example.com/this_is_one_example.html",
USER => "bitly_user_id",
APIKEY => "bitly_api_key",
jmp => 1);

=cut

sub new {
    my ($class) = shift;
    my %args = @_;
    $args{source} ||= "perlteknatusbitly";
    $args{jmp} ||= 0;
    use File::Spec;
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


=head2 makeashorterlink

The function C<makeashorterlink> will call the bitly.com API site passing it
your long URL and will return the shorter bitly.com version.

bitly.com requires the use of a user id and API key to shorten links.

j.mp is not currently supported for makeashorterlink

=cut

sub makeashorterlink #($;%)
{
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

=head2 makealongerlink

The function C<makealongerlink> does the reverse. C<makealongerlink>
will accept as an argument either the full bitly.com URL or just the
bitly.com identifier. bitly.com requires the use of a user name and API
Key when using the API.

If anything goes wrong, then the function will return C<undef>.

j.mp is not currently supported for makealongerlink

=cut

sub makealongerlink #($,%)
{
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
# return undef if $content eq 'ERROR';
    return $bitly->{longurl};
}

=head2 shorten

Shorten a URL using http://bitly.com. Calling the shorten method will return the shortened URL but will also store it in bitly.com object until the next call is made.

my $url = "http://www.example.com";
my $shortstuff = $bitly->shorten(URL => $url);

print "biturl is " . $bitly->{bitlyurl} . "\n";
or
print "biturl is $shortstuff\n";

=cut


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

=head2 expand

Expands a shortened bitly.com URL to the original long URL.

=cut
sub expand {
    my $self = shift;
    my %args = @_;
    if (!defined $args{URL}) {
        croak("URL is required.\n");
        return -1;
    }
#    my @foo = split(/\//, $args{URL});
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

=head2 info

Get info about a shortened bitly.com URL. By default, the method will use the value that's stored in $bitly->{bitlyurl}. To be sure you're getting info on the correct URL, it's a good idea to set this value before getting any info on it.

$bitly->{bitlyurl} = "http://bitly.com/jmv6";
my $info = $bitly->info();

say "Title of the page is " . $info->{title};
say "Created by " . $info->{created_by};

=cut


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



=head2 clicks

Get click thru information for a shortened bitly.com URL. By default, the method will use the value that's stored in $bitly->{bitlyurl}. To be sure you're getting info on the correct URL, it's a good idea to set this value before getting any info on it.

$bitly->{bitlyurl} = "http://bitly.com/jmv6";
my $clicks = $bitly->clicks();

say "Total number of clicks received: " . $clicks->{user_clicks};
say "Total number of global clicks received are: " . $clicks->{global_clicks};

=cut

sub clicks {
    my $self = shift;
    $self->{response} = $self->{browser}->get($self->{BASE} . '/v3/clicks?shortUrl=' . $self->{bitlyurl} . '&login=' . $self->{USER} . '&apiKey=' . $self->{APIKEY});
    $self->{response}->is_success || die 'Failed to get bitly.com link: ' . $self->{response}->status_line;
    $self->{$self->{bitlyurl}}->{content} = $self->{json}->jsonToObj($self->{response}->{_content});
#    $self->{$self->{bitlyurl}}->{errorCode} = $self->{$self->{bitlyurl}}->{content}->{status_txt};
    if ($self->{$self->{bitlyurl}}->{content}->{status_code} == 200 ) {
#        $self->{$self->{bitlyurl}}->{clicks} = $self->{$self->{bitlyurl}}->{content}->{results};
        $self->{$self->{bitlyurl}}->{clicks} = $self->{$self->{bitlyurl}}->{content}->{data}->{clicks}[0];
        return $self->{$self->{bitlyurl}}->{clicks};
    } else {
        return;
    }
}

=head2 errors

=cut

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

=head2 version

Gets the module version number

=cut
sub version {
    my $self = shift;
    my($version) = shift;# not sure why $version isn't being set. need to look at it
    warn "Version $version is later then $WWW::Shorten::Bitly::VERSION. It may not be supported" if (defined ($version) && ($version > $WWW::Shorten::Bitly::VERSION));
    return $WWW::Shorten::Bitly::VERSION;
}#version


=head2 referrers

Returns an array of hashes

my @ref = $bitly->referrers();
say "Referrers for " . $bitly->{bitlyurl};
foreach my $r (@ref) {
    foreach my $f (@{$r}) {
        say $f->{clicks} . ' from ' . $f->{referrer};
    }
}

=cut

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


=head2 countries {

Returns an array of hashesh

my @countries = $bitly->countries();
foreach my $r (@countries) {
    foreach my $f (@{$r}) {
        say $f->{clicks} . ' from ' . $f->{country};
    }
}

=cut

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

=head2 clicks_by_day {

Returns an array of hashes

my @c = $bitly->clicks_by_day();
say "Clicks by Day for " . $bitly->{bitlyurl};
foreach my $r (@c) {
    foreach my $f (@{$r}) {
        say $f->{clicks} . ' on ' . $f->{day_start};
    }
}

day_start is the timecode as specified by Bitly.com. You can use the following to turn it into a DateTime Object

use DateTime;
$dt = DateTime->from_epoch( epoch => $epoch );

=cut

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


=head2 qr_code

Returns the URL for the QR Code

=cut
sub qr_code {
    my $self = shift;
    my %args = @_;
    $self->{bitlyurl} ||= $args{shorturl};
    return $self->{bitlyurl} . '.qrcode';
}

=head2 validate

For any given a bitly user login and apiKey, you can validate that the pair is active.

=cut

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

=head2 bitly_pro_domain

Will return true or false whether the URL specified is a Bitly Pro Domain

my $bpd = $bitly->bitly_pro_domain(url => 'http://nyti.ms');
say "This is a Bitly Pro Domain: " . $bpd;

my $bpd2 = $bitly->bitly_pro_domain(url => 'http://example.com');
say "This is a Bitly Pro Domain: " . $bpd2;

=cut

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

=head2 lookup

=cut
sub lookup {
    my $self = shift;
}


=head2 clicks_by_minute

This part of the Bitly APi isn't being implemented because it's virtually impossible to know exactly which minute a clicks is attributed to. ya know, network lag, etc. I'll implement this when Bitly puts some sort of a time code into the results.

=cut



=head1 FILES

$HOME/.bitly or _bitly on Windows Systems.

You may omit USER and APIKEY in the constructor if you set them in the .bitly config file on separate lines using the syntax:

USER=username
APIKEY=apikey


=head1 AUTHOR

Pankaj Jain, C<< <pjain at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-shorten-bitly at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Shorten-Bitly>. I will
be notified, and then you'll automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc WWW::Shorten::Bitly


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Shorten-Bitly>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Shorten-Bitly>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Shorten-Bitly>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Shorten-Bitly/>

=back


=head1 ACKNOWLEDGEMENTS

=over

=item http://bitly.com for a wonderful service.

=item Larry Wall, Damian Conway, and all the amazing folks giving us Perl and continuing to work on it over the years.

=item Mizar, C<< <mizar.jp@gmail.com> >>, Peter Edwards, C<<pedwards@cpan.org> >>, Joerg Meltzer, C<< <joerg@joergmeltzer.de> >> for great patches.

=item Thai Thanh Nguyen, C<< <thai@thaiandhien.com> >> for patches to support the Bitly.com v3 API

=back

=head1 COPYRIGHT & LICENSE

=over

=item Copyright (c) 2009-2010 Pankaj Jain, All Rights Reserved L<http://blog.pjain.me>.

=item Copyright (c) 2009-2010 Teknatus Solutions LLC, All Rights Reserved
L<http://teknatus.com>.

=back

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=head1 SEE ALSO

L<perl>, L<WWW::Shorten>, L<http://bitly.com>.

=cut

1; # End of WWW::Shorten::Bitly
