=pod

=head1 NAME

t/port-names.t - Net::Prober test suite

=head1 DESCRIPTION

Check that port names are resolved to numbers

=cut

use strict;
use warnings;

use Test::More tests => 5;
use Net::Prober;

is(Net::Prober::port_name_to_num(undef), undef);
is(Net::Prober::port_name_to_num(23), 23);
is(Net::Prober::port_name_to_num("http"), 80);
is(Net::Prober::port_name_to_num("ftp"), 21);
is(Net::Prober::port_name_to_num("ssh"), 22);
