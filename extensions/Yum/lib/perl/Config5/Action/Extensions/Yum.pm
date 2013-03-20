package Config5::Action::Extensions::Yum;
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

# Config5::Action::Extensions::Yum - Action
#
# $Id: Yum.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/Yum/lib/perl/Config5/Action/Extensions/Yum.pm $

use strict;
use warnings;

use Config5::Util qw(run is_change_root);

# PROTOTYPES
sub apply();
sub check();
sub install($;$);
sub is_installed($);
sub progress($);
sub uninstall($);

my %CACHE;
my $CLEAN;


sub new
{
   my ($perlclass, $change, $class, $system) = @_;
   
   my $self = $perlclass->SUPER::new($change, $class, $system);
   bless $self, $perlclass;
}


sub apply()
{
   my ($self) = @_;
   
   my $action = $self->{change}->{action};
   my $pkg = $self->{change}->{package};
      
   my $rv;
   if ($action eq 'install') {
      $rv = install($pkg, $self->{change}->{repo});
   } elsif ($action eq 'uninstall') {
      $rv = uninstall($pkg);
   }

   $self->action_error("Failed to $action package '$pkg'")
      unless $rv;
    
   return $rv;
}


sub check()
{
   my ($self) = @_;
   
   return SKIP_CHROOT_NOT_SUPPORTED if is_change_root();

   my $action = $self->{change}->{action};
   my $pkg = $self->{change}->{package};

   if ($action eq 'install') {
      return is_installed($pkg) ? SKIP_NO_CHANGE : CHANGE_CREATE; 
   } elsif ($action eq 'uninstall') {
      return is_installed($pkg) ? CHANGE_REMOVE : SKIP_NO_CHANGE; 
   }
}


sub progress($)
{
   my ($self, $code) = @_;

   $self->SUPER::progress('package', $self->{change}->{action} . ' ' . $self->{change}->{package}, $code);
}


sub is_installed($)
{
   my ($pkg) = @_;

   return $CACHE{$pkg} if defined $CACHE{$pkg};

   my ($rv) = run('rpm', '-q', $pkg);
   
   $CACHE{$pkg} = $rv == 0 ? 1 : 0;

   return $CACHE{$pkg};
}


sub install($;$)
{
   my ($pkg, $repo) = @_;

   return 1 if is_installed($pkg);
   undef %CACHE;

   # Clean cache to be sure we get the latest updates
   run('yum', '-q', 'clean', 'all'), $CLEAN = 1
      unless $CLEAN;

   if (defined $repo) {
      run('yum', '-q', '-y', '--enablerepo', $repo, 'install', $pkg);
   } else {
      run('yum', '-q', '-y', 'install', $pkg);
   }

   return is_installed($pkg);
}


sub uninstall($)
{
   my ($pkg) = @_;

   return 1 unless is_installed($pkg);
   undef %CACHE;

   run('yum', '-q', '-y', 'remove', $pkg);

   return ! is_installed($pkg);
}


1;
