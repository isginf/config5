package Config5::Change::Extensions::Augeas;
use base Config5::Change;

# Copyright 2011 ETH Zurich, ISGINF
#
# This file is part of Config5.
#
# Config5 is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Config5 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Config5.  If not, see <http://www.gnu.org/licenses/>.

# Config5::Change::Extensions::Augeas - Change
#
# $Id: Augeas.pm 199 2013-03-20 08:08:00Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/Augeas/lib/perl/Config5/Change/Extensions/Augeas.pm $

use strict;
use warnings;

use Config5::Util qw(fail);


my %ACTIONS =
(
   'set' => 1, 'remove' => 1, 'insert' => 1, 'replace' => 1
);

my %LOCATIONS =
(
   'before' => 1, 'after' => 1
);


sub new
{
   my ($perlclass, $feature, $class, $keyword, $line, $lineno) = @_;
   
   my $self = $perlclass->SUPER::new($feature, $class, $keyword, $line, $lineno);
   bless $self, $perlclass;

   my $args = $self->{args};
   ($self->{action}, $args) = $self->parse($args, 1);

   fail "Invalid action '$self->{action}' in " . $self->identify() 
      unless defined $ACTIONS{$self->{action}};
 
   my $flags = 'ntT';

   if ($self->{action} eq 'remove') {
      ($self->{path}, $args) = $self->parse($args, 1);
   } elsif ($self->{action} eq 'set') {
      ($self->{path}, $self->{value}, $args) = $self->parse($args, 2);
      $flags .= 'b';
   } elsif ($self->{action} eq 'replace') {
      ($self->{path}, $self->{pattern}, $self->{value}, $args) = $self->parse($args, 3);
      $flags .= 'b';
   } elsif ($self->{action} eq 'insert') {
      ($self->{label}, $self->{location}, $self->{path}, $args) = $self->parse($args, 3);
     
      fail "Invalid location '$self->{location}' in " . $self->identify()
         unless defined $LOCATIONS{$self->{location}};
   }

   $self->check($args, $flags);
}


1;
