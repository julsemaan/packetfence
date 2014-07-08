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

sub description { 'OpenDaylight SDN controller' }
sub supportsFlows { return $TRUE }
sub getIfType{ return $SNMP::ETHERNET_CSMACD; }

sub authorizeMac {
    my ($self, $mac, $vlan, $port) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my @uplinks = $self->getUpLinks();
    # delete a previous flow that could have been installed on that port
    $self->delete_flow("outbound", $mac);
    # install a new outbound flow
    $self->install_tagged_outbound_flow($port, $uplinks[0], $mac, $vlan);
    # delete a previous flow that could have been installed on that port
    $self->delete_flow("inbound", $mac);
    # install a new inbound flow on the uplink
    $self->install_tagged_inbound_flow($uplinks[0], $port, $mac, $vlan );
}

sub get_flow_name{
    my ($self, $type, $mac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    $logger->info("IN GET FLOW NAME");
    my $clean_mac = $mac;
    $clean_mac =~ s/://g;

    if($type eq "outbound"){
        return "outbound".$clean_mac;
    }
    elsif($type eq "inbound"){
        return "inbound".$clean_mac; 
    }
    else{
        $logger->error("Invalid type sent. Returning nothing.");
    }
}

sub delete_flow {
    my ($self, $type, $mac) = @_;
    my $flow_name = $self->get_flow_name($type, $mac);
    $self->send_json_request("controller/nb/v2/flowprogrammer/default/node/MD_SAL/$self->{_OpenflowId}/staticFlow/$flow_name", {}, "DELETE");
}

sub send_json_request {
    my ($self, $path, $data, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    $logger->info("IN SEND_JSON_REQUEST $path");
    my $url = "http://172.20.20.99:8080/$path";
    my $json_data = encode_json $data;

    my $command = 'curl -u admin:admin -X '.$method.' -d \''.$json_data.'\' --header "Content-type: application/json" '.$url; 
    $logger->info("Running $command");
    $logger->info("Result of command : ".pf_run($command));
}

sub install_tagged_outbound_flow {
    my ($self, $source_int, $dest_int, $mac, $vlan) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    $logger->info("Installing tagged outbound flow on source port $source_int, destination port $dest_int, tagged with $vlan, on switch $self->{_OpenflowId}");
    
    my $clean_mac = $mac;
    $clean_mac =~ s/://g;
    my $flow_name = $self->get_flow_name("outbound", $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/MD_SAL/$self->{_OpenflowId}/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");
    my %data = (
        "installInHw" => "true",
        "name" => "$flow_name",
        "node" => {
            "id" => $self->{_OpenflowId},
            "type" => "MD_SAL",
        },
        "ingressPort" => "$self->{_OpenflowId}:$source_int",
        "priority" => "500",
        "dlSrc" => "$mac",
        "actions" => [
            "SET_VLAN_ID=$vlan",
            "OUTPUT=$self->{_OpenflowId}:$dest_int",
        ],
    );
    
    $self->send_json_request($path, \%data, "PUT");
   
}

sub install_tagged_inbound_flow {
    my ($self, $source_int, $dest_int, $mac, $vlan) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    
    my $clean_mac = $mac;
    $clean_mac =~ s/://g;
    my $flow_name = $self->get_flow_name("inbound", $mac);
    my $path = "controller/nb/v2/flowprogrammer/default/node/MD_SAL/$self->{_OpenflowId}/staticFlow/$flow_name";
    $logger->info("Computed path is : $path");

    my %data = (
        "name" => $flow_name,
        "node" => {
            "id" => $self->{_OpenflowId},
            "type" => "MD_SAL",
        },
        "ingressPort" => "$self->{_OpenflowId}:$source_int",
        "priority" => "500",
        "vlanId" => $vlan,
        "dlDst" => $mac,
        "installInHw" => "true",
        "actions" => [
            "OUTPUT=$self->{_OpenflowId}:$dest_int"
        ]
    );
    
    $self->send_json_request($path, \%data, "PUT");
   
}


#sub send_json_request {
#    my ($self, $path, $data, $method) = @_;
#    my $logger = Log::Log4perl::get_logger( ref($self) );
#    my $url = "http://172.20.20.99:8080/$path";
#    my $json_data = encode_json $data;
#    my $curl = WWW::Curl::Easy->new;
#    $curl->setopt(CURLOPT_HEADER, 1);
#    #$curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
#    #$curl->setopt(CURLOPT_NOSIGNAL, 1);
#    $curl->setopt(CURLOPT_URL, $url);
#    $curl->setopt(CURLOPT_HTTPHEADER, ['Content-type: application/json', 'Authorization: Basic YWRtaW46YWRtaW4=']);
#    #$curl->setopt(CURLOPT_HTTPAUTH, CURLOPT_HTTPAUTH);
#    #$curl->setopt(CURLOPT_USERNAME, "admin");
#    #$curl->setopt(CURLOPT_PASSWORD, "admin");
#    
#
#
#    my $request = $json_data;
#    my $response_body;
#    my $response;
#    #$curl->setopt(CURLOPT_POSTFIELDSIZE,length($request));
#    #$curl->setopt(CURLOPT_POST, 1);
#    if($method eq "PUT"){
#        $logger->info("USING PUT");
#        $curl->setopt(CURLOPT_PUT, 1);     
#    }   
#    $curl->setopt(CURLOPT_POSTFIELDS, $request);
#    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
#
#    use Data::Dumper;
#    $logger->info($json_data);
#    # Starts the actual request
#    my $curl_return_code = $curl->perform;
#
#    if ( $curl_return_code == 0 ) {
#       my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
#       if($response_code == 200) {
#           $response = decode_json($response_body);
#           use Data::Dumper;
#           $logger->info(Dumper($response));
#       } else {
#           $logger->error("An error occured while processing the JSON request return code ($response_code)");
#           $logger->error(Dumper($response_body));
#           die "An error occured while processing the JSON request return code ($response_code)";
#       }
#   } else {
#       my $msg = "An error occured while sending a JSON request: $curl_return_code ".$curl->strerror($curl_return_code)." ".$curl->errbuf;
#       $logger->error($msg);
#       die $msg;
#   }
#
#   
#    
#}

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
