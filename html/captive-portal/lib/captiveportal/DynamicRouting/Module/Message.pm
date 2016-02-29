package captiveportal::DynamicRouting::Module::Message;

=head1 NAME

DynamicRouting::Module::Message

=head1 DESCRIPTION

Module to show a message to the user

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';

has 'template' => (is => 'rw', default => sub {'message.html'});

has 'skipable' => (is => 'rw', default => sub {1});

has 'message' => (is => 'rw', required => 1);

sub execute_child {
    my ($self) = @_;
    if($self->app->request->param('next') && $self->skipable){
        $self->done();
    }
    else {
        $self->render($self->template, {
            message => $self->message, 
            skipable => $self->skipable,
        });
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

