package captiveportal::DynamicRouting::MultiSource;

=head1 NAME

captiveportal::DynamicRouting::MultiSource

=head1 DESCRIPTION

MultiSource role to apply on a module to allow it to use multiple sources

=cut

use Moose::Role;
use pf::log;
use List::Util qw(first);
use List::MoreUtils qw(uniq);
use pf::constants;

has 'source_id' => (is => 'rw', trigger => \&_build_sources );

has 'sources' => (is => 'rw', default => \&_build_sources);

has 'multi_source_types' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub{[]});

has 'multi_source_auth_classes' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub{[]});

has 'multi_source_object_classes' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub{[]});

sub display {
    my ($self) = @_;
    return @{$self->sources} ? $TRUE : $FALSE;
}

around 'source' => sub {
    my ($orig, $self, $source) = @_;

    # We don't modify the setting behavior
    if($source){
        $self->session->{source_id} = $source->id;
        $self->$orig($source);
    }

    # If the source is set in the session we use it.
    if($self->session->{source_id}){
        $source = first { $_->id eq $self->session->{source_id} } @{$self->sources};
        get_logger->info("Found source ".$source->id." in session.");
        return $source;
    }
    else {
        $self->$orig();
    }
};

sub _build_sources {
    my ($self, $source_id, $previous) = @_; 
    my @sources;
    # no source id was specified (default context) or the source_id attribute is empty
    if(!defined($source_id) || !$source_id){
        my @sources_by_type = map { $self->app->profile->getSourcesByType($_) } @{$self->multi_source_types};
        my @sources_by_auth_class = map { $self->app->profile->getSourcesByClass($_) } @{$self->multi_source_auth_classes};
        my @sources_by_object_class = map { $self->app->profile->getSourcesByObjectClass($_) } @{$self->multi_source_object_classes};
        push @sources, (@sources_by_type, @sources_by_auth_class, @sources_by_object_class);
        @sources = uniq(@sources);
    }
    else {
        my @source_ids = split(/\s*,\s*/, $source_id);
        @sources = map { pf::authentication::getAuthenticationSource($_) } @source_ids;
    }
    
    get_logger->debug(sub { "Module ".$self->id." is using sources : ".join(',', (map {$_->id} @sources)) });
    $self->sources(\@sources);
    return \@sources;
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

