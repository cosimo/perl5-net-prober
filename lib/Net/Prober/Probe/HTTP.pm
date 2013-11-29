package Net::Prober::Probe::HTTP;

use strict;
use warnings;

use base 'Net::Prober::Probe::TCP';

use Carp ();
use Digest::MD5 ();
use LWPx::ParanoidAgent ();

sub defaults {
    my ($self) = @_;
    my $defaults = $self->SUPER::defaults;

    my %http_defaults = (
        %{ $defaults },
        md5          => undef,
        port         => 80,
        scheme       => 'http',
        url          => '/',
        match        => undef,
        up_status_re => '^[23]\d\d$',
    );

    return \%http_defaults;
}

sub agent {

    my $ua = LWPx::ParanoidAgent->new();
    my $ver = $Net::Prober::VERSION || 'dev';
    $ua->agent("Net::Prober/$ver");
    $ua->max_redirect(0);

    return $ua;
}

sub probe {
    my ($self, $args) = @_;

    my ($host, $port, $timeout, $scheme, $url, $expected_md5, $content_match, $up_status_re) =
        $self->parse_args($args, qw(host port timeout scheme url md5 match up_status_re));

    if (defined $scheme) {
        if ($scheme eq 'http') {
            $port ||= 80;
        }
        elsif ($scheme eq 'https') {
            $port ||= 443;
        }
    }
    elsif (defined $port) {
        $scheme = $port == 443 ? "https" : "http";
    }

    $url =~ s{^/+}{};

    my $probe_url = "$scheme://$host:$port/$url";

    $self->time_now();

    my $ua = $self->agent();
    my $resp = $ua->get($probe_url);
    my $elapsed = $self->time_elapsed();
    my $content = $resp->content();
    my $status = $resp->code();

    my $good = 0;
    my $reason;

    if (! $up_status_re || ! defined $status || ! $status) {
        $good = $resp->is_redirect() || $resp->is_success();
        if (! $good) {
            $reason = "Response HTTP status code wasn't successful (2xx or 3xx)";
        }
    }
    elsif ($up_status_re && defined $status) {
        my $match_re;
        eval {
            $match_re = qr{$up_status_re}ms;
        } or do {
            Carp::croak("Invalid regex for HTTP status match '$up_status_re'\n");
        };
        $good = $status =~ $match_re;
        if (! $good) {
            $reason = "Response HTTP status code didn't match the specified regex ('$up_status_re')";
        }
    }

    if ($good and defined $expected_md5) {
        my $md5 = Digest::MD5::md5_hex($content);
        if ($md5 ne $expected_md5) {
            $good = 0;
            $reason = "Response body MD5 sum wasn't the expected ($expected_md5)";
        }
    }

    if ($good and defined $content_match) {
        my $match_re;
        eval {
            $match_re = qr{$content_match}ms;
        } or do {
            Carp::croak("Invalid regex for http content match '$content_match'\n");
        };
        if ($content !~ $match_re) {
            $good = 0;
            $reason = "Content didn't match the specified '$content_match' regex";
        }
    }

    my %status = (
        status => $resp->status_line,
        content => $content,
        elapsed => $elapsed,
    );

    my $md5 = $content
        ? Digest::MD5::md5_hex($content)
        : undef;

    $status{md5} = $md5 if $md5;
    $status{reason} = $reason if defined $reason;

    if ($good) {
        return $self->probe_ok(%status);
    }

    return $self->probe_failed(%status);
}

1;
