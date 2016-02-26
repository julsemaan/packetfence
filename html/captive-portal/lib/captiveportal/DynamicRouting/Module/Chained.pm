package captiveportal::DynamicRouting::Module::Chained;

=head1 NAME

captiveportal::DynamicRouting::Module::Chained

=head1 DESCRIPTION

To chain multiple modules one after the other

=cut

use Moose;
extends 'captiveportal::DynamicRouting::ModuleManager';

use pf::log;

has 'current_module_index' => (is => 'rw', builder => '_build_current_module_index', lazy => 1);

sub _build_current_module_index {
    my ($self) = @_;
    return $self->session->{current_module_index} // 0;
}

after 'current_module_index' => sub {
    my ($self) = @_;
    $self->session->{current_module_index} = $self->{current_module_index};  
};

sub next {
    my ($self) = @_;
    $self->current_module_index($self->current_module_index + 1);
    get_logger->debug("Executing module ".$self->current_module_index."/".$self->count_modules);
    if($self->current_module_index >= $self->count_modules){
        $self->done();
    }
    else {
        $self->current_module($self->get_module($self->current_module_index)->id);
        $self->app->redirect("/captive-portal");
    }
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

__PACKAGE__->meta->make_immutable;

1;

