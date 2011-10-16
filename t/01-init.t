#!usr/bin/env perl5
use strict;
use warnings;

use Test::More tests => 1;
use Device::CableModem::Zoom5341;

my $cm = new Device::CableModem::Zoom5341;
isa_ok($cm, 'Device::CableModem::Zoom5341', "Object defined right");
