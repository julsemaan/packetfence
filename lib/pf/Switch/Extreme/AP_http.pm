package pf::Switch::Extreme::AP_http;

=head1 NAME

pf::Switch::Extreme::AP_http

=head1 SYNOPSIS

The pf::Switch::Extreme::AP_http module implements an object oriented interface to 
manage the external captive portal on Extreme access points

=head1 STATUS

Developed and tested on EWC4110 running 09.15.03.0005

=cut

use strict;
use warnings;

use base ('pf::Switch::Xirrus');
use Log::Log4perl;

use pf::constants;
use pf::config;
use pf::util;
use pf::node;
use pf::iplog;

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessMacAuth { return $TRUE; }
sub supportsExternalPortal { return $TRUE; }
sub supportsWebFormRegistration { return $TRUE }

=head2 parseUrl

This is called when we receive a http request from the device and return specific attributes:

client mac address
SSID
client ip address
redirect url
grant url
status code

=cut

sub parseUrl {
    my($this, $req, $r) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $connection = $r->connection;

    my $ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $connection->remote_ip;
    my $mac = ip2mac($ip);

    $this->synchronize_locationlog("0", "0", $mac,
        0, $WIRELESS_MAC_AUTH, $mac, undef
    );

    return ($mac,$$req->param('ssid'),$ip,$$req->param('dest'),undef,"200");
}

sub parseSwitchIdFromRequest {
    my($class, $req) = @_;
    my $logger = Log::Log4perl::get_logger( $class );
    return $$req->param('hwc_ip'); 
}

=head2 returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overriding the default implementation for the external captive portal

=cut

sub returnRadiusAccessAccept {
    my ($self, $vlan, $mac, $port, $connection_type, $user_name, $ssid, $wasInline, $user_role) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    my $radius_reply_ref = {};

    my $node = node_view($mac);

    my $violation = pf::violation::violation_view_top($mac);
    # if user is unregistered or is in violation then we reject him to show him the captive portal 
    if ( $node->{status} eq $pf::node::STATUS_UNREGISTERED || defined($violation) ){
        $logger->info("[$mac] is unregistered. Refusing access to force the eCWP");
        my $radius_reply_ref = {
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => -1,
        }; 
        return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref]; 

    }
    else{
        $logger->info("Returning ACCEPT");
        return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
    }

}

sub getAcceptForm {
    my ( $self, $mac , $destination_url, $cgi_session) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    $logger->debug("[$mac] Creating web release form");

    my $token = $cgi_session->param("ecwp-original-param-token");
    my $controller_ip = $self->{_controllerIp};
    my $controller_port = $self->{_controllerPort};

    my $html_form = qq[
        <script>

        setTimeout(function(){
        window.location = "http://$controller_ip:$controller_port/auth_user_xml.php?token=$token&username=$mac&password=$mac"
        }, 2000)
        </script>
    ];

    $logger->debug("Generated the following html form : ".$html_form);
    return $html_form;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
