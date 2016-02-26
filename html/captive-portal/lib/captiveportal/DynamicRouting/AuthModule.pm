package captiveportal::DynamicRouting::AuthModule;

=head1 NAME

captiveportal::DynamicRouting::AuthModule

=head1 DESCRIPTION

Base authentication module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';

use Tie::IxHash;
use List::MoreUtils qw(uniq);
use pf::config;
use pf::person;
use pf::util;
use pf::log;
use captiveportal::DynamicRouting::Form::Authentication;

has 'source' => (is => 'rw', isa => 'pf::Authentication::Source|Undef');

has 'source_id' => (is => 'rw', trigger => \&_build_source);

has 'required_fields' => (is => 'rw', isa => 'ArrayRef[Str]', builder => '_build_required_fields', lazy => 1);

has 'custom_fields' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub {[]});

has 'request_fields' => (is => 'rw', traits => ['Hash'], builder => '_build_request_fields', lazy => 1);

has 'pid_field' => ('is' => 'rw', default => sub {'email'});

has 'with_aup' => ('is' => 'rw', default => sub {1});

has 'actions' => ('is' => 'rw', isa => 'HashRef', default => sub {{"role_from_source" => [], "unregdate_from_source" => []}});

use pf::authentication;
use pf::Authentication::constants;
use captiveportal::DynamicRouting::Actions;

sub form {
    my ($self) = @_;
    my $params = defined($self->app->request->parameters()) ? $self->app->request->parameters() : {};
    my $i18n = captiveportal::DynamicRouting::I18N->new;
    my $form = captiveportal::DynamicRouting::Form::Authentication->new(language_handle => $i18n, app => $self->app);
    $form->process(params => $params);
    return $form;
}

sub _build_request_fields {
    my ($self) = @_;
    return $self->app->hashed_params()->{fields} || {};
}

sub _build_source {
    my ($self) = @_;
    $self->source(pf::authentication::getAuthenticationSource($self->{source_id}));
}

sub execute_actions {
    my ($self) = @_;

    while(my ($action, $params) = each %{$self->actions}){
        get_logger->debug("Executing action $action with params : ".join(',', @{$params}));
        $AUTHENTICATION_ACTIONS{$action}->($self, @{$params});
    }

    unless(defined($self->new_node_info->{unregdate}) && defined($self->new_node_info->{unregdate})){
        get_logger->warn("Cannot find unregdate and role for user.");
        $self->app->flash->{error} = "You do not have permission to register a device with this username";
        return $FALSE;        
    }

    $self->app->session->{source} = $self->source;
    if(isenabled($self->source->{create_local_account})){
        $self->create_local_account();
    }
    
    get_logger->debug(sub { use Data::Dumper; "new_node_info after auth module actions : ".Dumper($self->new_node_info) });
    return $TRUE;
}

sub _build_required_fields {
    my ($self) = @_;
    my @fields;
    push @fields, 'aup' if($self->with_aup);
    push @fields, $self->pid_field if(defined($self->pid_field));
    push @fields, (defined($self->source) ? $self->source->mandatoryFields() : (), @{$self->required_fields_child}, @{$self->custom_fields});
    return [uniq(@fields)];
}

# implement this in childs
sub required_fields_child {[]}

sub merged_fields {
    my ($self) = @_;
    tie my %merged, 'Tie::IxHash';
    foreach my $field (@{$self->required_fields}){
        $merged{$field} = $self->request_fields->{$field}; 
    }
    return \%merged;
}

sub auth_source_params {
    my ($self) = @_;
    return {
        username => $self->app->session->{username},
    }
}

sub create_local_account {
    my ( $self, $password ) = @_;

    my $auth_params = $self->auth_source_params();

    use Data::Dumper;
    get_logger->info("SESSION : ".Dumper($self->session));

    unless($self->session->{fields}->{email}){
        get_logger->error("Can't create account since there is no user e-mail in the session.");
    }

    get_logger->debug("External source local account creation is enabled for this source. We proceed");

    # We create a "password" (also known as a user account) using the pid
    # with different parameters coming from the authentication source (ie.: expiration date)
    my $actions = &pf::authentication::match( $self->source->id, $auth_params );

    # We push an unregistration date that was previously calculated (setUnRegDate) that handle dynamic unregistration date and access duration
    my $action = pf::Authentication::Action->new({
        type    => $Actions::SET_UNREG_DATE, 
        value   => $self->new_node_info->{'unregdate'},
        class   => pf::Authentication::Action->getRuleClassForAction($Actions::SET_UNREG_DATE),
    });
    # Hack alert: We may already have a "SET_UNREG_DATE" action in the array and since the way the authentication framework is working is by going
    # through the actions on a first hit match, we want to make sure the unregistration date we computed (because we are taking care of the access duration,
    # dynamic date, ...) will be the first in the actions array.
    unshift (@$actions, $action);

    $password = pf::password::generate($self->app->session->{username}, $actions, $password);

    # We send the guest and email with the info of the local account
    my %info = (
        'pid'       => $self->app->session->{username},
        'password'  => $password,
        'email'     => $self->session->{fields}->{email},
        'subject'   => $self->app->i18n_format(
            "%s: Guest account creation information", $Config{'general'}{'domain'}
        ),
    );
    pf::web::guest::send_template_email(
            $pf::web::guest::TEMPLATE_EMAIL_LOCAL_ACCOUNT_CREATION, $info{'subject'}, \%info
    );

    get_logger->info("Local account for external source " . $self->source->id . " created with PID " . $self->app->session->{username});
}

sub prompt_fields {
    my ($self, $args) = @_;
    $args //= {};
    $self->render("signin.html", {
        previous_request => $self->app->request->parameters(),
        fields => $self->merged_fields,
        form => $self->form,
        %{$args},
    });
}

sub update_person_from_fields {
    my ($self, %options) = @_;
    $options{additionnal_fields} //= {};
    $options{pid} //= $self->request_fields->{$self->pid_field};
    # not sure we should set the portal + source here...
    person_modify($options{pid}, %{ $self->request_fields }, portal => $self->app->profile->getName, source => $self->source->id);
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

