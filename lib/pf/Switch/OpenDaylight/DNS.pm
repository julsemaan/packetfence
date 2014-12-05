package pf::Switch::OpenDaylight::DNS;

=head1 NAME

pf::Switch::Brocade::RFS

=head1 SYNOPSIS

Brocade RF Switches module

=head1 STATUS

This module is currently only a placeholder, see L<pf::Switch::Motorola>

=cut

use strict;
use warnings;

use base ('pf::Switch::OpenDaylight');
use JSON::XS;
use WWW::Curl::Easy;
use Log::Log4perl;
use pf::util;
use pf::config;
use pf::vlan::custom;
use pf::violation;
use pf::node;

sub description { 'OpenDaylight DNS isolation' }

sub getIsolationStrategy {return "DNS"}

sub isolate_device {
    my ($self, $ifIndex, $mac, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    
    if ( $self->reisolate_device($ifIndex, $mac) ){
        $logger->warn("Couldn't reactivate dnsredirect. Installing a new one");
        return $TRUE;
    }


    my $flow_name = $self->get_flow_name("dnsredirect-out", $mac);
    my $success_out = $self->install_redirect_out($ifIndex, $mac, $switch_id, $flow_name, "53", "udp");
   
    $flow_name = $self->get_flow_name("dnsredirect-in", $mac);
    my $success_in = $self->install_redirect_in($ifIndex, $mac, $switch_id, $flow_name, "53", "udp");
    
    return $success_out && $success_in;

}

sub release_device {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    #$self->find_and_delete_flow("dnsredirect", $mac);
    my $flow_name = $self->get_flow_name("dnsredirect-out", $mac);
    $self->deactivate_flow($flow_name); 
    $flow_name = $self->get_flow_name("dnsredirect-in", $mac);
    $self->deactivate_flow($flow_name); 

    return $TRUE;
}

sub reisolate_device {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $flow_name = $self->get_flow_name("dnsredirect-out", $mac);
    my $success_out = $self->reactivate_flow($flow_name); 
    $flow_name = $self->get_flow_name("dnsredirect-in", $mac);
    my $success_in = $self->reactivate_flow($flow_name); 
    return $success_in && $success_out;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
