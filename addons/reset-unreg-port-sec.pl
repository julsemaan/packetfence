#!/usr/bin/perl

use lib '/usr/local/pf/lib';

use pf::SwitchFactory;
use Data::Dumper;

use pf::util;

my $ip = $ARGV[0];

if(!defined($ip) || !valid_ip($ip)){
  print STDERR "The switch IP you entered is invalid.\n";
  exit;
}

my $switch = pf::SwitchFactory->getInstance()->instantiate($ip);

if(!$switch) {
  print STDERR "Unknown switch !\n";
  exit;
}

if (!$switch->connectRead ) {
  print STDERR "Can't SNMP read on $ip. Check the configuration.";
  exit;
}

if (!$switch->connectWrite ) {
  print STDERR "Can't SNMP write on $ip. Check the configuration.";
  exit;
}

$switch->resetPortSecurity();
print "Done resetting $ip.\n";
