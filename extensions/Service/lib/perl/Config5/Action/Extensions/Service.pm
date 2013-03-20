package Config5::Action::Extensions::Service;
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

# Config5::Action::Extensions::Service - Action
#
# $Id: Service.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/Service/lib/perl/Config5/Action/Extensions/Service.pm $

use strict;
use warnings;

use Config5::Util qw(run fail is_change_root);

# PROTOTYPES
sub add($);
sub apply();
sub check();
sub disable($);
sub enable($);
sub is_added($);
sub is_disabled($);
sub is_enabled($);
sub is_started($);
sub progress($);
sub remove($);
sub start($);
sub stop($);
sub update_cache();

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
   my $service = $self->{change}->{service};

   my $rv;
   if ($action eq 'add') {
      $rv = add($service);
   } elsif ($action eq 'remove') {
      $rv = remove($service);
   } elsif ($action eq 'enable') {
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

   if ($action eq 'add') {
      return is_added($service) ? SKIP_NO_CHANGE : CHANGE_CREATE;
   } elsif ($action eq 'remove') {
      return is_added($service) ? CHANGE_REMOVE : SKIP_NO_CHANGE;
   } elsif ($action eq 'enable') {
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

   run('service', $service, 'start');

   return is_started($service);
}


sub stop($)
{
   my ($service) = @_;

   return unless is_started($service);

   run('service', $service, 'stop');

   return ! is_started($service);
}


sub enable($)
{
   my ($service) = @_;

   return if is_enabled($service);

   run('chkconfig', $service, 'on');
   $CLEAN = 0;
   
   return is_enabled($service);
}


sub disable($)
{
   my ($service) = @_;

   return if is_disabled($service);

   run('chkconfig', $service, 'off');
   $CLEAN = 0;

   return is_disabled($service);
}


sub add($)
{
   my ($service) = @_;

   update_cache();
   return if defined $CACHE{$service};

   run('chkconfig', '--add', $service);
   $CLEAN = 0;

   return is_added($service);
}


sub remove($)
{
   my ($service) = @_;

   update_cache();
   return unless defined $CACHE{$service};

   run('chkconfig', '--remove', $service);
   $CLEAN = 0;

   return ! is_added($service);
}


sub update_cache()
{
   return if $CLEAN;

   my ($rv, @list) = run('chkconfig', '--list', '--type', 'sysv');
   fail "Cannot get list of services" if $rv;

   undef %CACHE;
   foreach my $line (@list)
   {
      my ($name,@status) = split /\s+/, $line;
      map { $CACHE{$name}->{$1} = $2 if /^(\d)\:(\S+)$/ } @status;
   } 

   $CLEAN = 1;
}


# 1: service added: 0: service not added
sub is_added($)
{
   my ($service) = @_;
   
   update_cache();
   return defined $CACHE{$service};
}


# 1: at least one on, undef: all off or unknown service
sub is_enabled($)
{
   my ($service) = @_;

   update_cache();
   return unless defined $CACHE{$service};

   my $flag;
   map { $flag = 1 if defined $CACHE{$service}->{$_} && $CACHE{$service}->{$_} eq 'on' } 1..5;

   return $flag;
}


# 1: all off, undef: some on or unknown service
sub is_disabled($)
{
   my ($service) = @_;

   update_cache();
   return 1 unless defined $CACHE{$service};

   map { return unless defined $CACHE{$service}->{$_} && $CACHE{$service}->{$_} eq 'off' } 0..6;

   return 1;
}


# 1: started, 0: stopped or unknown service
sub is_started($)
{
   my ($service) = @_;

   my ($rv) = run('service', $service, 'status');

   return $rv == 0;
}


1;
