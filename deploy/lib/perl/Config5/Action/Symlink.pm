package Config5::Action::Symlink;
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

# Config5::Action::Symlink - Action
#
# $Id: Symlink.pm 198 2013-03-19 15:14:36Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Action/Symlink.pm $

use strict;
use warnings;

use Config5::Util qw(change_root);
use Config5::Permissions;

# PROTOTYPES
sub apply($);
sub check();
sub progress($);


sub new
{
   my ($perlclass, $change, $class, $system, $subst) = @_;

   my $self = $perlclass->SUPER::new($change, $class, $system, $subst);
   bless $self, $perlclass;
}


sub apply($)
{
   my ($self, $code) = @_;

   my $path = change_root($self->{change}->{path});
   my $value = $self->substitute($self->{change}->{value});

   if ($code >= CHANGE_CONTENT)
   {
      unlink($path), rmdir($path) unless -l $path;

      my $tmp = $self->make_temp($path);

      $self->action_error("Unable to create symbolic link '$path'"), return
         unless symlink $value, $tmp;

      unlink($tmp), return
         unless $self->{change}->{permissions}->apply($tmp);

      return $self->rename_temp($tmp, $path);
   }

   return $self->{change}->{permissions}->apply($path);
}


sub check()
{
   my ($self) = @_;

   my $path = change_root($self->{change}->{path});
   my $value = $self->substitute($self->{change}->{value});

   return CHANGE_CREATE unless -l $path;
   
   my $oldvalue = readlink $path;
   return CHANGE_CONTENT if $value ne $oldvalue;
   return CHANGE_PROPERTIES if $self->{change}->{permissions}->check($path);

   return SKIP_NO_CHANGE;
}


sub progress($)
{
   my ($self, $code) = @_;

   $self->SUPER::progress($self->{change}->{path} . ': ' . $::SETTINGS->{display}->{changes}->{symlink}, '', $code);
}


1;
