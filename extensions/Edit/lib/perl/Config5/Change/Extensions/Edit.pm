package Config5::Change::Extensions::Edit;
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

# Config5::Change::Extensions::Edit - Change
#
# $Id: GConf.pm 647 2011-08-04 08:42:35Z walteste $
# $HeadURL: file:///import/svn/repositories/config5-rhel6/svn/trunk/lib/perl/Config5/Change/Extensions/GConf.pm $

use strict;
use warnings;

use Config5::Util qw(fail tokenize);


my %ACTIONS =
(
   'add' => 1, 'remove' => 1, 'replace' => 1, 'modify' => 1
);


sub new
{
   my ($perlclass, $feature, $class, $keyword, $line, $lineno) = @_;
   
   my $self = $perlclass->SUPER::new($feature, $class, $keyword, $line, $lineno);
   $self->{list_file} = 1;
   bless $self, $perlclass;

   my $args = $self->{args};
   ($self->{action}, $self->{path}, $args) = $self->parse($args, 2);

   fail "Invalid action '$self->{action}' in " . $self->identify() 
      unless defined $ACTIONS{$self->{action}};

   if ($self->{action} eq 'add') {
      ($self->{line}, $args) = $self->parse($args, 1);
      ($self->{re}, $args) = tokenize $args, 1;
   } elsif ($self->{action} eq 'remove') {
      ($self->{re}, $args) = $self->parse($args, 1);
   } else { # 'replace' and 'modify'
      ($self->{re}, $self->{line}, $args) = $self->parse($args, 2);
   }

   if (defined $self->{re}) {
      fail "Invalid regular expression '$self->{re}' in " . $self->identify()
         unless eval { qr/$self->{re}/ };
   }

   $self->check($args, 'bntT');
}


1;
