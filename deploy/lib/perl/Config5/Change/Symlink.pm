package Config5::Change::Symlink;
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

# Config5::Change::Symlink - Change
#
# $Id: Symlink.pm 198 2013-03-19 15:14:36Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Change/Symlink.pm $

use strict;
use warnings;


sub new
{
   my ($perlclass, $feature, $class, $keyword, $line, $lineno) = @_;

   my $self = $perlclass->SUPER::new($feature, $class, $keyword, $line, $lineno);
   bless $self, $perlclass;

   my $args = $self->{args};
   ($self->{value}, $args) = $self->parse($args, 1);
   ($self->{path}, $args) = $self->parse_path($args);
   ($self->{permissions}, $args) = $self->parse_permissions($args);
   
   $self->check($args, 'bntT');
}


1;
