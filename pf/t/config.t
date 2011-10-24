#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More;
use Test::NoWarnings;
use Config::IniFiles;

BEGIN { use_ok('pf::config') }

my %default_cfg;
my %doc;

tie %default_cfg, 'Config::IniFiles',
    ( -file => "/usr/local/pf/conf/pf.conf.defaults" );
tie %doc, 'Config::IniFiles',
    ( -file => "/usr/local/pf/conf/documentation.conf" );

#plan the number of tests
my $testNb = 0;
foreach my $section ( tied(%default_cfg)->Sections ) {
    foreach my $key ( keys( %{ $default_cfg{$section} } ) ) {
        if ($section ne 'proxies') {
            $testNb++;
        }
    }
}
foreach my $section ( tied(%doc)->Sections ) {
    if ( ($section ne 'proxies') && ($section ne 'passthroughs') ) {
        if ($section =~ /^([^.]+)\.(.+)$/) {
            if ( ($1 ne 'interface') && ($1 ne 'services') 
                 && (! ( ($1 eq 'alerting') && ($2 eq 'fromaddr') ) )
            ) {
                $testNb++;
            }
        } else {
            die("unable to parse section $section");
        }
    }
}

# +6 for: NoWarnings, use_ok and the 4 ok tests and the end
plan tests => $testNb + 6;

#run the tests
foreach my $section ( tied(%default_cfg)->Sections ) {
    foreach my $key ( keys( %{ $default_cfg{$section} } ) ) {
        if ($section ne 'proxies') {
            my $param = "$section.$key";
            ok ( exists($doc{$param}{'description'}),
                 "$param is documented" );
        }
    }
}

foreach my $section ( tied(%doc)->Sections ) {
    if ( ($section ne 'proxies')
        && ($section ne 'passthroughs')
        ) {
        if ($section =~ /^([^.]+)\.(.+)$/) {
            if ( ($1 ne 'interface') && ($1 ne 'services')
                 && (! ( ($1 eq 'alerting') && ($2 eq 'fromaddr') ) )
               ) {
                ok ( exists($default_cfg{$1}{$2}),
                     "$section has default value" );
            }
        } else {
            die("unable to parse section $section");
        }
    }
}

ok(is_in_list("sms","sms,email"), "is_in_list positive");
ok(!is_in_list("sms","email"), "is_in_list negative");
ok(!is_in_list("sms",""), "is_in_list empty list");
ok(is_in_list("sms","sms, email"), "is_in_list positive with spaces");

# TODO add tests for configfile import / export

=head1 AUTHOR

Dominik Ghel <dghel@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2009-2011 Inverse inc.

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

