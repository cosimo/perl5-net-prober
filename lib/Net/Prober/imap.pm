package Net::Prober::imap;

use strict;
use warnings;
use base 'Net::Prober::Probe::TCP';

sub args {
    return {
        host     => undef,
        port     => 143,
        timeout  => 30,
        username => undef,
        password => undef,
        mailbox  => 'inbox',
    };
}

sub probe {
    my ($self, $args) = @_;

    my ($host, $port, $timeout, $username, $password, $mailbox) =
        $self->parse_args($args, qw(host port timeout username password mailbox));

    my $t0 = $self->time_now();

    my $sock = $self->open_socket($args);
    if (! $sock) {
        return $self->probe_failed(
            reason => qq{Couldn't connect to imap server $host:$port},
        );
    }

    $self->_send_imap_command($sock, login => $username, $password);
    if (! $self->_parse_imap_reply($sock)) {
        return $self->probe_failed(
            reason => qq{Couldn't login to imap $host:$port with user $username},
        );
    }

    $self->_send_imap_command($sock, select => $mailbox);
    if (! $self->_parse_imap_reply($sock, qr{OK.*Completed}i)) {
        return $self->probe_failed(
            reason => qq{Couldn't select mailbox $mailbox when talking to imap $host:$port}
        );
    }

    $self->_send_imap_command($sock, 'logout');

    my $result = {
        ok => 1,
        time => $self->elapsed_time,
    };

    return $result;
}

sub _send_imap_command {
    my ($self, $sock, $cmd, @args) = @_;
    my $imap_cmd = sprintf ". %s %s\r\n", $cmd, join(" ", @args);
    return $sock->send($imap_cmd);
}

sub _parse_imap_reply {
    my ($self, $sock, $re) = @_;
    $re ||= qr{OK}i;
    my $reply;
    while (defined(my $buf = $sock->recv())) {
        $reply .= $buf;
    }
    return $reply;
}

1;
