# ABSTRACT: Probes network hosts for downtime, latency, etc...

package Net::Prober;

=pod

=head1 NAME

Net::Prober - Probes network hosts for downtime, latency, etc...

=head1 SYNOPSIS

    use Net::Prober;

    my $result = Net::Prober::probe({
        proto => 'tcp',
        port => 'ssh',
        host => 'localhost',
        timeout => 0.5,
    });

    # $result = {
    #   ok => 1,
    #   time => 0.0002345,
    #   host => '127.0.0.1',
    #   port => 22,
    # }

    # or...

    my $result = Net::Prober::probe({
        proto => 'http',
        host => 'www.opera.com',
        url => '/browser',
        match => 'Faster',
    });

=head1 DESCRIPTION

This module allows to probe hosts for downtime or latency.

You can use it if you want to know things like:

=over 4

=item can we connect to host C<X> on port I<whatever>?

=item how long it takes to connect to host C<X> on port I<whatever>?

=item does host C<X> respond to icmp pings?

=item check if host C<X> responds within a given timeout

=back

Various types of probes are implemented, namely:

=over 4

=item B<tcp>

Opens a socket, connects and closes the socket.

=item B<udp>

Same as TCP, but using a UDP connection.

=item B<http>

Makes an HTTP connection, and requests a given URL (or C</>
if none given). Can check that the content of the response
matches a given regular expression, or has an exact md5 hash.

=back

=head1 MOTIVATION

There must be tons of ready-made modules that do exactly
what this module tries to do. So why?

One reason is that, as ridiculous as this might sound,
I couldn't find any CPAN module to do this.

For example, I looked at the nagios code, as Nagios
does this (and more) but I couldn't find anything
even remotely similar.

Another reason is that I need this code to be very
compact and flexible enough to be wired directly
to a small config file, to be able to specify
the probe arguments as JSON. This is inspired by
the Varnish probe config block:

    # This is my config file.
    # It's JSON presumably...

    "backends": {
        "1.2.3.4" : {
            "datacenter" : "norway1",
            "probe" : {
                "proto": "tcp",
                "port" : "8432",
                "timeout" : 1.0,
            },
        },

        # ...
    }

=cut

use 5.006;
use strict;
use warnings;

use Carp ();
use Data::Dumper ();
use Digest::MD5 ();
use IO::Socket::INET ();
use LWPx::ParanoidAgent ();
use Net::Ping ();
use Time::HiRes ();

=head1 FUNCTIONS

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

sub probe_any {
    my ($class, $args) = @_;
    my $full_pkg = $class;

    # Open up for != Net::Prober::* classes
    if ($full_pkg !~ m{::}) {
        $full_pkg = "Net::Prober::${full_pkg}";
    }

    eval "require $full_pkg; 1" or do {
        Carp::croak("Couldn't load $full_pkg class: $@");
    };

    my $p = $full_pkg->new();
    return $p->probe($args);
}

sub probe_icmp {
    return probe_any('ping', @_);
}

sub probe_ping {
    return probe_any('ping', @_);
}

sub probe_imap {
    return probe_any('imap', @_);
}

sub probe_ssh {
    return probe_any('ssh', @_);
}

sub probe_smtp {
    return probe_any('smtp', @_);
}

sub probe_http {
    return probe_any('http', @_);
}

sub probe_tcp {
    return probe_any('tcp', @_);
}

=head2 C<probe( \%probe_spec )>

Runs a probe against a given host/port.

C<\%probe_spec> allows you to specify what kind of probe
you want to run and against what hostname and port.

Allowed hash keys are:

=over 4

=item C<proto>

What type of probe you want to run.
Can be any of C<tcp>, C<http>, C<icmp>.

B<Default is tcp>.

=item C<host>

Hostname or IP to be probed.

=item C<port>

Port or service to be probed.
Examples:

    23, 'ssh', 8432, 'http', 'echo'

=item C<timeout>

The maximum time to wait for a result. In seconds.

=back

Returns the results as hashref. Example:

    my $result = Net::Prober::probe({
        host => 'localhost',
        port => 'ssh',
        proto => 'tcp',
        timeout => 0.5,
    });

You will get B<at least> these keys:

    $result = {
        ok => 1,
        time => 0.001234,    # how long it took (s)
    }

or in case of failure:

    $result = {
        ok => 0,
        time => 0.001234,
        reason => 'Why the probe failed',
    }

=head3 C<http> probe

The HTTP probe support additional arguments:

=over 4

=item C<match>

Checks if the content matches a given regular expression.
Example:

    match => 'Not found'
    match => 'Log(in|out)'

=item C<md5>

Checks if the whole content of the response matches a given
MD5 hash. B<You can calculate the MD5 of a given URL with>:

    wget -q -O - http://your.url.here | md5sum

=item C<url>

What URL to download. By default it uses C</>.

=back

=head3 C<icmp> probe

Uses L<Net::Ping> to perform C<ICMP> probes, that is,
to send a ping packet to the given host and port.

C<size> of ping packets is not currently supported.

C<proto> is an additional key that allows to specify
whether the pings should be sent via UDP or TCP. Remember
that to send ICMP UDP packets you need root privileges.

B<The ICMP probe code will automatically switch to TCP if the
necessary privileges are not available>.

=cut

sub probe {
    my ($probe_type) = @_;

    my $host = $probe_type->{host};
    if (! defined $host or $host eq "") {
        Carp::croak("Can't probe undefined host\n");
    }

    my $proto = lc($probe_type->{proto} || 'tcp');
    my $port  = $probe_type->{port};

    # Resolve port names (http => 80)
    $port = port_name_to_num($port);

    my $probe = {
        host     => $host,
        port     => $port,
        proto    => $proto,
        url      => $probe_type->{url} || '/',
        timeout  => $probe_type->{timeout} || 1.0,
        md5      => $probe_type->{md5},
        match    => $probe_type->{match},
    };

    my $result;
    if ($proto eq 'http' || $proto eq 'https') {
        $result = probe_http($probe);
    }
    elsif ($proto eq 'tcp') {
        $result = probe_tcp($probe);
    }
    elsif ($proto eq 'icmp') {
        $result = probe_icmp($probe);
    }
    else {
        Carp::croak("Not implemented $proto probe yet");
    }

    return $result;
}

1;

