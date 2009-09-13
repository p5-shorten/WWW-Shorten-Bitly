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


=head1 NAME

WWW::Shorten::Bitly - Interface to shortening URLs using L<http://bit.ly>

=head1 VERSION

$Revision: 1.13 $

=cut

BEGIN {
    our $VERSION = do { my @r = (q$Revision: 1.13 $ =~ /\d+/g); sprintf "%1d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker
    $WWW::Shorten::Bitly::VERBOSITY = 2;
}

# ------------------------------------------------------------


=head1 SYNOPSIS

WWW::Shorten::Bitly provides an easy interface for shortening URLs using http://bit.ly. In addition to shortening URLs, you can pull statistics that bit.ly gathers regarding each shortened
WWW::Shorten::Bitly uses XML::Simple to convert the xml response for the meta info and click stats to create a hashref of the results.

WWW::Shorten::Bitly provides two interfaces. The first is the common C<makeashorterlink> and C<makealongerlink> that WWW::Shorten provides. However, due to the way the bit.ly API works, additional arguments are required. The second provides a better way of retrieving additional information and statistics about a bit.ly URL.

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
say "City referred to is " . $info->{calais}->{city}->{item};
say "Companies referred to are " . $info->{calais}->{company}->{item}[0] . "and " . $info->{calais}->{company}->{item}[1];
say "Title of the page is " . $info->{htmlTitle};

my $clicks = $bitly->clicks();
say "Total number of clicks received: " . $clicks->{clicks};
say "Total number of direct clicks received are: " . ${$clicks->{referrers}->{nodeKeyVal}[0]}->{direct}

=head1 FUNCTIONS

=head2 new

Create a new bit.ly object using your bit.ly user id and bit.ly api key.

my $bitly = WWW::Shorten::Bitly->new(URL => "http://www.example.com/this_is_one_example.html",
USER => "bitly_user_id",
APIKEY => "bitly_api_key");

to use bit.ly's new j.mp service, just construct the bitly object like this:
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
    if ( $args{jmp} == 1) {
        $bitly->{BASE} = "http://api.j.mp";
    } else {
        $bitly->{BASE} = "http://api.bit.ly";
    }
    $bitly->{json} = JSON::Any->new;
    $bitly->{browser} = LWP::UserAgent->new(agent => $args{source});
    $bitly->{xml} = new XML::Simple(SuppressEmpty => 1);
    my ($self) = $bitly;
    bless $self, $class;
}


=head2 makeashorterlink

The function C<makeashorterlink> will call the bit.ly API site passing it
your long URL and will return the shorter bit.ly version.

bit.ly requires the use of a user id and API key to shorten links.

j.mp is not currently supported for makeashorterlink

=cut

sub makeashorterlink #($;%)
{
    my $url = shift or croak('No URL passed to makeashorterlink');
    my ($user, $apikey) = @_ or croak('No username or apikey passed to makeshorterlink');
    if (!defined $url || !defined $user || !defined $apikey ) {
        croak("url, user and apikey are required for shortening a URL with bit.ly - in that specific order");
        &help();
    }
    my $ua = __PACKAGE__->ua();
    my $bitly;
    $bitly->{json} = JSON::Any->new;
    $bitly->{xml} = new XML::Simple(SuppressEmpty => 1);
    my $biturl = "http://api.bit.ly/shorten";
    $bitly->{response} = $ua->post($biturl, [
        'history' => '1',
        'version' => '2.0.1',
        'longUrl' => $url,
        'login' => $user,
        'apiKey' => $apikey,
    ]);
    $bitly->{response}->is_success || die 'Failed to get bit.ly link: ' . $bitly->{response}->status_line;
    $bitly->{bitlyurl} = $bitly->{json}->jsonToObj($bitly->{response}->{_content})->{results}->{$url}->{shortUrl};
    return unless $bitly->{response}->is_success;
    return $bitly->{bitlyurl};
}

=head2 makealongerlink

The function C<makealongerlink> does the reverse. C<makealongerlink>
will accept as an argument either the full bit.ly URL or just the
bit.ly identifier. bit.ly requires the use of a user name and API
Key when using the API.

If anything goes wrong, then the function will return C<undef>.

j.mp is not currently supported for makealongerlink

=cut

sub makealongerlink #($,%)
{
    my $url = shift or croak('No shortened bit.ly URL passed to makealongerlink');
    my ($user, $apikey) = @_ or croak('No username or apikey passed to makealongerlink');
    my $ua = __PACKAGE__->ua();
    my $bitly;
    my @foo = split(/\//, $url);
    $bitly->{json} = JSON::Any->new;
    $bitly->{xml} = new XML::Simple(SuppressEmpty => 1);
    $bitly->{response} = $ua->post('http://api.bit.ly/expand', [
        'version' => '2.0.1',
        'shortUrl' => $url,
        'login' => $user,
        'apiKey' => $apikey,
    ]);
    $bitly->{response}->is_success || die 'Failed to get bit.ly link: ' . $bitly->{response}->status_line;
    $bitly->{longurl} = $bitly->{json}->jsonToObj($bitly->{response}->{_content})->{results}->{$foo[3]}->{longUrl};
    return undef unless $bitly->{response}->is_success;
    my $content = $bitly->{response}->content;
# return undef if $content eq 'ERROR';
    return $bitly->{longurl};
}

=head2 shorten

Shorten a URL using http://bit.ly. Calling the shorten method will return the shortened URL but will also store it in bit.ly object until the next call is made.

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
    $self->{response} = $self->{browser}->post($self->{BASE} . '/shorten', [
        'history' => '1',
        'version' => '2.0.1',
        'longUrl' => $args{URL},
        'login' => $self->{USER},
        'apiKey' => $self->{APIKEY},
    ]);
    $self->{response}->is_success || die 'Failed to get bit.ly link: ' . $self->{response}->status_line;
    return undef if ( $self->{json}->jsonToObj($self->{response}->{_content})->{errorCode} != 0 );
    $self->{bitlyurl} = $self->{json}->jsonToObj($self->{response}->{_content})->{results}->{$args{URL}}->{shortUrl};
    return $self->{bitlyurl} if ( $self->{json}->jsonToObj($self->{response}->{_content})->{errorCode} == 0 );
}

=head2 expand

Expands a shortened bit.ly URL to the original long URL.

=cut
sub expand {
    my $self = shift;
    my %args = @_;
    if (!defined $args{URL}) {
        croak("URL is required.\n");
        return -1;
    }
    my @foo = split(/\//, $args{URL});
    $self->{response} = $self->{browser}->get($self->{BASE} . '/expand', [
        'history' => '1',
        'version' => '2.0.1',
        'shortUrl' => $args{URL},
        'login' => $self->{USER},
        'apiKey' => $self->{APIKEY},
    ]);
    $self->{response}->is_success || die 'Failed to get bit.ly link: ' . $self->{response}->status_line;
    return undef if ( $self->{json}->jsonToObj($self->{response}->{_content})->{errorCode} != 0 );
    $self->{longurl} = $self->{json}->jsonToObj($self->{response}->{_content})->{results}->{$foo[3]}->{longUrl};
    return $self->{longurl} if ( $self->{json}->jsonToObj($self->{response}->{_content})->{errorCode} == 0 );
}

=head2 info

Get info about a shortened bit.ly URL. By default, the method will use the value that's stored in $bitly->{bitlyurl}. To be sure you're getting info on the correct URL, it's a good idea to set this value before getting any info on it.

$bitly->{bitlyurl} = "http://bit.ly/jmv6";
my $info = $bitly->info();

say "City referred to is " . $info->{calais}->{city}->{item};
say "Companies referred to are " . $info->{calais}->{company}->{item}[0] . "and " . $info->{calais}->{company}->{item}[1];
say "Title of the page is " . $info->{htmlTitle};


=cut

sub info {
    my $self = shift;
    $self->{response} = $self->{browser}->post($self->{BASE} . '/info', [
        'format' => 'xml',
        'version' => '2.0.1',
        'shortUrl' => $self->{bitlyurl},
        'login' => $self->{USER},
        'apiKey' => $self->{APIKEY},
    ]);
    $self->{response}->is_success || die 'Failed to get bit.ly link: ' . $self->{response}->status_line;
    $self->{$self->{bitlyurl}}->{content} = $self->{xml}->XMLin($self->{response}->{_content});
    $self->{$self->{bitlyurl}}->{errorCode} = $self->{$self->{bitlyurl}}->{content}->{errorCode};
    if ($self->{$self->{bitlyurl}}->{errorCode} == 0 ) {
        $self->{$self->{bitlyurl}}->{info} = $self->{$self->{bitlyurl}}->{content}->{results}->{doc};
        return $self->{$self->{bitlyurl}}->{info};
    } else {
        return;
    }
}

=head2 clicks

Get click thru information for a shortened bit.ly URL. By default, the method will use the value that's stored in $bitly->{bitlyurl}. To be sure you're getting info on the correct URL, it's a good idea to set this value before getting any info on it.

$bitly->{bitlyurl} = "http://bit.ly/jmv6";
my $clicks = $bitly->clicks();

say "Total number of clicks received: " . $clicks->{clicks};
say "Total number of direct clicks received are: " . ${$clicks->{referrers}->{nodeKeyVal}[0]}->{direct}

=cut

sub clicks {
    my $self = shift;
    $self->{response} = $self->{browser}->post($self->{BASE} . '/stats', [
        'format' => 'xml',
        'version' => '2.0.1',
        'shortUrl' => $self->{bitlyurl},
        'login' => $self->{USER},
        'apiKey' => $self->{APIKEY},
    ]);
    $self->{response}->is_success || die 'Failed to get bit.ly link: ' . $self->{response}->status_line;
    $self->{$self->{bitlyurl}}->{content} = $self->{xml}->XMLin($self->{response}->{_content});
    $self->{$self->{bitlyurl}}->{errorCode} = $self->{$self->{bitlyurl}}->{content}->{errorCode};
    if ($self->{$self->{bitlyurl}}->{errorCode} == 0 ) {
        $self->{$self->{bitlyurl}}->{clicks} = $self->{$self->{bitlyurl}}->{content}->{results};
        return $self->{$self->{bitlyurl}}->{clicks};
    } else {
        return;
    }
}

=head2 errors

=cut

sub errors {
    my $self = shift;
    $self->{response} = $self->{browser}->post($self->{BASE} . '/errors', [
        'version' => '2.0.1',
        'login' => $self->{USER},
        'apiKey' => $self->{APIKEY},
    ]);
    $self->{response}->is_success || die 'Failed to get bit.ly link: ' . $self->{response}->status_line;
    $self->{$self->{bitlyurl}}->{content} = $self->{xml}->XMLin($self->{response}->{_content});
    $self->{$self->{bitlyurl}}->{errorCode} = $self->{$self->{bitlyurl}}->{content}->{errorCode};
    if ($self->{$self->{bitlyurl}}->{errorCode} == 0 ) {
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

=item http://bit.ly for a wonderful service.

=item Larry Wall, Damian Conway, and all the amazing folks giving us Perl and
continuing to work on it over the years.
=item Mizar, C<< <mizar.jp@gmail.com> >>, Peter Edwards, C<<pedwards@cpan.org> >>, Joerg Meltzer, C<< <joerg@joergmeltzer.de> >> for great patches.


=back

=head1 COPYRIGHT & LICENSE

=over

=item Copyright (c) 2009 Pankaj Jain, All Rights Reserved L<http://blog.linosx.com>.

=item Copyright (c) 2009 Teknatus Solutions LLC, All Rights Reserved
L<http://www.teknatus.com>.

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

L<perl>, L<WWW::Shorten>, L<http://bit.ly>.

=cut

1; # End of WWW::Shorten::Bitly
