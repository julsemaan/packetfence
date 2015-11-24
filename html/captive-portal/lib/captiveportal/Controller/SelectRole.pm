package captiveportal::Controller::SelectRole;
use Moose;

use pf::nodecategory;
use pf::node;

BEGIN { extends 'captiveportal::Base::Controller'; }

__PACKAGE__->config( namespace => 'select_role', );

sub index : Path : Args(0) {
    my ($self, $c) = @_;
    if ( $c->request->method eq 'POST' ) {
        my $mac = $c->portalSession->clientMac;
        my $role = $c->request->param('role');
        $c->log->info("Assigning role $role to $mac");
        node_modify($mac, category => $role);
        $c->forward( 'CaptivePortal' => 'endPortalSession' );
    }
    else {
        $c->stash->{roles} = [nodecategory_view_all()];
        $c->stash->{template} = "select_role.html";
    }
}

=head1 NAME

captiveportal::Controller::Root - Root Controller for captiveportal

=head1 DESCRIPTION

[enter your description here]

=cut

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

__PACKAGE__->meta->make_immutable;

1;
