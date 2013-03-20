package Config5::System::SystemInfo;
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

# Config5::System::SystemInfo - System Information via system-info
#
# $Id: SystemInfo.pm 198 2013-03-19 15:14:36Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/examples/modules/System/SystemInfo.pm $

use strict;
use warnings;

use Sys::Hostname;
use Socket;

use Config5::Util qw(slurp fail info run change_root is_change_root);


sub new
{
   my ($perlclass, $file, $nolocal) = @_;

   my $self = $perlclass->SUPER::new($nolocal);
   my $items = $::SETTINGS->{system}->{items};
   $file = change_root($::SETTINGS->{system}->{systeminfo}->{file})
      unless defined $file;

   # Determine items from current system which can only be done if not chrooted
   unless (is_change_root() || $nolocal)
   {
      # Read the number of CPUs
      if ($items->{processors})
      {
         my $procs = 0;
         map { $procs++ if /^processor\s+\:\s+\d+$/ } slurp '/proc/cpuinfo';
         $self->set('processors', $procs);
      }

      # OS release
      if ($items->{release}) 
      {
         my ($rc, $string) = run('lsb_release', '-r', '-s');
         fail "Cannot run 'lsb_release -r' to determine OS release"
         if $rc || ! defined $string || $string !~ /^(\S+)/;
         $self->set('release', $1);
      }
   }

   # Parse system-info file and add all known items
   my %items;
   map { $items{lc $1} = $2 if /^(\S+)=(.+)/ } slurp $file;
   map { $self->set($_, $items{$_}) } keys %items;

   # Map remaining system-info entries to properties according to configuration
   foreach my $item (@{$::SETTINGS->{system}->{systeminfo}->{append_properties}})
   {
      next unless defined $items{$item};
      my $bool = lc $items{$item};
      $self->append('properties', $item)
         if $bool eq '1' || $bool eq 'on' || $bool eq 'yes';
   }

   # Set default properties
   foreach my $entry (@{$::SETTINGS->{system}->{systeminfo}->{default_properties}})
   {
      my ($default, @others) = @{$entry};
      map { next if $self->is_in_list('properties', $_) } @others;
      $self->append('properties', $default);
   }

   bless $self, $perlclass;
}


1;
