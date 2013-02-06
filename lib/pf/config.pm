package pf::config;

=head1 NAME

pf::config - PacketFence configuration

=cut

=head1 DESCRIPTION

pf::config contains the code necessary to read and manipulate the 
PacketFence configuration files.

It automatically imports gazillions of globals into your namespace. You 
have been warned.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files: F<log.conf>, F<pf.conf>, 
F<pf.conf.defaults>, F<networks.conf>, F<dhcp_fingerprints.conf>, F<oui.txt>, F<floating_network_device.conf>, F<oauth2-ips.conf>.

=cut

use strict;
use warnings;
use Config::IniFiles;
use Date::Parse;
use File::Basename qw(basename);
use File::Spec;
use Log::Log4perl;
use Net::Interface qw(inet_ntoa :afs);
use Net::Netmask;
use POSIX;
use Readonly;
use threads;
use Try::Tiny;
use File::Which;
use Time::Local;

# Categorized by feature, pay attention when modifying
our (
    $install_dir, $bin_dir, $conf_dir, $lib_dir, $log_dir, $generated_conf_dir, $var_dir,
    @listen_ints, @dhcplistener_ints, @ha_ints, $monitor_int,
    @internal_nets, @routed_isolation_nets, @routed_registration_nets, @inline_nets, @external_nets,
    @inline_enforcement_nets, @vlan_enforcement_nets, $management_network, 
    %guest_self_registration,
    $default_config_file, %Default_Config, 
    $config_file, %Config, 
    $network_config_file, %ConfigNetworks, %ConfigOAuth, $oauth_ip_file, 
    $dhcp_fingerprints_file, $dhcp_fingerprints_url,
    $oui_file, $oui_url,
    $floating_devices_file, %ConfigFloatingDevices,
    %connection_type, %connection_type_to_str, %connection_type_explained,
    %mark_type_to_str, %mark_type,
    $blackholemac, $portscan_sid, $thread, $default_pid, $fqdn,
    %CAPTIVE_PORTAL
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT = qw(
        $install_dir $bin_dir $conf_dir $lib_dir $generated_conf_dir $var_dir $log_dir
        @listen_ints @dhcplistener_ints @ha_ints $monitor_int 
        @internal_nets @routed_isolation_nets @routed_registration_nets @inline_nets $management_network @external_nets
        @inline_enforcement_nets @vlan_enforcement_nets
        %guest_self_registration
        $IPTABLES_MARK_UNREG $IPTABLES_MARK_REG $IPTABLES_MARK_ISOLATION
        $IPSET_VERSION %mark_type_to_str %mark_type
        $MAC $PORT $SSID $ALWAYS
        $default_config_file %Default_Config
        $config_file %Config
        $network_config_file %ConfigNetworks %ConfigOAuth
        $dhcp_fingerprints_file $dhcp_fingerprints_url 
        $oui_file $oui_url
        $floating_devices_file %ConfigFloatingDevices
        $blackholemac $portscan_sid $WIPS_VID @VALID_TRIGGER_TYPES $thread $default_pid $fqdn
        $FALSE $TRUE $YES $NO
        $IF_INTERNAL $IF_ENFORCEMENT_VLAN $IF_ENFORCEMENT_INLINE
        $WIRELESS_802_1X $WIRELESS_MAC_AUTH $WIRED_802_1X $WIRED_MAC_AUTH $WIRED_SNMP_TRAPS $UNKNOWN $INLINE
        $WIRELESS $WIRED $EAP
        $VOIP $NO_VOIP $NO_PORT $NO_VLAN
        %connection_type %connection_type_to_str %connection_type_explained
        $RADIUS_API_LEVEL $VLAN_API_LEVEL $INLINE_API_LEVEL $AUTHENTICATION_API_LEVEL $SOH_API_LEVEL $BILLING_API_LEVEL
        $ROLE_API_LEVEL
        $SELFREG_MODE_EMAIL $SELFREG_MODE_SMS $SELFREG_MODE_SPONSOR $SELFREG_MODE_GOOGLE $SELFREG_MODE_FACEBOOK $SELFREG_MODE_GITHUB
        %CAPTIVE_PORTAL
        $HTTP $HTTPS
        normalize_time $TIME_MODIFIER_RE $ACCT_TIME_MODIFIER_RE
        $BANDWIDTH_DIRECTION_RE $BANDWIDTH_UNITS_RE
        is_vlan_enforcement_enabled is_inline_enforcement_enabled
        is_in_list
        $LOG4PERL_RELOAD_TIMER
        load_config
    );
}

use pf::util::apache qw(url_parser);

$thread = 0;

# TODO bug#920 all application config data should use Readonly to avoid accidental post-startup alterration
$install_dir = '/usr/local/pf';
$bin_dir = File::Spec->catdir( $install_dir, "bin" );
$conf_dir = File::Spec->catdir( $install_dir, "conf" );
$var_dir = File::Spec->catdir( $install_dir, "var" );
$generated_conf_dir = File::Spec->catdir( $var_dir , "conf");
$lib_dir = File::Spec->catdir( $install_dir, "lib" );
$log_dir = File::Spec->catdir( $install_dir, "logs" );

Log::Log4perl->init("$conf_dir/log.conf");
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  threads->self->tid() );

my $logger = Log::Log4perl->get_logger('pf::config');

# some global constants
Readonly::Scalar our $FALSE => 0;
Readonly::Scalar our $TRUE => 1;
Readonly::Scalar our $YES => 'yes';
Readonly::Scalar our $NO => 'no';

$config_file            = $conf_dir . "/pf.conf";
$default_config_file    = $conf_dir . "/pf.conf.defaults";
$network_config_file    = $conf_dir . "/networks.conf";
$dhcp_fingerprints_file = $conf_dir . "/dhcp_fingerprints.conf";
$oui_file               = $conf_dir . "/oui.txt";
$floating_devices_file  = $conf_dir . "/floating_network_device.conf";
$oauth_ip_file          = $conf_dir . "/oauth2-ips.conf";

$oui_url               = 'http://standards.ieee.org/regauth/oui/oui.txt';
$dhcp_fingerprints_url = 'http://www.packetfence.org/dhcp_fingerprints.conf';

Readonly our @VALID_TRIGGER_TYPES => ( "accounting", "detect", "internal", "mac", "nessus", "openvas", "os", "soh", "useragent", 
        "vendormac" );

$portscan_sid = 1200003;
$default_pid  = 1;

Readonly our $WIPS_VID => '1100020';

# Interface types
Readonly our $IF_INTERNAL => 'internal';

# Interface enforcement techniques
Readonly our $IF_ENFORCEMENT_VLAN => 'vlan';
Readonly our $IF_ENFORCEMENT_INLINE => 'inline';

# Network configuration parameters
Readonly our $NET_TYPE_VLAN_REG => 'vlan-registration';
Readonly our $NET_TYPE_VLAN_ISOL => 'vlan-isolation';
Readonly our $NET_TYPE_INLINE => 'inline';

# connection type constants
Readonly our $WIRELESS_802_1X   => 0b110000001;
Readonly our $WIRELESS_MAC_AUTH => 0b100000010;
Readonly our $WIRED_802_1X      => 0b011000100;
Readonly our $WIRED_MAC_AUTH    => 0b001001000;
Readonly our $WIRED_SNMP_TRAPS  => 0b001010000;
Readonly our $INLINE            => 0b000100000;
Readonly our $UNKNOWN           => 0b000000000;
# masks to be used on connection types
Readonly our $WIRELESS => 0b100000000;
Readonly our $WIRED    => 0b001000000;
Readonly our $EAP      => 0b010000000;

# TODO we should build a connection data class with these hashes and related constants
# String to constant hash
%connection_type = (
    'Wireless-802.11-EAP'   => $WIRELESS_802_1X,
    'Wireless-802.11-NoEAP' => $WIRELESS_MAC_AUTH,
    'Ethernet-EAP'          => $WIRED_802_1X,
    'Ethernet-NoEAP'        => $WIRED_MAC_AUTH,
    'SNMP-Traps'            => $WIRED_SNMP_TRAPS,
    'Inline'                => $INLINE,
);

# Their string equivalent for database storage
%connection_type_to_str = (
    $WIRELESS_802_1X => 'Wireless-802.11-EAP',
    $WIRELESS_MAC_AUTH => 'Wireless-802.11-NoEAP',
    $WIRED_802_1X => 'Ethernet-EAP',
    $WIRED_MAC_AUTH => 'Ethernet-NoEAP',
    $WIRED_SNMP_TRAPS => 'SNMP-Traps',
    $INLINE => 'Inline',
    $UNKNOWN => '',
);

# String to constant hash
# these duplicated in html/admin/common.php for web admin display
# changes here should be reflected there
%connection_type_explained = (
    $WIRELESS_802_1X => 'WiFi 802.1X',
    $WIRELESS_MAC_AUTH => 'WiFi MAC Auth',
    $WIRED_802_1X => 'Wired 802.1x',
    $WIRED_MAC_AUTH => 'Wired MAC Auth',
    $WIRED_SNMP_TRAPS => 'Wired SNMP',
    $INLINE => 'Inline',
    $UNKNOWN => 'Unknown',
);

# VoIP constants
Readonly our $VOIP    => 'yes';
Readonly our $NO_VOIP => 'no';

# HTTP constants
Readonly our $HTTP => 'http';
Readonly our $HTTPS => 'https';

# API version constants
Readonly::Scalar our $RADIUS_API_LEVEL => 1.02;
Readonly::Scalar our $VLAN_API_LEVEL => 1.01;
Readonly::Scalar our $INLINE_API_LEVEL => 1.01;
Readonly::Scalar our $AUTHENTICATION_API_LEVEL => 1.10;
Readonly::Scalar our $SOH_API_LEVEL => 1.00;
Readonly::Scalar our $BILLING_API_LEVEL => 1.00;
Readonly::Scalar our $ROLE_API_LEVEL => 0.90;

# to shut up strict warnings
$ENV{PATH} = '/sbin:/bin:/usr/bin:/usr/sbin';

# Inline related
# Ip mash marks
# Warning: make sure to verify conf/iptables.conf for hard-coded marks if you change the marks here.
Readonly::Scalar our $IPTABLES_MARK_REG => "1";
Readonly::Scalar our $IPTABLES_MARK_ISOLATION => "2";
Readonly::Scalar our $IPTABLES_MARK_UNREG => "3";
Readonly::Scalar our $IPSET_VERSION => ipset_version();

%mark_type = (
    'Reg'   => $IPTABLES_MARK_REG,
    'Isol' => $IPTABLES_MARK_ISOLATION,
    'Unreg'          => $IPTABLES_MARK_UNREG,
);

# Their string equivalent for database storage
%mark_type_to_str = (
    $IPTABLES_MARK_REG => 'Reg',
    $IPTABLES_MARK_ISOLATION => 'Isol',
    $IPTABLES_MARK_UNREG => 'Unreg',
);

# Use for match radius attributes

Readonly::Scalar our $MAC => "mac";
Readonly::Scalar our $PORT => "port";
Readonly::Scalar our $SSID => "ssid";
Readonly::Scalar our $ALWAYS => "always";


Readonly::Scalar our $NO_PORT => 0;
Readonly::Scalar our $NO_VLAN => 0;

# Guest related
Readonly our $SELFREG_MODE_EMAIL => 'email';
Readonly our $SELFREG_MODE_SMS => 'sms';
Readonly our $SELFREG_MODE_SPONSOR => 'sponsor';
Readonly our $SELFREG_MODE_GOOGLE => 'google';
Readonly our $SELFREG_MODE_FACEBOOK => 'facebook';
Readonly our $SELFREG_MODE_GITHUB => 'github';

# this is broken NIC on Dave's desk - it better be unique!
$blackholemac = "00:60:8c:83:d7:34";

# Log Reload Timer in seconds
Readonly our $LOG4PERL_RELOAD_TIMER => 5 * 60;

# simple cache for faster config lookup
my $cache_vlan_enforcement_enabled;
my $cache_inline_enforcement_enabled;

# Accepted time modifier values
# if you change these, make sure to change:
# html/admin/common/helpers.inc's get_time_units_for_dropdown and get_time_regexp()
our $TIME_MODIFIER_RE = qr/[smhDWMY]/;
our $ACCT_TIME_MODIFIER_RE = qr/[DWMY]/;

# Bandwdith accounting values
our $BANDWIDTH_DIRECTION_RE = qr/IN|OUT|TOT/;
our $BANDWIDTH_UNITS_RE = qr/B|KB|MB|GB|TB/;


# constants are done, let's load the configuration
try {
    load_config();
} catch {
    chomp($_);
    $logger->logdie("Fatal error preventing configuration to load. Please review your configuration. Error: $_");
};

=head1 SUBROUTINES

=over

=item load_config

Load configuration. Can be used to reload it too.

WARNING: This has been recently introduced and was not tested with our 
multi-threaded daemons.

=cut
sub load_config {

    readPfConfigFiles();
    readNetworkConfigFile();
    readFloatingNetworkDeviceFile();
    readOAuthFile();
}

=item ipset_version -  check the ipset version on the system

=cut

sub ipset_version {
    my $logger = Log::Log4perl::get_logger('pf::config');
    my $exe_path = which('ipset');
    if (defined($exe_path)) {
        # TODO: once we can import pf::util in here, we should run this through pf_run instead of backticks
        my $cmd = "sudo ".$exe_path." --version";
        my $out = `$cmd`;
        my ($ipset_version) = $out =~ m/^ipset\s+v?([\d+])/ims;
        return $ipset_version;
    }
    else {
        return 0;
    }
}

=item readPfConfigFiles -  pf.conf.defaults & pf.conf

=cut
sub readPfConfigFiles {

    # load default and override by local config (most common case)
    if ( -e $default_config_file && -e $config_file ) {
        tie %Config, 'Config::IniFiles',
            (
            -file   => $config_file,
            -import => Config::IniFiles->new( -file => $default_config_file )
            );
    }
    # load default values only (local config doesn't exist)
    elsif ( -e $default_config_file ) {
        # import from default values then assign filename to save configuration file
        tie %Config, 'Config::IniFiles', ( -import => Config::IniFiles->new( -file => $default_config_file ) );
        tied(%Config)->SetFileName($config_file);
    }
    # load only local config
    elsif ( -e $config_file ) {
        tie %Config, 'Config::IniFiles', ( -file => $config_file );
    }
    # fail
    else {
        die ("No configuration files present.");
    }

    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->logcroak( join( "\n", @errors ) );
    }

    #remove trailing spaces..
    foreach my $section ( tied(%Config)->Sections ) {
        foreach my $key ( keys %{ $Config{$section} } ) {
            $Config{$section}{$key} =~ s/\s+$//;
        }
    }

    # TODO why was this commented out? it seems to be adequate, no?
    #normalize time
    #tie %documentation, 'Config::IniFiles', ( -file => $conf_dir."/documentation.conf" );
    #foreach my $section (sort tied(%documentation)->Sections) {
    #   my($group,$item) = split(/\./, $section);
    #   my $type = $documentation{$section}{'type'};
    #   $Config{$group}{$item}=normalize_time($Config{$group}{$item}) if ($type eq "time");
    #}

    #normalize time
    foreach my $val (
        "expire.iplog",               "expire.traplog",
        "expire.locationlog",         "expire.node",
        "trapping.redirtimer",
        "registration.skip_window",   "registration.skip_reminder",
        "registration.expire_window", "registration.expire_session",
        "registration.expire_window_midnight",
        "general.maintenance_interval", "scan.duration",
        "vlan.bounce_duration",   
        "guests_self_registration.email_activation_timeout", "guests_self_registration.access_duration",
        "guests_admin_registration.default_access_duration",
    ) {
        my ( $group, $item ) = split( /\./, $val );
        $Config{$group}{$item} = normalize_time( $Config{$group}{$item} );
    }
    foreach my $val ( "registration.skip_deadline", "registration.expire_deadline" )
    {
        my ( $group, $item ) = split( /\./, $val );
        $Config{$group}{$item} = str2time( $Config{$group}{$item} );
    }

    #determine absolute paths
    foreach my $val ("alerting.log") {
        my ( $group, $item ) = split( /\./, $val );
        if ( !File::Spec->file_name_is_absolute( $Config{$group}{$item} ) ) {
            $Config{$group}{$item} = File::Spec->catfile( $log_dir, $Config{$group}{$item} );
        }
    }

    $fqdn = $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};

    foreach my $interface ( tied(%Config)->GroupMembers("interface") ) {
        my $int_obj;
        my $int = $interface;
        $int =~ s/interface //;

        my $ip             = $Config{$interface}{'ip'};
        my $mask           = $Config{$interface}{'mask'};
        my $type           = $Config{$interface}{'type'};

        if ( defined($ip) && defined($mask) ) {
            $ip   =~ s/ //g;
            $mask =~ s/ //g;
            $int_obj = new Net::Netmask( $ip, $mask );
            $int_obj->tag( "ip",      $ip );
            $int_obj->tag( "int",     $int );
        }

        if (!defined($type)) {
            $logger->warn("$int: interface type not defined");
            # setting type to empty to avoid warnings on split below
            $type = '';
        }

        die "Missing mandatory element ip or netmask on interface $int"
            if ($type =~ /internal|managed|management|external/ && !defined($int_obj));

        foreach my $type ( split( /\s*,\s*/, $type ) ) {
            if ( $type eq 'internal' ) {
                push @internal_nets, $int_obj;
                if ($Config{$interface}{'enforcement'} eq $IF_ENFORCEMENT_VLAN) {
                  push @vlan_enforcement_nets, $int_obj;
                } elsif ($Config{$interface}{'enforcement'} eq $IF_ENFORCEMENT_INLINE) {
                    push @inline_enforcement_nets, $int_obj;
                }
                push @listen_ints, $int if ( $int !~ /:\d+$/ );
            } elsif ( $type eq 'managed' || $type eq 'management' ) {

                $int_obj->tag("vip", _fetch_virtual_ip($int, $interface));
                $management_network = $int_obj;
                # adding management to dhcp listeners by default (if it's not already there)
                push @dhcplistener_ints, $int if ( not scalar grep({ $_ eq $int } @dhcplistener_ints) );

            } elsif ( $type eq 'external' ) {
                push @external_nets, $int_obj;
            } elsif ( $type eq 'monitor' ) {
                $monitor_int = $int;
            } elsif ( $type =~ /^dhcp-?listener$/i ) {
                push @dhcplistener_ints, $int;
            } elsif ( $type eq 'high-availability' ) {
                push @ha_ints, $int;
            }
        }
    }

    # GUEST RELATED
    # explode self-registration status and modes for easier and cached boolean tests for different services
    $guest_self_registration{'enabled'} = $TRUE
        if ( $Config{'registration'}{'guests_self_registration'} =~ /^\s*(y|yes|true|enable|enabled|1)\s*$/i );

    $guest_self_registration{$SELFREG_MODE_EMAIL} = $TRUE if is_in_list(
        $SELFREG_MODE_EMAIL,
        $Config{'guests_self_registration'}{'modes'}
    );
    $guest_self_registration{$SELFREG_MODE_SMS} = $TRUE if is_in_list(
        $SELFREG_MODE_SMS,
        $Config{'guests_self_registration'}{'modes'}
    );
    $guest_self_registration{$SELFREG_MODE_SPONSOR} = $TRUE if is_in_list(
        $SELFREG_MODE_SPONSOR,
        $Config{'guests_self_registration'}{'modes'}
    );
    $guest_self_registration{$SELFREG_MODE_GOOGLE} = $TRUE if is_in_list(
        $SELFREG_MODE_GOOGLE,
        $Config{'guests_self_registration'}{'modes'}
    );
    $guest_self_registration{$SELFREG_MODE_FACEBOOK} = $TRUE if is_in_list(
        $SELFREG_MODE_FACEBOOK,
        $Config{'guests_self_registration'}{'modes'}
    );
    $guest_self_registration{$SELFREG_MODE_GITHUB} = $TRUE if is_in_list(
        $SELFREG_MODE_GITHUB,
        $Config{'guests_self_registration'}{'modes'}
    );

    # check for portal profile guest self registration options in case they're disabled in default profile
    foreach my $portalprofile ( tied(%Config)->GroupMembers("portal-profile") ) {
        # marking guest_self_registration as globally enabled if needed by one of the portal profiles
        if ( (defined($Config{$portalprofile}{'guest_self_reg'})) && 
             ($Config{$portalprofile}{'guest_self_reg'} =~ /^\s*(y|yes|true|enable|enabled|1)\s*$/i) ) {
            $guest_self_registration{'enabled'} = $TRUE;
        }

        # marking guest_self_registration as globally enabled if one of the portal profile doesn't defined auth method
        # no auth method == guest self registration
        if ( !defined($Config{$portalprofile}{'auth'}) ) {
            $guest_self_registration{'enabled'} = $TRUE;
        }

        # marking different guest_self_registration modes as globally enabled if needed by one of the portal profiles
        if ( defined($Config{$portalprofile}{'guest_modes'}) ) {
            $guest_self_registration{$SELFREG_MODE_EMAIL} = $TRUE
                if is_in_list($SELFREG_MODE_EMAIL, $Config{$portalprofile}{'guest_modes'});
            $guest_self_registration{$SELFREG_MODE_SMS} = $TRUE
                if is_in_list($SELFREG_MODE_SMS, $Config{$portalprofile}{'guest_modes'});
            $guest_self_registration{$SELFREG_MODE_SPONSOR} = $TRUE
                if is_in_list($SELFREG_MODE_SPONSOR, $Config{$portalprofile}{'guest_modes'});
            $guest_self_registration{$SELFREG_MODE_GOOGLE} = $TRUE
                if is_in_list($SELFREG_MODE_GOOGLE, $Config{$portalprofile}{'guest_modes'});
            $guest_self_registration{$SELFREG_MODE_FACEBOOK} = $TRUE
                if is_in_list($SELFREG_MODE_FACEBOOK, $Config{$portalprofile}{'guest_modes'});
            $guest_self_registration{$SELFREG_MODE_GITHUB} = $TRUE
                if is_in_list($SELFREG_MODE_GITHUB, $Config{$portalprofile}{'guest_modes'});
        }
    }

    _load_captive_portal();
}

=item readNetworkConfigFiles - networks.conf

=cut
sub readNetworkConfigFile {

    tie %ConfigNetworks, 'Config::IniFiles', ( -file => $network_config_file, -allowempty => 1 );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->logcroak( join( "\n", @errors ) );
    }   

    #remove trailing spaces..
    foreach my $section ( tied(%ConfigNetworks)->Sections ) {
        foreach my $key ( keys %{ $ConfigNetworks{$section} } ) {
            $ConfigNetworks{$section}{$key} =~ s/\s+$//;
        }
    }

    foreach my $network ( tied(%ConfigNetworks)->Sections ) {

        # populate routed nets variables
        if ( is_network_type_vlan_isol($network) ) {
            my $isolation_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
            push @routed_isolation_nets, $isolation_obj;
        } elsif ( is_network_type_vlan_reg($network) ) {
            my $registration_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
            push @routed_registration_nets, $registration_obj;
        } elsif ( is_network_type_inline($network) ) {
            my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
            push @inline_nets, $inline_obj;
        }

        # transition pf_gateway to next_hop
        # TODO we can deprecate pf_gateway in 2012
        if ( defined($ConfigNetworks{$network}{'pf_gateway'}) && !defined($ConfigNetworks{$network}{'next_hop'}) ) {
            # carry over the parameter so that things still work
            $ConfigNetworks{$network}{'next_hop'} = $ConfigNetworks{$network}{'pf_gateway'};
        }
    }

}

=item readFloatingNetworkDeviceFile - floating_network_device.conf

=cut
sub readFloatingNetworkDeviceFile {

    tie %ConfigFloatingDevices, 'Config::IniFiles', ( -file => $floating_devices_file, -allowempty => 1 );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->logcroak( join( "\n", @errors ) );
    }

    #remove trailing spaces..
    foreach my $section ( tied(%ConfigFloatingDevices)->Sections ) {   
        foreach my $key ( keys %{ $ConfigFloatingDevices{$section} } ) {
            if ($key eq 'trunkPort') {
                if ($ConfigFloatingDevices{$section}{$key} =~ /^\s*(y|yes|true|enabled|1)\s*$/i) {
                    $ConfigFloatingDevices{$section}{$key} = '1';
                } else {
                    $ConfigFloatingDevices{$section}{$key} = '0';
                }
            } else {
                $ConfigFloatingDevices{$section}{$key} =~ s/\s+$//;
            }
        }
    }
}

=item readOAuthFile - oauth2-ips.conf

=cut
sub readOAuthFile {
    tie %ConfigOAuth, 'Config::IniFiles', ( -file => $oauth_ip_file, -allowempty => 1 );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->logcroak( join( "\n", @errors ) );
    }
    
    #Remove Spaces
    foreach my $section ( tied(%ConfigOAuth)->Sections ) {
        foreach my $key ( keys %{ $ConfigOAuth{$section} } ) {
            $ConfigOAuth{$section}{$key} =~ s/\s+$//;
        }
    }
} 

=item normalize_time - formats date

Months and years are approximate. Do not use for anything serious about time.

=cut
sub normalize_time {
    my ($date) = @_;
    if ( $date =~ /^\d+$/ ) {
        return ($date);

    } else {
        my ( $num, $modifier ) = $date =~ /^(\d+)($TIME_MODIFIER_RE)$/i or return (0);

        if ( $modifier eq "s" ) { return ($num);
        } elsif ( $modifier eq "m" ) { return ( $num * 60 );
        } elsif ( $modifier eq "h" ) { return ( $num * 60 * 60 );
        } elsif ( $modifier eq "D" ) { return ( $num * 24 * 60 * 60 );
        } elsif ( $modifier eq "W" ) { return ( $num * 7 * 24 * 60 * 60 );
        } elsif ( $modifier eq "M" ) { return ( $num * 30 * 24 * 60 * 60 );
        } elsif ( $modifier eq "Y" ) { return ( $num * 365 * 24 * 60 * 60 );
        }
    }
}

=item start_date

Function that calculate the starting date in second of the current day (at midnight),
week (on monday midnight), month (first of the month at midnight), year (first january at midnight).

=cut
sub start_date {
    my ($date) = @_;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my ( $num, $modifier ) = $date =~ /^(\d+)($TIME_MODIFIER_RE)$/i or return (0);
    if ( $modifier eq "D" ) {
        return (time - (($hour * 3600) + ($min * 60) + $sec));
    } elsif ( $modifier eq "W" ) {
        if ($wday eq '0') {
           $wday = 6;
        } else {
           $wday = ($wday -1);
        }
        return (time - (($wday * 86400) + ($hour * 3600) + ($min * 60) + $sec));
    } elsif ( $modifier eq "M" ) {
        return ( mktime (0,0,0,1,$mon,$year));
    } elsif ( $modifier eq "Y" ) {
        return ( mktime (0,0,0,0,0,$year));
    }
}

=item end_date

Function that calculate the ending timestamp of the current day,week,month,year
(exemple 15 Jan 2012 will calculate the 31 Jan 2012 if the arg of the function is 1M)

=cut
sub end_date {
    my ($date) =@_;
    my $logger = Log::Log4perl::get_logger('pf::config');
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my ( $num, $modifier ) = $date =~ /^(\d+)($TIME_MODIFIER_RE)$/i or return (0);
    if ( $modifier eq "D" ) {
        return ( $num * 86400 );
    } elsif ( $modifier eq "W" ) {
        return ($num * 604800);
    } elsif ( $modifier eq "M" ) {
# We have to calculate the number of days in the next month(s)
        my $days_month = 0;
        while ($num != 0) {
            if ($mon eq 11) {
                $mon = 0;
                $year ++;
            }
            my $next_month = timelocal(0, 0, 0, 1, $mon + 1 , $year);
            $days_month += (localtime($next_month - 86_400))[3];
            $mon ++;
            $num --;
        }
        return (($days_month  + 1) * 86400);
    } elsif ( $modifier eq "Y" ) {
# We have to calculate the number of days in the next year(s)
        my $days_year = 0;
        $year = $year + 1900;
        while ($num != 0) {
            if ((($year & 3) == 0) && (($year % 100 != 0) || ($year % 400 == 0))) {
                $days_year +=  366;
            } else {
                $days_year += 365;
            }
            $num --;
            $year ++;
        }
        return (($days_year + 1 ) * 86400);
    }
}

=item is_vlan_enforcement_enabled

Returns true or false based on if vlan enforcement is enabled or not

=cut
sub is_vlan_enforcement_enabled {

    # cache hit
    return $cache_vlan_enforcement_enabled if (defined($cache_vlan_enforcement_enabled));

    foreach my $interface (@internal_nets) {
        my $device = "interface " . $interface->tag("int");

        if (defined($Config{$device}{'enforcement'}) && $Config{$device}{'enforcement'} eq $IF_ENFORCEMENT_VLAN) {
            # cache the answer for future access
            $cache_vlan_enforcement_enabled = $TRUE;
            return $TRUE;
        }
    }

    # if we haven't exited at this point, it means there are no vlan enforcement
    # cache the answer for future access
    $cache_vlan_enforcement_enabled = $FALSE;
    return $FALSE;
}

=item is_inline_enforcement_enabled

Returns true or false based on if inline enforcement is enabled or not

=cut
sub is_inline_enforcement_enabled {

    # cache hit
    return $cache_inline_enforcement_enabled if (defined($cache_inline_enforcement_enabled));

    foreach my $interface (@internal_nets) {
        my $device = "interface " . $interface->tag("int");

        if (defined($Config{$device}{'enforcement'}) && $Config{$device}{'enforcement'} eq $IF_ENFORCEMENT_INLINE) {
            # cache the answer for future access
            $cache_inline_enforcement_enabled = $TRUE;
            return $TRUE;
        }
    }

    # if we haven't exited at this point, it means there are no vlan enforcement
    # cache the answer for future access
    $cache_inline_enforcement_enabled = $FALSE;
    return $FALSE;
}

=item get_newtork_type

Returns the type of a network. The call encapsulate the type configuration changes that we made.

Returns undef on unrecognized types.

=cut
# TODO we can deprecate isolation / registration in 2012
sub get_network_type {
    my ($network) = @_;

    
    if (!defined($ConfigNetworks{$network}{'type'})) {
        # not defined
        return;

    } elsif ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_VLAN_REG$/i) {
        # vlan-registration
        return $NET_TYPE_VLAN_REG;

    } elsif ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_VLAN_ISOL$/i) {
        # vlan-isolation
        return $NET_TYPE_VLAN_ISOL;

    } elsif ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE$/i) {
        # inline
        return $NET_TYPE_INLINE;;

    } elsif ($ConfigNetworks{$network}{'type'} =~ /^registration$/i) {
        # deprecated registration
        $logger->warn("networks.conf network type registration is deprecated use vlan-registration instead");
        return $NET_TYPE_VLAN_REG;

    } elsif ($ConfigNetworks{$network}{'type'} =~ /^isolation$/i) {
        # deprecated isolation
        $logger->warn("networks.conf network type isolation is deprecated use vlan-isolation instead");
        return $NET_TYPE_VLAN_ISOL;
    }

    $logger->warn("Unknown network type for network $network");
    return;
}

=item is_network_type_vlan_reg

Returns true if given network is of type vlan-registration and false otherwise.

=cut
sub is_network_type_vlan_reg {
    my ($network) = @_;

    my $result = get_network_type($network);
    if (defined($result) && $result eq $NET_TYPE_VLAN_REG) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

=item is_network_type_vlan_isol

Returns true if given network is of type vlan-isolation and false otherwise.

=cut
sub is_network_type_vlan_isol {
    my ($network) = @_;

    my $result = get_network_type($network);
    if (defined($result) && $result eq $NET_TYPE_VLAN_ISOL) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

=item is_network_type_inline

Returns true if given network is of type inline and false otherwise.

=cut
sub is_network_type_inline {
    my ($network) = @_;

    my $result = get_network_type($network);
    if (defined($result) && $result eq $NET_TYPE_INLINE) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

=item is_in_list

Searches for an item in a comma separated list of elements (like we do in our configuration files).

Returns true or false values based on if item was found or not.

=cut
sub is_in_list {
    my ($item, $list) = @_;
    my @list = split( /\s*,\s*/, $list );
    return $TRUE if ( scalar grep({ $_ eq $item } @list) );
    return $FALSE;
}

=item _fetch_virtual_ip

Returns the virtual IP (vip) on a given interface.

First, if there's a vip parameter defined on the interface, we return that.

Othwerise, we assume that the vip has a /32 netmask and that's how we fetch it.

We return the first vip that matches the above criteria in decimal dotted notation (ex: 192.168.1.1).
Undef if nothing is found.

=cut
# TODO IPv6 support
sub _fetch_virtual_ip {
    my ($interface, $config_section) = @_;

    # [interface $int].vip= ... always wins
    return $Config{$config_section}{'vip'} if defined($Config{$config_section}{'vip'});

    my $if = Net::Interface->new($interface);
    return if (!defined($if));

    # these array are ordered the same way, that's why we can assume the following
    my @masks = $if->netmask(AF_INET);
    my @addresses = $if->address(AF_INET);

    for my $i (0 .. $#masks) {
        return inet_ntoa($addresses[$i]) if (inet_ntoa($masks[$i]) eq '255.255.255.255');
    }
    return;
}

=item _load_captive_portal

Populate captive portal related configuration and constants.

=cut
sub _load_captive_portal {

    # CAPTIVE-PORTAL RELATED
    # Captive Portal constants
    %CAPTIVE_PORTAL = (
        "NET_DETECT_INITIAL_DELAY" => floor($Config{'trapping'}{'redirtimer'} / 4),
        "NET_DETECT_RETRY_DELAY" => 2,
        "NET_DETECT_PENDING_INITIAL_DELAY" => 2 * 60,
        "NET_DETECT_PENDING_RETRY_DELAY" => 30,
        "TEMPLATE_DIR" => "$install_dir/html/captive-portal/templates",
        "ADMIN_TEMPLATE_DIR" => "$install_dir/html/admin/templates",
    );

    # passthrough proxy is enabled, we need to inject proper 'allow through' for pf::web::dispatcher
    if ( $Config{'trapping'}{'passthrough'} eq "proxy" ) {

        my $passthrough_ref = {};
        foreach my $key (keys %{$Config{'passthroughs'}}) {
            my (undef, undef, $host, $query) = url_parser($Config{'passthroughs'}{$key});
            $passthrough_ref->{$host} = $query;
        }
        $CAPTIVE_PORTAL{'PASSTHROUGHS'} = $passthrough_ref;
        # pre-loading an regex for hosts so that the first passthrough pass is fast
        my $pt_hosts = join('|', keys %$passthrough_ref);
        $CAPTIVE_PORTAL{'PASSTHROUGH_HOSTS_RE'} = qr/^(?:$pt_hosts)$/;
    }

    # process pf.conf's parameter into an IP => 1 hash
    %{$CAPTIVE_PORTAL{'loadbalancers_ip'}} = 
        map { $_ => $TRUE } split(/\s*,\s*/, $Config{'captive_portal'}{'loadbalancers_ip'})
    ;
}

=back

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Olivier Bilodeau <obilodeau@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2009-2012 Inverse, inc.

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
