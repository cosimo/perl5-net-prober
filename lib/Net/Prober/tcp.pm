package Net::Prober::tcp;

use strict;
use warnings;
use base 'Net::Prober::Probe::TCP';

use Carp ();
use Net::Prober ();

sub probe {
    my ($self, $args) = @_;

    my ($host, $port, $timeout, $proto) =
        $self->parse_args($args, qw(host port timeout proto));

    $port = Net::Prober::port_name_to_num($port);

    if (! defined $port or $port == 0) {
        Carp::croak("Can't probe: undefined port");
    }

    $timeout ||= 3.5;

    my $t0 = $self->time_now();

    my $sock = $self->open_socket($args);
    my $good = 0;
    my $reason;

    if (! $sock) {
        $reason = "Socket open failed";
    }
    else {
        $good = $sock->connected() && $sock->close();
        if (! $good) {
            $reason = "Socket connect or close failed";
        }
    }

    my $elapsed = $self->time_elapsed();

    if ($good) {
        return $self->probe_ok(
            time => $elapsed,
            host => $host,
            port => $port,
        );
    }

    return $self->probe_failed(
        time => $elapsed,
        host => $host,
        port => $port,
        reason => $reason,
    );

}

1;
