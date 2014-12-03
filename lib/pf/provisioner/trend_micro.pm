package pf::provisioner::trend_micro;
=head1 NAME

pf::provisioner::trend_micro

=cut

=head1 DESCRIPTION

pf::provisioner::trend_micro

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use pf::util qw(clean_mac);
use WWW::Curl::Easy;
use JSON qw( decode_json );
use Log::Log4perl;
use pf::iplog;
use pf::ConfigStore::Provisioning;

=head1 Atrributes

=head2 host

Host of the trend micro MDM

=cut

has host => (is => 'rw');

=head2 port

Port to connect to the trend micro API

=cut

has api_port => (is => 'rw', default => sub { 443 });

=head2 enrolment_ip

=head2 enrolment_port

Port to connect to the device enrolment web page

=cut

has enrolment_port => (is => 'rw', default => sub { 8080 });

=head2 protocol

Protocol to connect to the trend micro web API

=cut

has protocol => (is => 'rw', default => sub { "https" } );

=head2 agent_download_uri

The URI to download the agent. 
It should be on the same host as this. 
Otherwise add the necessary passthroughs

=cut

has agent_download_uri => (is => 'rw');

sub authorize {
    my ($self,$mac) = @_;
    # for testing we will always return false
    return 0; 
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
