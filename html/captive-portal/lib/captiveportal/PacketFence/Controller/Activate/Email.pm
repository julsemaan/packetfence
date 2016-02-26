package captiveportal::PacketFence::Controller::Activate::Email;
use Moose;
use namespace::autoclean;

BEGIN { extends 'captiveportal::Base::Controller'; }

use POSIX;

use pf::constants;
use pf::config;
use pf::activation qw($GUEST_ACTIVATION $SPONSOR_ACTIVATION);
use pf::node;
use pf::Portal::Session;
use pf::util qw(valid_mac isenabled);
use pf::web;
use pf::log;
use pf::web::guest 1.30;
use HTML::Entities;

# called last to allow redefinitions
use pf::web::custom;

use pf::authentication;
use pf::Authentication::constants;

=head1 NAME

captiveportal::PacketFence::Controller::Activate::Email - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $request = $c->request;
    my $code    = $request->param('code');
    my $logger  = $c->log;
    if ( defined $code ) {
        $c->forward( 'code', [$code] );
    } else {
        $self->showError($c,"An activation code is required");
        $c->detach;
    }
}

sub code : Path : Args(1) {
    my ( $self, $c, $code ) = @_;
    my $portalSession = $c->portalSession;
    my $profile       = $c->profile;
    my $node_mac;
    my $request = $c->request;
    my $logger  = $c->log;

    # validate code
    my $activation_record = pf::activation::validate_code($code);
    if (  !defined($activation_record)
        || ref($activation_record) ne 'HASH'
        || !defined( $activation_record->{'type'} ) ) {

        $self->showError($c,
                "The activation code provided is invalid."
              . " Reasons could be: it never existed, it was already used or has expired."
        );
        $c->detach;
    }

    # if we have a MAC, guest was on-site and we set that MAC in the session
    $node_mac = $activation_record->{'mac'};
    if ( defined($node_mac) ) {
        $portalSession->guestNodeMac($node_mac);
    }
    $c->stash( activation_record => $activation_record );

    # Email activated guests only need to prove their email was valid by clicking on the link.
    if ( $activation_record->{'type'} eq $GUEST_ACTIVATION ) {
        # We want to bypass the release process because we want to go back in the app with the reg status
        $c->stash->{application}->session->{release_bypass} = $TRUE;
        $c->stash->{application}->session->{email_completed} = $TRUE;
        $c->forward(Root => 'dynamic_application');
        $c->detach();
    }

    #
    # Sponsor activated guests. We need the sponsor to authenticate before allowing access
    #
    elsif ( $activation_record->{'type'} eq $SPONSOR_ACTIVATION ) {
        $c->forward('doSponsorRegistration', [$code]);

    } else {

        $logger->info( "User has nothing to do here, redirecting to "
              . $c->portalSession->destinationUrl );
        $c->response->redirect( $c->portalSession->destinationUrl );
    }
}

=head2 login

TODO: documention

=cut

sub login : Private {
    my ( $self, $c ) = @_;
    if ( $c->has_errors ) {
        $c->stash->{txt_auth_error} = join(' ', grep { ref ($_) eq '' } @{$c->error});
        $c->clear_errors;
    }
    $c->stash(
        template => $pf::web::guest::SPONSOR_LOGIN_TEMPLATE,
        username => $c->request->param_encoded("username"),
    );
}

=head2 doSponsorRegistration

TODO: documention

=cut

sub doSponsorRegistration : Private {
    my ( $self, $c, $code ) = @_;
    my $logger            = $c->log();
    my $request           = $c->request;
    my $activation_record = $c->stash->{activation_record};
    my $portalSession     = $c->portalSession;
    my $node_mac          = $portalSession->guestNodeMac;
    my ( $pid, $email ) = @{$activation_record}{ 'pid', 'contact_info' };
    my $auth_params = {
        'username'   => $pid,
        'user_email' => $email
    };

    my $profile = $c->profile;
    my $sponsor_type =
      pf::Authentication::Source::SponsorEmailSource->getDefaultOfType;
    my $source = $profile->getSourceByType($sponsor_type);

    if ($source) {

        # if we have a username in session it means user has already authenticated
        # so we go ahead and allow the guest in
        if ( !defined( $c->session->{"username"} ) ) {

            # User is not logged and didn't provide username or password: show login form
            if (!(  $request->param("username") && $request->param("password")
                )
              ) {
                $logger->info(
                    "Sponsor needs to authenticate in order to activate guest. Guest token: $code"
                );
                $c->detach('login');
            }

            # User provided username and password: authenticate
            $c->forward(Authenticate => 'authenticationLogin');
            $c->detach('login') if $c->has_errors;
        }
        # Verify if the user has the role mark as sponsor
        my $source_match = $c->session->{source_match} || $c->session->{source_id};
        my $value = &pf::authentication::match($source_match, {username => $c->session->{"username"}, rule_class => $Rules::ADMIN}, $Actions::MARK_AS_SPONSOR);
        unless (defined $value) {
            $c->log->error( $c->session->{"username"} . " does not have permission to sponsor a user"  );
            $c->session->{username} = undef;
            $self->showError($c,"does not have permission to sponsor a user");
            $c->detach('login');
        }



        # handling log out (not exposed to the UI at this point)
        # TODO: if we ever expose it, we'll need to alter the form action to make sure to trim it
        # otherwise we'll submit our authentication but with ?action=logout so it'll delete the session right away
        if ( defined( $request->param("action") )
            && $request->param("action") eq "logout" ) {
            $c->session->{username} = undef;
            $c->detach('login');
        }

        # User is authenticated (session username exists OR auth_return == $TRUE above)
        $logger->debug( $c->session->{username}
              . " successfully authenticated. Activating sponsored guest" );

        my ( %info, $template );

        if ( defined( $activation_record->{'pid'} ) ) {
            $pid = $activation_record->{'pid'};

            # populating variables used to send email
            $template = $pf::web::guest::TEMPLATE_EMAIL_SPONSOR_CONFIRMED;
            $info{'subject'} = i18n_format("%s: Guest access request accepted", $Config{'general'}{'domain'});

            # TO:
            $info{'email'} = $pid;

            # username
            $info{'pid'} = $pid;
            $info{'cc'} =
            $Config{'guests_self_registration'}{'sponsorship_cc'};

            # we create a password using the actions from the sponsor authentication source;
            # NOTE: When sponsoring a network access, the new user will be created (in the password table) using
            # the actions of the sponsor authentication source of the portal profile on which the *sponsor* has landed.
            my $actions = &pf::authentication::match( $source->{id}, { username => $pid, user_email => $pid } );
            $info{'password'} =
              pf::password::generate( $pid, $actions );

            pf::web::guest::send_template_email( $template, $info{'subject'},
                \%info );
        }

        pf::activation::set_status_verified($code);

        # send to a success page
        $c->stash(
            template => $pf::web::guest::SPONSOR_CONFIRMED_TEMPLATE );
        $c->delete_session();
        $c->detach;
    } else {
        $logger->warn( "No active sponsor source for profile "
              . $profile->getName
              . ", redirecting to "
              . $c->portalSession->destinationUrl );
        $c->response->redirect( $c->portalSession->destinationUrl );
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

