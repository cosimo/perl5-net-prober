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
        #arn "# Trying to connect through SSL to $host:$port with timeout $timeout\n";
        require IO::Socket::SSL;
        return IO::Socket::SSL->new(
            PeerAddr => $host,
            PeerPort => $port,
            SSL_verify_mode => 0,
            Timeout  => $timeout,
        );
    }

    # Unix sockets support (ex.: /tmp/mysqld.sock)
    if (defined $port && $port =~ m{^/}) {
        require IO::Socket::UNIX;
        return IO::Socket::UNIX->new($port);
    }

    # Normal TCP socket to host:port
    #arn "# Trying to connect to $host:$port with timeout $timeout\n";
    return IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Timeout  => $timeout,
    );

}

1;
