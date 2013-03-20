package Config5::Action::Link;
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

# Config5::Action::Link - Action
#
# $Id: Link.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Action/Link.pm $

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

   my $source = change_root($self->{change}->{source});
   my $path = change_root($self->{change}->{path});

   my $tmp = $self->make_temp($path);

   $self->action_error("Unable to create link '$path' to '$source'"), return
      unless link $source, $tmp;

   return $self->rename_temp($tmp, $path);
}


sub check()
{
   my ($self) = @_;

   my $source = change_root($self->{change}->{source});
   my $path = change_root($self->{change}->{path});

   my ($dev1, $inode1) = lstat $source or return CHANGE_CREATE;
   my ($dev2, $inode2) = lstat $path or return CHANGE_CREATE;
  
   return $dev1 == $dev2 && $inode1 == $inode2 ? SKIP_NO_CHANGE : CHANGE_CONTENT;
}


sub progress($)
{
   my ($self, $code) = @_;

   $self->SUPER::progress($self->{change}->{path} . ': ' . $::SETTINGS->{display}->{changes}->{link}, '', $code);
}

   
1;
