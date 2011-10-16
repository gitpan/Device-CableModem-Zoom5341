#!usr/bin/env perl5
use strict;
use warnings;

use Test::More;
use Device::CableModem::Zoom5341;


# See if we can setup a HTTP server
my $ip = '127.0.0.1';
my ($port, $fret, $ischild);

eval
{
	use HTTP::Daemon;

	# Try setting it up
	my $d = HTTP::Daemon->new(LocalAddr => $ip)
			or plan skip_all => "Can't setup HTTP::Daemon";
	$port = $d->sockport;

	# Now, we'll want to fork() off and run this in another process
	my $fret = fork();
	if($fret > 0)
	{
		# Parent; just fall through and finish the tests
		return;
	}
	elsif(!defined($fret))
	{
		# Something went bad
		print STDERR "XXX badfret\n";
		plan skip_all => "fork failed: $@";
	}

	# Else we're the child.  Do the HTTP serving
	$ischild = 1;

	# Make sure we don't accidentally hang around forever
	$SIG{ALRM} = sub { die "$0 child: Timed out\n" };
	alarm 3;

	# Accept one connection, and return a 404
	my $c = $d->accept;
	$c->get_request;
	$c->send_error(404);
	$c->close;

	# Take the next, and return data
	$c = $d->accept;
	$c->get_request;
	$c->send_response(HTTP::Response->new(200, 'OK',
			['Content-Type', 'text/plain'], "Ohai\n"));
	$c->close;

	# Done; shut down
	exit;
};

if($@ && defined($fret))
{
	# If we get here as the child, we should die very loudly
	die $@ if $ischild;

	# Else, we're the parent, so something in the setup failed
	plan skip_all => "Couldn't get local HTTP::Daemon working: $@";
}

plan tests => 6;

my $cm = Device::CableModem::Zoom5341->new(modem_addr => "$ip:$port");
isa_ok($cm, 'Device::CableModem::Zoom5341', "Object built OK");

# First, we expect a 404
eval { $cm->fetch_connection };
like($@, qr/404 Not Found/, "Got expected 404");

# Next, we expect some real data
eval { $cm->fetch_connection };
ok(!$@, "Fetch didn't error");
is($cm->{conn_html}[0], "Ohai", "Got expected data");

# Check that calling the fetch makes sure everything's clear
$cm->{conn_stats} = "hey, this is set";
$cm->{__TESTING_NO_FETCH} = 1;
$cm->fetch_connection;
is($cm->{conn_html},  undef, "Cached HTML is cleared out");
is($cm->{conn_stats}, undef, "Cached stats are cleared out");
