package Config5::Owner;

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

# Config5::Owner - Ownership
#
# $Id: Owner.pm 186 2012-10-25 08:17:18Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Owner.pm $

use strict;
use warnings;

use Config5::Util;

# PROTOTYPES
sub get_gid();
sub get_uid();


sub new
{
   my ($perlclass, $change, $user, $group) = @_;
   my ($self, $uid, $gid);

   if (! defined $user || $user eq '-') {
      $uid = -1;
   } elsif ($user =~ /^\d+$/) {
      $uid = $user;   
   }
    
   if (! defined $group || $group eq '-') {
      $gid = -1;
   } elsif ($group =~ /^\d+$/) {
      $gid = $group;   
   }
     
   $self->{user} = $user;
   $self->{uid} = $uid;
   $self->{group} = $group;
   $self->{gid} = $gid;
   $self->{change} = $change;

   bless $self, $perlclass;
   $self;
}


sub get_uid()
{
   my ($self) = @_;

   return $self->{uid}
      if defined $self->{uid};

   (undef, undef, $self->{uid}) = getpwnam($self->{user});
   fail "Unknown user '" . $self->{user} . "' in " . $self->{change}->identify()
      unless defined $self->{uid};

   return $self->{uid};
}

sub get_gid()
{
   my ($self) = @_;

   return $self->{gid}
      if defined $self->{gid};

   (undef, undef, $self->{gid}) = getgrnam($self->{group});
   fail "Unknown group '" . $self->{group} . "' in " . $self->{change}->identify()
      unless defined $self->{gid};
   
   return $self->{gid};
}


1;
