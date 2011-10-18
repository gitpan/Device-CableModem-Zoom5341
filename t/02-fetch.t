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
	$fret = fork();
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
	my $r = $c->get_request;
	if($r->method ne 'GET' || $r->uri ne '/status_connection.asp')
	{
		die "Unexpected request1 '@{[$r->method]} @{[$r->uri]}'";
	}
	$c->send_error(404);
	$c->close;

	# Take the next, and return data
	$c = $d->accept;
	$r = $c->get_request;
	if($r->method ne 'GET' || $r->uri ne '/status_connection.asp')
	{
		die "Unexpected request2 '@{[$r->method]} @{[$r->uri]}'";
	}
	$c->send_response(HTTP::Response->new(200, 'OK',
			['Content-Type', 'text/plain'], "Ohai\n"));
	$c->close;

	# Done; shut down
	exit;
};

# The child process shouldn't get here
if($ischild)
{
	die "Child: $@" if $@;
	die "Child: shouldn't get here\n";
}

# The parent shouldn't see an error or bad fork() return.
if($@ || !defined($fret))
{
	plan skip_all => "Couldn't get local HTTP::Daemon working: $@";
}


# OK, should be good; run the tests
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
