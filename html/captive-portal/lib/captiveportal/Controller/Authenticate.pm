package captiveportal::Controller::Authenticate;
use Moose;

BEGIN { extends 'captiveportal::PacketFence::Controller::Authenticate'; }

sub login : Local : Args(0) {
    my ( $self, $c ) = @_;
    if ( $c->request->method eq 'POST' ) {

        # External authentication
        $c->forward('validateLogin');
        $c->forward('enforceLoginRetryLimit');
        $c->forward('authenticationLogin');
        $c->detach('showLogin') if $c->has_errors;
        $c->forward('validateMandatoryFields');
        $c->forward('postAuthentication');
        $c->forward( 'CaptivePortal' => 'webNodeRegister', [$c->stash->{info}->{pid}, %{$c->stash->{info}}] );
        # We push the select role page to super admins
        if($c->stash->{info}->{category} eq "ITAdmins"){
            $c->session->{is_admin} = 1;
            $c->response->redirect('/select_role');
        }
        $c->forward( 'CaptivePortal' => 'endPortalSession' );
    }

    # Return login
    $c->forward('showLogin');

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
