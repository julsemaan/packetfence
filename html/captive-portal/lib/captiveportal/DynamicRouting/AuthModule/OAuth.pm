package captiveportal::DynamicRouting::AuthModule::OAuth;

=head1 NAME

captiveportal::DynamicRouting::AuthModule::OAuth

=head1 DESCRIPTION

OAuth base module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::AuthModule';

use pf::log;
use pf::config;
use pf::auth_log;
use Net::OAuth2::Client;

has 'token_scheme' => (is => 'rw', default => sub {"auth-header:OAuth"});

has '+source' => (isa => 'pf::Authentication::Source::OAuthSource');

sub allowed_urls_auth_module {
    return [
        '/oauth2/go',
        '/oauth2/callback',
    ];
}

sub get_client {
    my ($self) = @_;
    my $source = $self->source;
    return Net::OAuth2::Profile::WebServer->new(
        client_id => $source->{'client_id'},
        client_secret => $source->{'client_secret'},
        site => $source->{'site'},
        authorize_path => $source->{'authorize_path'},
        access_token_path => $source->{'access_token_path'},
        access_token_method => $source->{'access_token_method'},
        scope => $source->{'scope'},
        redirect_uri => $source->{'redirect_url'},
        token_scheme => $self->token_scheme, 
    );
}

sub landing {
    my ($self) = @_;
    $self->render('oauth2/landing.html', {
        source => $self->source,
    });
}

sub execute_child {
    my ($self) = @_;
    if($self->app->request->path eq "oauth2/callback"){
        $self->handle_callback();
    }
    elsif($self->app->request->path eq "oauth2/go"){
        pf::auth_log::record_oauth_attempt($self->source->id, $self->current_mac);
        $self->app->redirect($self->get_client->authorize);
    }
    else {
        $self->landing();
    }
}

sub get_token {
    my ($self) = @_;
    
    my $code = $self->app->request->parameters->{code};
    
    my $token;
    eval {
        $token = $self->get_client->get_access_token($code);
    };
    if ($@) {
        get_logger->warn("OAuth2: failed to receive the token from the provider: $@");
        pf::auth_log::change_record_status($self->source->id, $self->current_mac, $pf::auth_log::FAILED);
        $self->app->flash->{error} = $self->app->i18n("OAuth2 Error: Failed to get the token");
        $self->landing();
        return;
    }
    return $token;
}

sub handle_callback {
    my ($self) = @_;

    my $token = $self->get_token();
    return unless($token);

    # request a JSON response
    my $h = HTTP::Headers->new( 'x-li-format' => 'json' );
    my $response = $token->get($self->source->{'protected_resource_url'}, $h ); 

    if ($response->is_success) {
        my $info = $self->_decode_response($response); 
        my $pid = $self->_extract_username_from_response($info); 
        
        $self->username($pid);

        get_logger->info("OAuth2 successfull for username ".$self->username);
        $self->source->lookup_from_provider_info($self->username, $info);
        
        pf::auth_log::record_completed_oauth($self->source->id, $self->current_mac, $pid, $pf::auth_log::COMPLETED);

        $self->done();
    }
    else {
        get_logger->info("OAuth2: failed to validate the token, redireting to login page.");
        get_logger->debug(sub { use Data::Dumper; "OAuth2 failed response : ".Dumper($response) });
        pf::auth_log::change_record_status($self->source->id, $self->current_mac, $pf::auth_log::FAILED);
        $self->app->flash->{error} = $self->app->i18n("OAuth2 Error: Failed to validate the token, please retry");
        $self->landing();
        return;
    }
}

sub _decode_response {
    my ($self, $response) = @_;
    my $json = new JSON;
    return $json->decode($response->content());
}

sub _extract_username_from_response {
    my ($self, $info) = @_;
    return $info->{email};
}

sub auth_source_params {
    my ($self) = @_;
    return {
        username => $self->username(),
        user_email => $self->username(),
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

