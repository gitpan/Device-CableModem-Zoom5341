# Fetch page from the cablemodem
use strict;
use warnings;

use Carp;


=head1 NAME

Device::CableModem::Zoom5341::Fetch

=head1 NOTA BENE

This is part of the guts of Device::CableModem::Zoom5341.  If you're
reading this, you're either developing the module, writing tests, or
coloring outside the lines; consider yourself warned.

=cut


=head2 ->fetch_page_rows

Grabs the connection status page from the modem, returns the given HTML
as an array of lines.
=cut
sub fetch_page_rows
{
	my $self = shift;

	use LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	my $url = "http://$self->{modem_addr}/status_connection.asp";
	my $req = HTTP::Request->new(GET => $url);
	my $res = $ua->request($req);

	croak "Failed HTTP GET on $url: @{[$res->status_line]}"
			unless($res->is_success);

	my $html = $res->content;
	croak "Got no data from $url" unless($html);

	my @html = split /\n/, $html;
	chomp @html;

	return @html;
}


=head2 ->fetch_connection

Grabs and stashes the connection status page.
=cut
sub fetch_connection
{
	my $self = shift;

	# Ensure everything's clear
	$self->{conn_html}  = undef;
	$self->{conn_stats} = undef;

	# Backdoor for testing
	return if $self->{__TESTING_NO_FETCH};

	my @html = $self->fetch_page_rows;
	carp "Failed fetching page from modem" unless @html;
	$self->{conn_html} = \@html;

	return;
}


1;
