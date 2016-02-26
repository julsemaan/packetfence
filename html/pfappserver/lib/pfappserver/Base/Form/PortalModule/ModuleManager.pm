package pfappserver::Base::Form::PortalModule::ModuleManager;

=head1 NAME

pfappserver::Base::Form::Role::MultiSource

=head1 DESCRIPTION

Role for MultiSource portal modules

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::PortalModule';
with 'pfappserver::Base::Form::Role::Help';

use pf::ConfigStore::PortalModule;
use captiveportal::DynamicRouting::util;

has_field 'modules' =>
  (
    'type' => 'DynamicTable',
    'sortable' => 1,
    'do_label' => 0,
  );

has_field 'modules.contains' =>
  (
    type => 'Select',
    widget_wrapper => 'DynamicTableRow',
  );


has_block 'module_manager_definition' => (
    render_list => [qw(modules)],
);

sub BUILD {
    my ($self) = @_;
    
    $self->field('modules.contains')->options([$self->options_modules]);
}

sub options_modules {
    my ($self) = @_;
    my $cs = pf::ConfigStore::PortalModule->new;
    my $modules = $cs->readAll("id");

    my $modules_by_type = captiveportal::DynamicRouting::util::modules_by_type($modules);
    delete $modules_by_type->{Root};

    return map { {
        group => $_,
        options => [
            map { {
                value => $_->{id},
                label => $_->{description}
            } } @{$modules_by_type->{$_}}
        ]
    } } keys(%$modules_by_type);
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


