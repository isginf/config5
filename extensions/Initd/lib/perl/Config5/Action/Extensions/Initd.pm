package Config5::Action::Extensions::Initd;
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

# Config5::Action::Extensions::Initd - Action
#
# $Id: Initd.pm 195 2013-03-19 07:18:17Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/Initd/lib/perl/Config5/Action/Extensions/Initd.pm $

use strict;
use warnings;

use Config5::Util qw(run is_change_root);

# PROTOTYPES
sub apply();
sub check();
sub disable($);
sub enable($);
sub is_disabled($);
sub is_enabled($);
sub is_started($);
sub progress($);
sub start($);
sub stop($);
sub update_cache();

my %CACHE;
my $CLEAN;


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
      return is_disabled($service) ? SKIP_NO_CHANGE : CHANGE_CONTENT;
   } elsif ($action eq 'start') {
      return is_started($service) ? SKIP_NO_CHANGE : CHANGE_CONTENT;
   } elsif ($action eq 'stop') {
      return is_started($service) ? CHANGE_CONTENT : SKIP_NO_CHANGE;
   } 
}


sub progress($)
{
   my ($self, $code) = @_;

   $self->SUPER::progress('service', $self->{change}->{action} . ' ' . $self->{change}->{service}, $code);
}


sub start($)
{
   my ($service) = @_;

   return if is_started($service);

   run("/etc/init.d/$service", 'start');

   return is_started($service);
}


sub stop($)
{
   my ($service) = @_;

   return unless is_started($service);

   run("/etc/init.d/$service", 'stop');

   return ! is_started($service);
}


sub enable($)
{
   my ($service) = @_;

   return if is_enabled($service);

   run('update-rc.d', $service, 'defaults');
   $CLEAN = 0;
   
   return is_enabled($service);
}


sub disable($)
{
   my ($service) = @_;

   return if is_disabled($service);

   run('update-rc.d', '-f', $service, 'remove');
   $CLEAN = 0;

   return is_disabled($service);
}


# 1: at least one on, undef: all off or unknown service
sub is_enabled($)
{
   my ($service) = @_;

   update_cache();
   return unless defined $CACHE{$service};

   my $flag;
   map { $flag = 1 if $CACHE{$service}->{$_} } 1..5;

   return $flag;
}


# 1: all off, undef: some on or unknown service
sub is_disabled($)
{
   my ($service) = @_;

   update_cache();
   return 1 unless defined $CACHE{$service};

   map { return if $CACHE{$service}->{$_} } 0..6, 'S';

   return 1;
}


# 1: started, 0: stopped or unknown service
sub is_started($)
{
   my ($service) = @_;

   my ($rv) = run("/etc/init.d/$service", 'status');

   return $rv == 0;
}


sub update_cache()
{
   return if $CLEAN;

   undef %CACHE;

   foreach my $level ( 0..6, 'S' )
   {
      my $dir = "/etc/rc${level}.d";
      opendir my $dh, $dir
         or next;

      foreach my $link (readdir $dh)
      {
         next if $link eq '.' || $link eq '..';
         next unless $link =~ /^S\d+/;

         next unless -l "$dir/$link";
         my $value = readlink "$dir/$link";
         next unless defined $value && $value =~ /\/([^\/]+)$/;

         $CACHE{$1}->{$level} = 1;
      }

      closedir $dh;
   }
}


1;
