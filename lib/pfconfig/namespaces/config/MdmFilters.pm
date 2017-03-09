package pfconfig::namespaces::config::MdmFilters;

=head1 NAME

pfconfig::namespaces::config::MdmFilter

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::MdmFilters

This module creates the configuration hash associated to mdm_filters.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw($mdm_filters_config_file);

use base 'pfconfig::namespaces::config';

=head2 init

Initialize the namespace object with its child resources

=cut

sub init {
    my ($self) = @_;
    $self->{file} = $mdm_filters_config_file;
    $self->{child_resources} = [ 'FilterEngine::MdmScopes' ];
}

=head2 build_child

Post configuration parsing manipulation

=cut

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{ $self->{cfg} };

    $self->cleanup_whitespaces( \%tmp_cfg );

    return \%tmp_cfg;

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

