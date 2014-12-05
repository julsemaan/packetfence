package pf::Switch::OpenDaylight;

=head1 NAME

pf::Switch::Brocade::RFS

=head1 SYNOPSIS

Brocade RF Switches module

=head1 STATUS

This module is currently only a placeholder, see L<pf::Switch::Motorola>

=cut

use strict;
use warnings;

use base ('pf::Switch');
use JSON::XS;
use WWW::Curl::Easy;
use Log::Log4perl;
use pf::util;
use pf::config;
use pf::vlan::custom;
use pf::violation;
use pf::node;

sub description { 'OpenDaylight SDN controller' }
sub supportsFlows { return $TRUE }
sub getIfType{ return $SNMP::ETHERNET_CSMACD; }

sub getIsolationStrategy {return "VLAN"}

sub release_device {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    $logger->warn("Not implemented");
}
sub reisolate_device {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    $logger->warn("Not implemented");
}
sub isolate_device {
    my ($self, $ifIndex, $mac, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    $logger->warn("Not implemented");
}


sub authorizeMac {
    my ($self, $mac, $vlan, $port, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my @uplinks = $self->getUpLinks();

    my $violation = violation_view_top($mac);

    if(defined($violation) && $violation->{vid} eq "1100010"){
        $logger->info("Rogue DHCP detected. Packets from $mac will be dropped");
        $self->install_drop_flow($port, $mac, $vlan);
        return;
    }

    # install a new outbound flow
    $self->install_tagged_outbound_flow($port, $uplinks[0], $mac, $vlan, $switch_id) || return $FALSE;
    # install a new inbound flow on the uplink
    $self->install_tagged_inbound_flow($uplinks[0], $port, $mac, $vlan, $switch_id ) || return $FALSE;
    # instal a flow for broadcast packets
    $self->install_tagged_inbound_flow($uplinks[0], $port, "ff:ff:ff:ff:ff:ff", $vlan, "broadcast", $switch_id ) || return $FALSE;
}

sub get_flow_name{
    my ($self, $type, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $clean_mac = $mac;
    $clean_mac =~ s/://g;

    return "$type-$clean_mac";
}

sub deauthorizeMac {
    my ($self, $mac, $vlan, $port, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my @uplinks = $self->getUpLinks();
    $logger->info("Deleting flows for $mac on port $port on $self->{_ip}");
    # delete a possible drop flow
    $self->delete_flow("drop", $mac, $switch_id) || return $FALSE;
    $self->delete_flow("outbound", $mac, $switch_id) || return $FALSE;
    $self->delete_flow("inbound", $mac, $switch_id) || return $FALSE;
    $self->delete_flow("broadcast", "ff:ff:ff:ff:ff:ff", $switch_id) || return $FALSE;
}

sub delete_flow {
    my ($self, $type, $mac, $switch_id) = @_;
    my $flow_name = $self->get_flow_name($type, $mac);
    return $self->send_json_request("controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name", {}, "DELETE");
}

sub send_json_request {
    my ($self, $path, $data, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $url = "$self->{_wsTransport}://$self->{_ip}:8080/$path";
    my $json_data = encode_json $data;

    my $command = 'curl -u '.$self->{_wsUser}.':'.$self->{_wsPwd}.' -X '.$method.' -d \''.$json_data.'\' --header "Content-type: application/json" '.$url; 
    $logger->info("Running $command");
    my $result = pf_run($command);
    $logger->info("Result of command : ".$result);
    if ( !($method eq "GET") && ( $result eq "Success" || $result eq "No modification detected" || $result eq "") ){
        return $TRUE;
    }
    elsif ($method eq "GET"){
        return $result;
    }
    return $FALSE;
}

sub install_tagged_outbound_flow {
    my ($self, $source_int, $dest_int, $mac, $vlan, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    $logger->info("Installing tagged outbound flow on source port $source_int, destination port $dest_int, tagged with $vlan, on switch $switch_id");
    
    my $clean_mac = $mac;
    $clean_mac =~ s/://g;
    my $flow_name = $self->get_flow_name("outbound", $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");
    my %data = (
        "installInHw" => "true",
        "name" => "$flow_name",
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        "ingressPort" => "$source_int",
        "etherType" => "0x800",
        "priority" => "500",
        "dlSrc" => "$mac",
        "actions" => [
            "SET_VLAN_ID=$vlan",
            "OUTPUT=$dest_int",
        ],
    );
    
    return $self->send_json_request($path, \%data, "PUT");
   
}

sub install_tagged_inbound_flow {
    my ($self, $source_int, $dest_int, $mac, $vlan, $flow_prefix, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if(!defined($flow_prefix)){
        $flow_prefix = "inbound";
    }

    my $flow_name = $self->get_flow_name($flow_prefix, $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        "ingressPort" => "$source_int",
        "etherType" => "0x800",
        "priority" => "500",
        "vlanId" => $vlan,
        "dlDst" => $mac,
        "installInHw" => "true",
        "actions" => [
            "OUTPUT=$dest_int"
        ]
    );
    
    return $self->send_json_request($path, \%data, "PUT");
   
}

sub install_drop_flow {
    my ($self, $source_int, $mac, $vlan, $flow_prefix, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if(!defined($flow_prefix)){
        $flow_prefix = "drop";
    }

    my $flow_name = $self->get_flow_name($flow_prefix, $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        "ingressPort" => "$source_int",
        "priority" => "500",
        "etherType" => "0x800",
        "installInHw" => "true",
        "actions" => [
            "DROP"
        ]
    );
    
    return $self->send_json_request($path, \%data, "PUT");
 
}

sub handleReAssignVlanTrapForWiredMacAuth {
    my ($self, $ifIndex, $mac) = @_;
    my $vlan_obj = new pf::vlan::custom();    
    my $info = pf::node::node_view($mac);
    my $violation_count = pf::violation::violation_count_trap($mac);
    my $device_not_ok = (!defined($info) || $violation_count > 0 || $info->{status} eq $pf::node::STATUS_UNREGISTERED || $info->{status} eq $pf::node::STATUS_PENDING);

    if($self->{_IsolationStrategy} eq "VLAN"){
        my ($vlan, $wasInline, $user_role) = $vlan_obj->fetchVlanForNode($mac, $self, $ifIndex, undef, undef, undef);
        $self->deauthorizeMac($mac, $vlan, $ifIndex);
        $self->authorizeMac($mac, $vlan, $ifIndex);
    }
    else{
        if ($device_not_ok){
            $self->reisolate_device($ifIndex, $mac);
        }
        else{
            $self->release_device($ifIndex, $mac);
        }
    }
}

sub block_network_detection {
    my ($self, $ifIndex, $mac, $switch_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    
    my $flow_name = $self->get_flow_name("block-network-detection", $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        "ingressPort" => "$ifIndex",
        "dlSrc" => $mac,
        "priority" => "1100",
        "etherType" => "0x800",
        "nwDst" => "192.195.20.194/32",
        "tpDst" => "80",
        "protocol" => "tcp",
        "installInHw" => "true",
        "actions" => [
            "DROP"
        ]
    );
    return $self->send_json_request($path, \%data, "PUT");

}



sub install_redirect_out {
    my ($self, $ifIndex, $mac, $switch_id, $flow_name, $tpDst, $protocol) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    
 
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
        "priority" => "1000",
        "etherType" => "0x800",
        #"nwDst" => "0.0.0.0/0",
        "tpDst" => $tpDst,
        "protocol" => $protocol,
        "installInHw" => "true",
        "actions" => [
            "CONTROLLER"
        ]
    );
    return $self->send_json_request($path, \%data, "PUT");   
}

sub install_redirect_in {
    my ($self, $ifIndex, $mac, $switch_id, $flow_name, $tpSrc, $protocol) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        #"ingressPort" => "$ifIndex",
        "dlDst" => $mac,
        "priority" => "1000",
        "etherType" => "0x800",
        #"nwDst" => "0.0.0.0/0",
        "tpSrc" => $tpSrc,
        "protocol" => $protocol,
        "installInHw" => "true",
        "actions" => [
            "CONTROLLER"
        ]
    );
    return $self->send_json_request($path, \%data, "PUT");
 
}

sub find_flow_by_name {
    my ($self, $name) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $path = "controller/nb/v2/flowprogrammer/default";
    my %data = ();
    my $json_response = $self->send_json_request( $path, \%data, "GET" );
    my $data = decode_json($json_response);

    my $flows = $data->{flowConfig};
    foreach my $flow (@$flows){
        if($flow->{name} eq $name){
            return $flow;
        }
    }

    return $FALSE;

}

sub find_and_delete_flow {
    my ($self, $type, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $flow_name = $self->get_flow_name($type, $mac);
    my $flow = $self->find_flow_by_name($flow_name);
    $self->delete_flow($type, $mac, $flow->{node}->{id});
}

sub deactivate_flow{
    my ($self, $flow_name) = @_;
    my $flow = $self->find_flow_by_name($flow_name);
    if($flow && $flow->{installInHw} eq "true"){
        $self->toggle_flow($flow);
    }
}

sub reactivate_flow{
    my ($self, $flow_name) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $flow = $self->find_flow_by_name($flow_name);
    if($flow && $flow->{installInHw} eq "false"){
        $self->toggle_flow($flow);
        return $TRUE;
    }
    else{
        return $FALSE;
    }
}

sub toggle_flow {
    my ($self, $flow) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$flow->{node}->{id}/staticFlow/$flow->{name}";
    $logger->info("Computed path is : $path");

    return $self->send_json_request($path, {}, "POST");
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
