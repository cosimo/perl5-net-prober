package Net::Prober::ping;

use strict;
use warnings;
use base 'Net::Prober::Probe::Base';

sub defaults {
    return {
        host    => undef,
        port    => undef,
        timeout => undef,
        # icmp requires root privileges, but we don't use tcp
        # because it may incorrectly report hosts as down
        proto   => 'icmp',
        size    => undef,
    };
}

sub probe {
    my ($self, $args) = @_;

    my ($host, $port, $timeout, $proto, $size) =
        $self->parse_args($args, qw(host port timeout proto size));

    #my ($host, $port, $timeout, $proto, $size) =
    #    @{$probe}{qw(host port timeout proto size)};

    my $pinger = Net::Ping->new($proto, $timeout);
    $pinger->hires();

    if (defined $port) {
        if ($proto eq 'icmp') {
            Carp::croak("Ping on port $port with icmp protocol is not implemented");
        }
        $pinger->port_number($port);
    }

    my ($ok, $elapsed, $ip) = $pinger->ping($host);
    $pinger->close();

    my $result = {
        ok   => $ok ? 1 : 0,
        time => $elapsed,
        ip   => $ip,
    };

    return $result;
}

1;
