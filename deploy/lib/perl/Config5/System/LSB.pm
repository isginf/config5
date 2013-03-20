package Config5::System::LSB;
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
# $Id: LSB.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/System/LSB.pm $

use strict;
use warnings;

use Config5::Util qw(fail run is_change_root);

sub new
{
   my ($perlclass) = @_;

   my $self = $perlclass->SUPER::new();

   bless $self, $perlclass;

   # This module is only meaningful if not running chrooted
   unless (is_change_root())
   {
      my ($rc, $string);
      my $items = $::SETTINGS->{system}->{items};

      # OS ID
      if ($items->{os}) 
      {
         ($rc, $string) = run('lsb_release', '-i', '-s');
         fail "Cannot run 'lsb_release -i' to determine OS id"
            if $rc || ! defined $string || $string !~ /^(\S+)/;
         my $os = $1;

         if ($::SETTINGS->{system}->{lsb}->{append_code})
         {
            ($rc, $string) = run('lsb_release', '-c', '-s');
            fail "Cannot run 'lsb_release -c' to determine OS code name"
               if $rc || ! defined $string || $string !~ /^(\S+)/;
            $os .= "-$1"; 
         }

         $self->set('os', $os);
      }

      # OS Release
      if ($items->{release})
      {
         ($rc, $string) = run('lsb_release', '-r', '-s');
         fail "Cannot run 'lsb_release -r' to determine OS release"
            if $rc || ! defined $string || $string !~ /^(\S+)/;
         $self->set('release', $1);
      }
   }

   return $self;
}

1;

