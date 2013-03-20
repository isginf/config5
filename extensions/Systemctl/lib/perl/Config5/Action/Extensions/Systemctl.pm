package Config5::Action::Extensions::Systemctl;
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

# Config5::Action::Extensions::Systemctl - Action
#
# $Id: Systemctl.pm 195 2013-03-19 07:18:17Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/Systemctl/lib/perl/Config5/Action/Extensions/Systemctl.pm $

use strict;
use warnings;

use Config5::Util qw(run is_change_root);

# PROTOTYPES
sub apply();
sub check();
sub disable($);
sub enable($);
sub is_enabled($);
sub is_started($);
sub progress($);
sub start($);
sub stop($);
sub update_cache();

my %CACHE;
my $CLEAN;
my $DISABLED;


sub new
{
   my ($perlclass, $change, $class) = @_;
   
   my $self = $perlclass->SUPER::new($change, $class);
   bless $self, $perlclass;
}


sub apply()
{
   my ($self) = @_;
   
   my $action = $self->{change}->{action};
   my $service = $self->{change}->{service};

   my $rv;
   if ($action eq 'enable') {
      $rv = enable($service);
   } elsif ($action eq 'disable') {
      $rv = disable($service);
   } elsif ($action eq 'start') {
      $rv = start($service);
   } elsif ($action eq 'stop') {
      $rv = stop($service);
   } 

   $self->action_error("Failed to $action service '$service'")
      unless $rv;
   
   return $rv;
}


sub check()
{
   my ($self) = @_;
   
   return SKIP_CHROOT_NOT_SUPPORTED if is_change_root();

   my $action = $self->{change}->{action};
   my $service = $self->{change}->{service};

   if ($action eq 'enable') {
      return is_enabled($service) ? SKIP_NO_CHANGE : CHANGE_CONTENT;
   } elsif ($action eq 'disable') {
      return is_enabled($service) ? CHANGE_CONTENT : SKIP_NO_CHANGE;
   } elsif ($action eq 'start') {
      return is_started($service) ? SKIP_NO_CHANGE : CHANGE_CONTENT;
   } elsif ($action eq 'stop') {
      return is_started($service) ? CHANGE_CONTENT : SKIP_NO_CHANGE;
   } 
}


sub progress($)
{
   my ($self, $code) = @_;

   $self->SUPER::progress('service', $self->{change}->{action} . ' ' .  $self->{change}->{service}, $code);
}


sub start($)
{
   my ($service) = @_;

   $service .= '.service' unless $service =~ /\./;

   return if is_started($service);

   run('systemctl', 'start', $service);
   $CLEAN = 0;

   return is_started($service);
}


sub stop($)
{
   my ($service) = @_;

   $service .= '.service' unless $service =~ /\./;

   return unless is_started($service);

   run('systemctl', 'stop', $service);
   $CLEAN = 0;

   return ! is_started($service);
}


sub enable($)
{
   my ($service) = @_;

   $service .= '.service' unless $service =~ /\./;

   return if is_enabled($service);

   run('systemctl', 'enable', $service);

   return is_enabled($service);
}


sub disable($)
{
   my ($service) = @_;

   $service .= '.service' unless $service =~ /\./;

   return unless is_enabled($service);

   run('systemctl', 'disable', $service);

   return ! is_enabled($service);
}


sub update_cache()
{
   return if $CLEAN || $DISABLED;

   my ($rv, @list) = run('systemctl', '--full', '--quiet', '--all');
   $DISABLED = 1, return if $rv;

   undef %CACHE;
   foreach (@list)
   {
      # Stop at first empty line to skip the rest of the information
      last if /^$/;

      next unless /^(\S+)\s+\S+\s+(\S+)/;
      $CACHE{$1} = $2 eq 'active' ? 1 : 0;
   }

   # Disable caching if the list is empty
   $DISABLED = 1 unless %CACHE;

   $CLEAN = 1;
}


# 1: started, 0: stopped, unknown or not loaded
sub is_started($)
{
   my ($service) = @_;

   $service .= '.service' unless $service =~ /\./;

   update_cache();

   return defined $CACHE{$service} && $CACHE{$service} == 1
      unless $DISABLED;

   my ($rv) = run('systemctl', 'is-active', $service);

   return $rv == 0 ? 1 : 0;
}


# 1: enabled, 0: disabled, unknown or not loaded
sub is_enabled($)
{
   my ($service) = @_;

   $service .= '.service' unless $service =~ /\./;

   my ($rv) = run('systemctl', 'is-enabled', $service);

   return $rv == 0 ? 1 : 0;
}


1;

