package Config5::Action::Remove;
use Config5::Action;
use base Config5::Action;

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

# Config5::Action::Remove - Action
#
# $Id: Remove.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Action/Remove.pm $

use strict;
use warnings;

use Config5::Util qw(change_root);

# PROTOTYPES
sub apply();
sub check();
sub progress($);


sub new
{
   my ($perlclass, $change, $class, $system) = @_;

   my $self = $perlclass->SUPER::new($change, $class, $system);
   bless $self, $perlclass;
}


sub apply()
{
   my ($self) = @_;

   my $path = change_root($self->{change}->{path});
      
   my $count;
   if ( -d $path && ! -l $path ) {
      $count = rmdir $path;
   } else {
      $count = unlink $path;
   }

   $self->action_error("Unable to remove '$path'")
      if $count == 0;
    
   return $count;
}


sub check()
{
   my ($self) = @_;
   
   my $path = change_root($self->{change}->{path});

   -e $path ? CHANGE_REMOVE : SKIP_NO_CHANGE;
}


sub progress($)
{
   my ($self, $code) = @_;

   $self->SUPER::progress($self->{change}->{path} . ': ' . $::SETTINGS->{display}->{changes}->{remove}, '', $code);
}


1;
