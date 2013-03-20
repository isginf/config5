package Config5::Change::Extensions::GConf;
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

# Config5::Change::Extensions::GConf - Change
#
# $Id: GConf.pm 161 2012-08-23 05:52:24Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/GConf/lib/perl/Config5/Change/Extensions/GConf.pm $

use strict;
use warnings;

use Config5::Util qw(fail tokenize);


my %ACTIONS =
(
   'set' => 1, 'clear' => 1,
);


sub new
{
   my ($perlclass, $feature, $class, $keyword, $line, $lineno) = @_;
   
   my $self = $perlclass->SUPER::new($feature, $class, $keyword, $line, $lineno);
   bless $self, $perlclass;

   my $args = $self->{args};
   ($self->{action}, $self->{key}, $args) = $self->parse($args, 2);

   fail "Invalid action '$self->{action}' in " . $self->identify() 
      unless defined $ACTIONS{$self->{action}};

   my $flags ='ntT';

   if ($self->{action} eq 'set')
   {
      ($self->{value}, $args) = $self->parse($args, 1);
      ($self->{type}, $args) = tokenize $args, 1;
      $flags .= 'b';
   }

   $self->check($args, $flags);
}


1;
