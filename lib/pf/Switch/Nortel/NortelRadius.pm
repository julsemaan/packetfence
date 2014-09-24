package pf::Switch::Nortel::NortelRadius;

=head1 NAME

pf::Switch::Avaya::ERS4000 - Object oriented module to access SNMP enabled Avaya ERS 4000 switches

=head1 SYNOPSIS

The pf::Switch::Avaya::ERS4000 module implements an object 
oriented interface to access SNMP enabled Avaya::ERS4000 switches.

=head1 STATUS

This module is currently only a placeholder, see pf::Switch::Avaya.

=cut

use strict;
use warnings;

use pf::Switch::constants;
use Log::Log4perl;
use Net::SNMP;
use pf::config;
use pf::util;

use base ('pf::Switch');

sub supportsWiredMacAuth { return $SNMP::TRUE; }
sub supportsWiredDot1x { return $SNMP::TRUE }
sub supportsRadiusVoip { return $SNMP::TRUE }

sub isVoIPEnabled {
    my ($this) = @_;
    return ( $this->{_VoIPEnabled} == 1 );
}


sub description { 'Nortel RADIUS module' }

sub _identifyConnectionType {
    my ($this, $nas_port_type, $eap_type, $mac, $user_name) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    unless( defined($nas_port_type) ){
        $logger->info("Request type is not set. On Nortel this means it's MAC AUTH");
        return $WIRED_MAC_AUTH;
    }
    
    # if we're not overiding, we call the parent method
    return $this->SUPER::_identifyConnectionType($nas_port_type, $eap_type, $mac, $user_name);

}

sub parseRequest {
    my ($this, $radius_request) = @_;
    my $client_mac = clean_mac($radius_request->{'Calling-Station-Id'}) || clean_mac($radius_request->{'User-Name'});
    my $user_name = $radius_request->{'User-Name'};
    my $nas_port_type = $radius_request->{'NAS-Port-Type'};
    my $port = $radius_request->{'NAS-Port'};
    my $eap_type = 0;
    if (exists($radius_request->{'EAP-Type'})) {
        $eap_type = $radius_request->{'EAP-Type'};
    }
    my $nas_port_id;
    if (defined($radius_request->{'NAS-Port-Id'})) {
        $nas_port_id = $radius_request->{'NAS-Port-Id'};
    }
    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, undef);
}


sub getVoipVsa {
    return {};
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
