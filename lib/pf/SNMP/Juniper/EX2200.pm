package pf::SNMP::Juniper::EX2200;

=head1 NAME

pf::SNMP::Juniper::EX - Object oriented module to manage Juniper's EX Series switches

=cut

use strict;
use warnings;

use base ('pf::SNMP::Juniper');
use Log::Log4perl;
use Net::Appliance::Session;

use pf::config;
sub description { 'Juniper EX 2200 Series' }

# importing switch constants
use pf::SNMP::constants;

sub getIfIndexByNasPortId{
    my ($this, $nas_port_id) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $nas_port_id =~ s/\.\d+$//g;

    my $OID_ifName = "1.3.6.1.2.1.2.2.1.2";
    if ( !$this->connectRead() ) {
        $logger->warn("Cannot connect to switch $this->{'_ip'} using SNMP");
    }
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => $OID_ifName );

    
    foreach my $key ( keys %{$result} ) {
        my $portName = $result->{$key}; 
        if ($portName eq $nas_port_id ){
            $key =~ /^$OID_ifName\.(\d+)$/;
            my $ifindex = $1;
            $logger->info("Found ifindex $ifindex for nas port id $nas_port_id");
            return $ifindex;
        }
    }
    return $FALSE;
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
