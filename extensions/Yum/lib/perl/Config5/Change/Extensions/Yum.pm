package Config5::Change::Extensions::Yum;
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

# Config5::Change::Extensions::Yum - Change
#
# $Id: Yum.pm 174 2012-08-23 11:46:25Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/Yum/lib/perl/Config5/Change/Extensions/Yum.pm $

use strict;
use warnings;

use Config5::Util qw(fail tokenize);


my %ACTIONS =
(
   'install' => 1, 'uninstall' => 1,
);


sub new
{
   my ($perlclass, $feature, $class, $keyword, $line, $lineno) = @_;
   
   my $self = $perlclass->SUPER::new($feature, $class, $keyword, $line, $lineno);
   bless $self, $perlclass;

   my $args = $self->{args};
   ($self->{action}, $self->{package}, $args) = $self->parse($args, 2);
   ($self->{repo}, $args) = tokenize $args if $self->{action} eq 'install';

   fail "Invalid action '$self->{action}' in " . $self->identify() 
      unless defined $ACTIONS{$self->{action}};

   $self->check($args);
}


1;
