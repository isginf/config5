package Config5::System::Hardwired;
use base Config5::System;

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

# Config5::System::LSB - System Information via Linux Standard Base
#
# $Id: Hardwired.pm 2405 2013-03-18 07:36:50Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5-rhel6/trunk/lib/perl/Config5/System/Hardwired.pm $

use strict;
use warnings;

use Config5::Util qw(fail run);

sub new
{
   my ($perlclass) = @_;

   my $self = $perlclass->SUPER::new();
   my $items = $::SETTINGS->{system}->{items};

   foreach my $item (keys %$items)
   {
      next if defined $self->{$item};
      $self->set($item, $::SETTINGS->{system}->{hardwired}->{$item});
   }

   bless $self, $perlclass;
}

1;

