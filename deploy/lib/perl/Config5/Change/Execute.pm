package Config5::Change::Execute;
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

# Config5::Change::Execute - Change
#
# $Id: Execute.pm 186 2012-10-25 08:17:18Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Change/Execute.pm $

use strict;
use warnings;


sub new
{
   my ($perlclass, $feature, $class, $keyword, $line, $lineno) = @_;
   
   my $self = $perlclass->SUPER::new($feature, $class, $keyword, $line, $lineno);

   $self->{command} = $self->{args};

   bless $self, $perlclass;

   $self->check('', 'bntT');
}


1;
