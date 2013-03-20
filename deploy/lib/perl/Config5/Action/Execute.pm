package Config5::Action::Execute;
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

# Config5::Action::Execute - Action
#
# $Id: Execute.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Action/Execute.pm $

use strict;
use warnings;

use Template;

use Config5::Util qw(run is_change_root info);
use Config5::Permissions;

# PROTOTYPES
sub apply();
sub check();
sub progress($);


sub new
{
   my ($perlclass, $change, $class, $system, $subst) = @_;
   
   my $self = $perlclass->SUPER::new($change, $class, $system, $subst);
   bless $self, $perlclass;
}


sub apply()
{
   my ($self) = @_;

   my $cmd = $self->substitute($self->{change}->{command});

   my ($rv, @output) = run($cmd);

   info join('',"===== Output =====\n", @output, "=================="), 4;
   $self->action_error("Command '$cmd' returned $rv"), return
      if $rv;

   return 0;
}


sub check()
{
   unless ($::SETTINGS->{builtin}->{execute}->{allow_chroot}) {
     return SKIP_CHROOT_NOT_SUPPORTED if is_change_root();
   }

   return CHANGE_ALWAYS;
}


sub progress($)
{
   my ($self, $code) = @_;

   my $cmd = $self->substitute($self->{change}->{command});

   $self->SUPER::progress(undef, $cmd, $code);
}


1;
