package captiveportal::DynamicRouting::AuthModule::Sponsor;

=head1 NAME

captiveportal::DynamicRouting::Sponsor

=head1 DESCRIPTION

Sponsoring module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::AuthModule';

use pf::log;
use pf::config;
use Date::Format qw(time2str);
use pf::Authentication::constants;

has '+source' => (isa => 'pf::Authentication::Source::SponsorEmailSource');

sub required_fields_child {
    return ["user_email", "sponsor"];
}

sub execute_child {
    my ($self) = @_;
    if($self->app->request->method eq "POST"){
        $self->do_sponsor_registration();
    }
    elsif(pf::activation::activation_has_entry($self->current_mac,'sponsor')){
        $self->waiting_room();
    }
    else{
        $self->prompt_fields();
    }
}

sub do_sponsor_registration {
    my ($self) = @_;
    my %info;
    get_logger->info("registering  guest through a sponsor");

    return unless($self->_validate_sponsor($self->request_fields->{sponsor}));

    my $source = $self->source;
    my $pid = $self->request_fields->{$self->pid_field};
    my $user_email = $self->request_fields->{user_email};
    $info{'pid'} = $pid;

    # form valid, adding person (using modify in case person already exists)
    my $note = 'sponsored confirmation Date of arrival: ' . time2str("%Y-%m-%d %H:%M:%S", time);

    get_logger->info( "Adding guest person " . $pid );

    # set node in pending mode
    $info{'status'} = $pf::node::STATUS_PENDING;

    $info{'cc'} = $Config{'guests_self_registration'}{'sponsorship_cc'};

    # fetch more info for the activation email
    # this is meant to be overridden in pf::web::custom with customer specific needs
    foreach my $key (qw(firstname lastname telephone company sponsor)) {
        $info{$key} = $self->request_fields->{$key};
    }
    $info{'subject'} = $self->app->i18n_format( "%s: Guest access request", $Config{'general'}{'domain'} );
    utf8::decode($info{'subject'});

    # TODO this portion of the code should be throttled to prevent malicious intents (spamming)
    my ( $auth_return, $err, $errargs_ref ) =
      pf::activation::create_and_send_activation_code(
        $self->current_mac,
        $pid,
        $info{'sponsor'},
        $pf::web::guest::TEMPLATE_EMAIL_SPONSOR_ACTIVATION,
        $pf::activation::SPONSOR_ACTIVATION,
        $self->app->profile->getName,
        %info,
      );
    
    pf::auth_log::record_guest_attempt($source->id, $self->current_mac, $pid);

    $self->app->session->{user_email} = $user_email;

    $self->update_person_from_fields();

    $self->waiting_room();
}

sub waiting_room {
    my ($self) = @_;
    $self->render("waiting.html", $self->_release_args());
}

sub _validate_sponsor {
    my ($self, $sponsor_email) = @_;
    my $value = &pf::authentication::match( pf::authentication::getInternalAuthenticationSources(), { email => $sponsor_email, 'rule_class' => $Rules::ADMIN }, $Actions::MARK_AS_SPONSOR );

    if (!defined $value) {
        $self->app->flash->{error} = $self->app->i18n_format($GUEST::ERRORS{$GUEST::ERROR_SPONSOR_NOT_ALLOWED}, $sponsor_email);
        $self->prompt_fields();
        return 0;
    }
    return 1; 
}

sub auth_source_params {
    my ($self) = @_;
    return {
        user_email => $self->app->session->{user_email},
    };
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

