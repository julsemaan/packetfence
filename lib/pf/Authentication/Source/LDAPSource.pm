package pf::Authentication::Source::LDAPSource;

=head1 NAME

pf::Authentication::Source::LDAPSource

=head1 DESCRIPTION

=cut

use pf::config qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::Authentication::Condition;

use Net::LDAP;
use Net::LDAPS;
use List::Util;
use Net::LDAP::Util qw(escape_filter_value);

use Moose;
extends 'pf::Authentication::Source';

# available encryption
use constant {
    NONE => "none",
    SSL => "ssl",
    TLS => "starttls",
};

has '+type' => (default => 'LDAP');
has 'host' => (isa => 'Maybe[Str]', is => 'rw', default => '127.0.0.1');
has 'port' => (isa => 'Maybe[Int]', is => 'rw', default => 389);
has 'basedn' => (isa => 'Str', is => 'rw', required => 1);
has 'binddn' => (isa => 'Maybe[Str]', is => 'rw');
has 'password' => (isa => 'Maybe[Str]', is => 'rw');
has 'encryption' => (isa => 'Str', is => 'rw', required => 1);
has 'scope' => (isa => 'Str', is => 'rw', required => 1);
has 'usernameattribute' => (isa => 'Str', is => 'rw', required => 1);

=head1 METHODS

=head2 available_attributes

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my @ldap_attributes = map { { value => $_, type => $Conditions::SUBSTRING } }
    ("cn", "department", "displayName", "distinguishedName", "givenName", "memberOf", "sn", "eduPersonPrimaryAffiliation", "mail");

  # We check if our username attribute is present, if not we add it.
  if (not grep {$_->{value} eq $self->{'usernameattribute'} } @ldap_attributes ) {
    push (@ldap_attributes, { value => $self->{'usernameattribute'}, type => $Conditions::SUBSTRING });
  }

  return [@$super_attributes, @ldap_attributes];
}

=head2 authenticate

=cut

sub authenticate {
  my ( $self, $username, $password ) = @_;
  my $logger = Log::Log4perl->get_logger( __PACKAGE__ );

  my ($connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();

  if (! defined($connection)) {
    $logger->error("Unable to connect to an LDAP server.");
    return ($FALSE, 'Unable to validate credentials at the moment');
  }
  my $result = $self->bind_with_credentials($connection);

  if ($result->is_error) {
    $logger->error("Unable to bind with $self->{'binddn'} on $LDAPServer:$LDAPServerPort");
    return ($FALSE, 'Unable to validate credentials at the moment');
  }

  my $filter = "($self->{'usernameattribute'}=$username)";
  $result = $connection->search(
    base => $self->{'basedn'},
    filter => $filter,
    scope => $self->{'scope'},
    attrs => ['dn']
  );
  if ($result->is_error) {
    $logger->error("Unable to execute search $filter from $self->{'basedn'} on $LDAPServer:$LDAPServerPort");
    return ($FALSE, 'Unable to validate credentials at the moment');
  }

  if ($result->count == 0) {
    $logger->warn("No entries found (". $result->count .") with filter $filter from $self->{'basedn'} on $LDAPServer:$LDAPServerPort for source $self->{'id'}");
    return ($FALSE, 'Invalid login or password');
  } elsif ($result->count > 1) {
    $logger->warn("Unexpected number of entries found (" . $result->count .") with filter $filter from $self->{'basedn'} on $LDAPServer:$LDAPServerPort for source $self->{'id'}");
    return ($FALSE, 'Invalid login or password');
  }

  my $user = $result->entry(0);

  $result = $connection->bind($user->dn, password => $password);

  if ($result->is_error) {
    $logger->warn("User cannot " . $user->dn . " cannot bind from $self->{'basedn'} on $LDAPServer:$LDAPServerPort for source $self->{'id'}");
    return ($FALSE, 'Invalid login or password');
  }

  return ($TRUE, 'Successful authentication using LDAP.');
}


=head2 _connect

Try every server in @LDAPSERVER in turn.
Returns the connection object and a valid LDAP server and port or undef
if all connections fail

=cut

sub _connect {
  my $self = shift;
  my $connection;
  my $logger = Log::Log4perl::get_logger(__PACKAGE__);

  my @LDAPServers = split(/\s*,\s*/, $self->{'host'});
  # uncomment the next line if you want the servers to be tried in random order
  # to spread out the connections amongst a set of servers
  #@LDAPServers = List::Util::shuffle @LDAPServers;

  TRYSERVER:
  foreach my $LDAPServer ( @LDAPServers ) {
    # check to see if the hostname includes a port (e.g. server:port)
    my $LDAPServerPort;
    if ( $LDAPServer =~ /:/ ) {
        $LDAPServerPort = ( split(/:/,$LDAPServer) )[-1];
    }
    $LDAPServerPort //=  $self->{'port'} ;

    if ( $self->{'encryption'} eq SSL ) {
        $connection = Net::LDAPS->new($LDAPServer, port =>  $LDAPServerPort );
    } else {
        $connection = Net::LDAP->new($LDAPServer, port =>  $LDAPServerPort );
    }
    if (! defined($connection)) {
      $logger->warn("Unable to connect to $LDAPServer");
      next TRYSERVER;
    }

    # try TLS if required, return undef if it fails
    if ( $self->{'encryption'} eq TLS ) {
      my $mesg = $connection->start_tls();
      if ( $mesg->code() ) { $logger->error($mesg->error()) and return undef; }
    }

    $logger->debug("using ldap connection to $LDAPServer");
    return ( $connection, $LDAPServer, $LDAPServerPort );
  }
  # if the connection is still undefined after trying every server, we fail and return undef.
  if (! defined($connection)) {
    $logger->error("Unable to connect to any LDAP Server");
  }
  return undef;
}


=head2 match_in_subclass

C<$params> are the parameters gathered at authentication (username, SSID, connection, type, etc).

C<$rule> is the rule instance that defines the conditions.

C<$own_conditions> are the conditions specific to an LDAP source.

Conditions that match are added to C<$matching_conditions>.

=cut

sub match_in_subclass {

    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;

    my $logger = Log::Log4perl->get_logger( __PACKAGE__ );

    $logger->debug("Matching rules in LDAP source");

    my $filter = $self->ldap_filter_for_conditions($own_conditions, $rule->match, $self->{'usernameattribute'}, $params);

    $logger->debug("LDAP filter: $filter");

    my ( $connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();
    if (! defined($connection)) {
        $logger->error("Unable to connect to an LDAP server.");
        return undef;
    }

    my $result = $self->bind_with_credentials($connection);

    if ($result->is_error) {
        $logger->error("Unable to bind with $self->{'binddn'} on $LDAPServer:$LDAPServerPort");
        return undef;
    }

    $logger->debug("Searching for $filter, from $self->{'basedn'}, with scope $self->{'scope'}");
    my @attributes = map { $_->{'attribute'} } @{$own_conditions};
    $result = $connection->search(
      base => $self->{'basedn'},
      filter => $filter,
      scope => $self->{'scope'},
      attrs => \@attributes
    );

    if ($result->is_error) {
        $logger->error("Unable to execute search $filter from $self->{'basedn'} on $LDAPServer:$LDAPServerPort, we skip the rule.");
        return undef;
    }

    $logger->debug("Found ".$result->count." results");
    if ($result->count == 1) {
        my $entry = $result->pop_entry();
        my $entry_matches = 1;
        $connection->unbind;

        # Perform match on regexp conditions since they were not included in the LDAP filter
        foreach my $condition (grep { $_->{'operator'} eq $Conditions::MATCHES } @{$own_conditions}) {
            my $attribute = $entry->get_value($condition->{'attribute'});
            my $value = $condition->{'value'};
            if ($attribute && $attribute =~ m/$condition->{'value'}/) {
                $entry_matches = 1;
                last if ($rule->match eq $Rules::ANY)
            }
            else {
                $entry_matches = 0;
                if ($rule->match eq $Rules::ALL) {
                    last;
                }
            }
        }

        if ($entry_matches) {
            # If we found a result, we push all conditions as matched ones.
            # That is normal, as we used them all to build our LDAP filter.
            my $dn = $entry->dn;
            $logger->info("Found a match ($dn)");
            push @{ $matching_conditions }, @{ $own_conditions };
            return $params->{'username'};
        }
    }

    return undef;
}

=head2 test

Test if we can bind and search to the LDAP server

=cut

sub test {
  my ($self) = @_;
  my $logger = Log::Log4perl->get_logger( __PACKAGE__ );

  # Connect
  my ( $connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();

  if (! defined($connection)) {
    $logger->warn("Unable to connect to any LDAP server");
    return ($FALSE, "Can't connect to server");
  }

  # Bind
  my $result = $self->bind_with_credentials($connection);
  if ($result->is_error) {
    $logger->warn("Unable to bind with $self->{'binddn'} on $LDAPServer:$LDAPServerPort");
    return ($FALSE, "Unable to bind to $LDAPServer with these settings");
  }

  # Search
  my $filter = "($self->{'usernameattribute'}=packetfence)";
  $result = $connection->search(
    base => $self->{'basedn'},
    filter => $filter,
    scope => $self->{'scope'},
    attrs => ['dn'],
    sizelimit => 1
  );

  if ($result->is_error) {
      $logger->warn("Unable to execute search $filter from $self->{'basedn'} on $LDAPServer:$LDAPServerPort: ".$result->error);
      return ($FALSE, 'Wrong base DN or username attribute');
  }

  return ($TRUE, 'Success');
}

=head2 ldap_filter_for_conditions

This function is used to generate an LDAP filter based on conditions
from a rule.

=cut

sub ldap_filter_for_conditions {
  my ($self, $conditions, $match, $usernameattribute, $params) = @_;

  # We first check if it's a catch all, if it is, we only
  # check for the usernameattribute - to match it in the source

  my @ldap_conditions;
  my $logical_op = ($match eq $Rules::ANY) ? '|' :   '&';
  my $expression = '(' . $usernameattribute . '=' . $params->{'username'} . ')';
  foreach my $condition (@{$conditions})  {
    my $str;
    my $operator = $condition->{'operator'};
    my $value = escape_filter_value($condition->{'value'});
    my $attribute = $condition->{'attribute'};

    if ($operator eq $Conditions::EQUALS) {
      $str = "${attribute}=${value}";
    } elsif ($operator eq $Conditions::CONTAINS) {
      $str = "${attribute}=*${value}*";
    } elsif ($operator eq $Conditions::STARTS) {
      $str = "${attribute}=${value}*";
    } elsif ($operator eq $Conditions::ENDS) {
      $str = "${attribute}=*${value}";
    }

    if ($str) {
        push(@ldap_conditions, $str);
    }
  }
  if (@ldap_conditions) {
      my $subexpressions = join('',map { "($_)" } @ldap_conditions);
      if (@ldap_conditions > 1) {
          $subexpressions = "(${logical_op}${subexpressions})";
      }
      $expression = "(&${expression}${subexpressions})";
  }

  return $expression;
}

=head2 username_from_email

=cut

sub username_from_email {
    my ( $self, $email ) = @_;

    my $logger = Log::Log4perl->get_logger('pf::authentication');

    my $filter = "(mail=$email)";

    my ( $connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();
    if (! defined($connection)) {
      $logger->error("Unable to connect to $self->{'host'}");
      return undef;
    }

    my $result = $self->bind_with_credentials($connection);

    if ($result->is_error) {
      $logger->error("Unable to bind with $self->{'binddn'}");
      return undef;
    }

    $logger->info("Searching for $filter, from $self->{'basedn'}, with scope $self->{'scope'}");
    $result = $connection->search(
      base => $self->{'basedn'},
      filter => $filter,
      scope => $self->{'scope'},
      attrs => [$self->{'usernameattribute'}]
    );

    if ($result->is_error) {
      $logger->error("Unable to execute search: " . $result->error);
      next;
    }

    if ($result->count == 1) {
      my $username = $result->entry->get_value( $self->{'usernameattribute'} );
      $connection->unbind;
      $logger->info("LDAP:found a match in username_from_email ($email => $username)");
      return $username;
    }

    $logger->info("No match found for filter: $filter");
    return undef;
}


sub bind_with_credentials {
    my ($self,$connection) = @_;
    my $result;
    if ($self->{'binddn'} && $self->{'password'}) {
        $result = $connection->bind($self->{'binddn'}, password => $self->{'password'});
    } else {
        $result = $connection->bind;
    }
    return $result;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
