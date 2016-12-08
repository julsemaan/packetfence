package pf::firewallsso::ASA;

=head1 NAME

pf::firewallsso::ASA

=head1 SYNOPSIS

The pf::firewallsso::ASA module implements an object oriented interface
to update the ASA user table.

=cut


use strict;
use warnings;

use base ('pf::firewallsso');

use POSIX();
use pf::log;

use pf::config qw(%ConfigFirewallSSO);
sub description { 'Cisco ASA' }
use pf::node qw(node_view);
use LWP::UserAgent ();
use HTTP::Request::Common ();
use JSON::MaybeXS qw(encode_json);

#Export environement variables for LWP
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

=head1 METHODS

=head2 action

Perform a http get request based on the registered status of the node and his role.

=cut

my $ua = LWP::UserAgent->new;

sub action {
    my ($self,$firewall_id,$method,$mac,$ip,$timeout) = @_;
    my $logger = get_logger();

    if ($method eq 'Start') {
        my $node_info = node_view($mac);
        my $username = $node_info->{'pid'};
        $self->send_command("cts role-based sgt-map $ip sgt $node_info->{category_id}");
    }
    elsif ($method eq 'Stop') {
        my $node_info = node_view($mac);
        $self->send_command("no cts role-based sgt-map $ip sgt $node_info->{category_id}");
    }
    return 0;
}

sub send_command {
    my ($self, $command) = @_;
    my $logger = get_logger;
    # Create a request
    my $req = HTTP::Request->new(POST => "http://".$self->{id}."/api/cli");
    $req->content_type('application/json');
    my $payload = {
        commands => [
            $command,
        ],
    };
    $req->content(encode_json($payload));

    # Pass request to the user agent and get a response back
    my $res = $ua->request($req);

    # Check the outcome of the response
    if ($res->is_success) {
        $logger->info("Command $command successfully sent to Cisco ASA");
    }
    else {
        $logger->warn("Command $command failed to be sent to Cisco ASA");
    }
}
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
