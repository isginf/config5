package Config5::Change::Append;
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

# Config5::Change::Append - Change
#
# $Id: Append.pm 180 2012-08-27 14:09:33Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Change/Append.pm $

use strict;
use warnings;


sub new
{
   my ($perlclass, $feature, $class, $keyword, $line, $lineno) = @_;

   my $self = $perlclass->SUPER::new($feature, $class, $keyword, $line, $lineno);
   $self->{is_generator} = 1;   
   bless $self, $perlclass;

   my $args = $self->{args};
   ($self->{input}, $args) = $self->parse_featurefile($args);
   ($self->{path}, $args) = $self->parse_path($args);
   ($self->{subst}, $args) = $self->parse_substitutions($args);

   $self->check($args, 'b');
}


1;
