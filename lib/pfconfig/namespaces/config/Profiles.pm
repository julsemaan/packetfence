package pfconfig::namespaces::config::Profiles;

=head1 NAME

pfconfig::namespaces::config::Profiles

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Profiles

This module creates the configuration hash associated to profiles.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths;
use pf::util;
use pfconfig::namespaces::resource::guest_self_registration;
use pf::constants::Portal::Profile;
use pf::filter_engine::profile;
use pf::factory::condition::profile;
use List::MoreUtils qw(uniq);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file}            = $profiles_config_file;
    $self->{default_section} = "default";
    $self->{child_resources} = [ 'FilterEngine::Profile', 'resource::URI_Filters' ];
}

sub build_child {
    my ($self) = @_;
    my @uri_filters;
    my %Profiles_Config = %{ $self->{cfg} };
    $self->cleanup_whitespaces( \%Profiles_Config );

    while ( my ( $key, $profile ) = each %Profiles_Config ) {
        foreach my $field (qw(locale sources filter provisioners)) {
            $profile->{$field} = [ split( /\s*,\s*/, $profile->{$field} || '' ) ];
        }
    }

    my @profiles = @{ $self->{ordered_sections} };

    my $config_guest_modes = pfconfig::namespaces::resource::guest_self_registration->new( $self->{cache} );
    while ( my ( $id, $profile ) = each %Profiles_Config ) {
        my $guest_modes = $config_guest_modes->_guest_modes_from_sources( $profile->{sources} );
        $profile->{guest_modes} = @$guest_modes ? join( ',', @$guest_modes ) : '';
    }

    #Clearing the Profile filters
    my $default_description = $Profiles_Config{'default'}{'description'};
    foreach my $profile_id (@profiles) {
        my $profile = $Profiles_Config{$profile_id};
        $profile->{'description'} = ''
            if $profile_id ne 'default' && $profile->{'description'} eq $default_description;
        $profile->{block_interval} = normalize_time( $profile->{block_interval}
                || $pf::constants::Portal::Profile::BLOCK_INTERVAL_DEFAULT_VALUE );
        foreach my $filter (@{$profile->{filter}}) {
            if ($filter =~ $pf::factory::condition::profile::PROFILE_FILTER_REGEX) {
                push @uri_filters,$3 if $1 eq 'uri';
            }
        }
    }
    @uri_filters = uniq @uri_filters;
    $self->{uri_filters} = \@uri_filters;
    $self->{engine_profile} = pf::filter_engine::profile->new({ ordered_ids => \@profiles, config => \%Profiles_Config });

    return \%Profiles_Config;

}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

