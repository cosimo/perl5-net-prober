=pod

=head1 NAME

t/icmp.t - Net::Prober test suite

=head1 DESCRIPTION

Try to probe hosts via a ICMP ping

=cut

use strict;
use warnings;

use Test::More tests => 8;
use Net::Prober;

my $result = Net::Prober::probe_icmp({
    host => 'localhost',
});

ok($result && ref $result eq 'HASH', 'probe_icmp() returns a hashref');
ok(exists $result->{ok} && $result->{ok} =~ m{^[01]$},
    "Ping to localhost result: '$result->{ok}'"
);

ok(exists $result->{time}
    && $result->{time} > 0.0
    && $result->{time} < 1.0,
    "Got a ping time too ($result->{time}s)",
);

ok(exists $result->{ip}
    && $result->{ip} eq '127.0.0.1',
    "Got the correct 'ip' value"
);

# IPv6-related tests

SKIP: {

    skip("Net::Ping doesn't support IPv6 apparently?", 4);

    $result = Net::Prober::probe_icmp({
        host => '::1',
    });

    ok($result && ref $result eq 'HASH', 'probe_icmp() returns a hashref');
    ok(exists $result->{ok} && $result->{ok}, 'Ping to ipv6 localhost succeeded');
    ok(exists $result->{time}
        && $result->{time} > 0.0
        && $result->{time} < 1.0,
        "Got a ping time too ($result->{time}s)",
    );
    ok(exists $result->{ip}
        && $result->{ip} eq '::1',
        "Got the correct 'ip' value"
    );

}

