package captiveportal::PacketFence::Controller::WirelessProfile;
use Moose;
use namespace::autoclean;

BEGIN { extends 'captiveportal::Base::Controller'; }
use pf::config;

__PACKAGE__->config( namespace => 'wireless-profile.mobileconfig', );

=head1 NAME

captiveportal::PacketFence::Controller::WirelessProfile - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $username = $c->session->{username} || '';
    my $provisioner = $c->profile->findProvisioner($c->portalSession->clientMac);
    my $filename = $c->stash->{filename} || "wireless-profile.mobileconfig";
    $c->stash(
        template     => 'wireless-profile.xml',
        current_view => 'MobileConfig',
        provisioner  => $provisioner,
        username     => $username
    );
    $c->response->headers->content_type('application/x-apple-aspen-config; chatset=utf-8');
    $c->response->headers->header( 'Content-Disposition', "attachment; filename=\"$filename\"" );
}

sub profile_xml : Path('/profile.xml') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{filename} = 'profile.xml';
    $c->forward('index');
}  

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
