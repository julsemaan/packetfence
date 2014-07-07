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

sub description { 'OpenDaylight SDN controller' }

sub authorizeMac {
    my ($self, $mac, $switch_id, $port) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my @uplinks = $self->getUpLinks();
    #$switch_id =~ s/(.{1,2})/$1:/gs;
    my $path = "controller/nb/v2/flowprogrammer/default/node/OF/$switch_id/staticFlow/";
    $logger->info("Computed path is : $path");
    my %data = (
        "installInHw" => "true",
        "name" => "flow $mac",
        "node" => {
            "id" => $switch_id,
            "type" => "OF",
        },
        "ingressPort" => $port,
        "priority" => "500",
        "dlSrc" => "f0:4d:a2:cb:d9:c5",
        "actions" => [
            "SET_VLAN_ID=156",
            "OUTPUT=$uplinks[0]",
        ],
    );
    
    $self->send_json_request($path, \%data);
    foreach my $uplink (@uplinks) {
        
    }
}

sub send_json_request {
    my ($self, $path, $data) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $url = "http://172.20.20.99:8080/$path";
    my $json_data = encode_json $data;
    my $curl = WWW::Curl::Easy->new;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_URL, $url);
    $curl->setopt(CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    $curl->setopt(CURLOPT_HTTPAUTH, CURLOPT_HTTPAUTH);
    $curl->setopt(CURLOPT_USERNAME, "admin");
    $curl->setopt(CURLOPT_PASSWORD, "admin");
    
    my $request = $json_data;
    my $response_body;
    my $response;
    $curl->setopt(CURLOPT_POSTFIELDSIZE,length($request));
    $curl->setopt(CURLOPT_POSTFIELDS, $request);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);

    # Starts the actual request
    my $curl_return_code = $curl->perform;

    if ( $curl_return_code == 0 ) {
       my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
       if($response_code == 200) {
           $response = decode_json($response_body);
           use Data::Dumper;
           $logger->info(Dumper($response));
       } else {
           $logger->error("An error occured while processing the JSON request return code ($response_code)");
           die "An error occured while processing the JSON request return code ($response_code)";
       }
   } else {
       my $msg = "An error occured while sending a JSON request: $curl_return_code ".$curl->strerror($curl_return_code)." ".$curl->errbuf;
       $logger->error($msg);
       die $msg;
   }

   
    
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
