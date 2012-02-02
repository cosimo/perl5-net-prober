package Net::Prober::Probe::TCP;

use strict;
use warnings;

use base 'Net::Prober::Probe::Base';

use IO::Socket::INET;

sub defaults {
    return {
        host => undef,
        port => undef,
        ssl  => 0,
    }
}

sub open_socket {
    my ($self, $args) = @_;

    # TODO ipv6?
    my ($host, $port, $ssl, $timeout) = $self->parse_args(
        $args, qw(host port ssl timeout)
    );

    if ($ssl) {
        require IO::Socket::SSL;
        return IO::Socket::SSL->new(
            PeerAddr => $host,
            PeerPort => $port,
            SSL_verify_mode => 0,
            Timeout  => $timeout,
        );
    }

    # Unix sockets support (ex.: /tmp/mysqld.sock)
    if ($port =~ m{^/}) {
        require IO::Socket::UNIX;
        return IO::Socket::UNIX->new($port);
    }

    # Normal TCP socket to host:port
    return IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Timeout  => $timeout,
    );

}

=head2 C<port_name_to_num($port)>

Converts a given port name (ex.: C<ssh>, or C<http>) to
a number. Returns the number as result.

If the given port doesn't look like a port name,
then you get back what you passed as argument,
unchanged.

=cut

sub port_name_to_num {
    my ($self, $port) = @_;

    if (! $port) {
        $port = $self;
    }

    if (defined $port and $port ne "" and $port =~ m{^\D}) {
        $port = (getservbyname($port, "tcp"))[2];
    }

    return $port;
}

1;
