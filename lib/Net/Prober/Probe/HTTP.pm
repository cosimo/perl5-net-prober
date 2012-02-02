package Net::Prober::Probe::HTTP;

use strict;
use warnings;

use base 'Net::Prober::Probe::TCP';

use LWPx::ParanoidAgent ();

sub defaults {
    my ($self) = @_;
    my $defaults = $self->SUPER::defaults;

    my %http_defaults = (
        %{ $defaults },
        md5     => undef,
        port    => 80,
        scheme  => 'http',
        url     => '/',
        match   => undef,
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

1;
