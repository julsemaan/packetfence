package pf::Switch::OpenDaylight::WEB;

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

sub description { 'OpenDaylight WEB isolation' }

sub getIsolationStrategy {return "WEB"}

sub isolate_device {
    my ($self, $ifIndex, $mac, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    
    if ( $self->reisolate_device($ifIndex, $mac) ){
        $logger->warn("Couldn't reactivate webredirect. Installing a new one");
        return $TRUE;
    }

    if (! $self->install_web_whitelist($ifIndex, $mac, $switch_id) ){
        return $FALSE;
    }

    my $flow_name = $self->get_flow_name("webredirect-out", $mac);
    my $success_out = $self->install_redirect_out($ifIndex, $mac, $switch_id, $flow_name, "80", "tcp");
   
    $flow_name = $self->get_flow_name("webredirect-in", $mac);
    my $success_in = $self->install_redirect_in($ifIndex, $mac, $switch_id, $flow_name, "80", "tcp");

    return $success_out && $success_in;

}

sub release_device {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    #$self->find_and_delete_flow("dnsredirect", $mac);
    my $flow_name = $self->get_flow_name("webredirect-out", $mac);
    $self->deactivate_flow($flow_name); 
    $flow_name = $self->get_flow_name("webredirect-in", $mac);
    $self->deactivate_flow($flow_name); 

    return $TRUE;
}

sub reisolate_device {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $flow_name = $self->get_flow_name("webredirect-out", $mac);
    my $success_out = $self->reactivate_flow($flow_name); 
    $flow_name = $self->get_flow_name("webredirect-in", $mac);
    my $success_in = $self->reactivate_flow($flow_name); 
    return $success_in && $success_out;
}

sub install_web_whitelist {
    my ($self, $ifIndex, $mac, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    
    my $flow_name = $self->get_flow_name("webredirect-whitelist-out", $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        #"ingressPort" => "$ifIndex",
        "dlSrc" => $mac,
        "priority" => "1001",
        "etherType" => "0x800",
        "nwDst" => "172.20.20.109",
        #"nwDst" => "0.0.0.0/0",
        "tpDst" => "80",
        "protocol" => "tcp",
        "installInHw" => "true",
        "actions" => [
            "OUTPUT=1"
        ]
    );
    my $success_out = $self->send_json_request($path, \%data, "PUT");

    $flow_name = $self->get_flow_name("webredirect-whitelist-in", $mac);
    $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        #"ingressPort" => "$ifIndex",
        "dlDst" => $mac,
        "priority" => "1001",
        "etherType" => "0x800",
        "nwSrc" => "172.20.20.109",
        #"nwDst" => "0.0.0.0/0",
        "tpSrc" => "80",
        "protocol" => "tcp",
        "installInHw" => "true",
        "actions" => [
            "OUTPUT=$ifIndex"
        ]
    );
    my $success_in = $self->send_json_request($path, \%data, "PUT");
    
    return $success_out && $success_in;

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
