package Config5::Action::Extensions::GConf;
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

# Config5::Action::Extensions::GConf - Action
#
# $Id: GConf.pm 198 2013-03-19 15:14:36Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/GConf/lib/perl/Config5/Action/Extensions/GConf.pm $

use strict;
use warnings;

use Config5::Util qw(run fail is_change_root);

# PROTOTYPES
sub apply();
sub check();
sub check_clear($);
sub check_set($$);
sub clear($);
sub get_source();
sub progress($);
sub set($$;$);

my $SOURCE;


sub new
{
   my ($perlclass, $change, $class, $system, $subst) = @_;
   
   my $self = $perlclass->SUPER::new($change, $class, $system, $subst);
   bless $self, $perlclass;
}


sub apply()
{
   my ($self) = @_;
   
   my $action = $self->{change}->{action};
   my $key = $self->{change}->{key};
      
   my $rv;
   if ($action eq 'set') {
      $rv = $self->set($key, $self->{change}->{value}, $self->{change}->{type});
   } elsif ($action eq 'clear') {
      $rv = clear($key);
   }

   $self->action_error("Failed to $action key '$key'")
      unless $rv;

   return $rv;
}


sub check()
{
   my ($self) = @_;
   
   return SKIP_CHROOT_NOT_SUPPORTED if is_change_root();

   my $action = $self->{change}->{action};
   my $key = $self->{change}->{key};

   if ($action eq 'set') {
      return $self->check_set($key, $self->{change}->{value}) ? SKIP_NO_CHANGE : CHANGE_CONTENT; 
   } elsif ($action eq 'clear') {
      return check_clear($key) ? SKIP_NO_CHANGE : CHANGE_CONTENT; 
   }
}


sub progress($)
{
   my ($self, $code) = @_;

   my $action = $self->{change}->{action};
  
   $self->SUPER::progress('', "$action " . $self->{change}->{key} . ($action eq 'set' ? ": '" . $self->{change}->{value} . "'" : ''), $code);
}


# 1: set, 0: cleared/error
sub check_set($$)
{
   my ($self, $key, $new) = @_;

   my ($rv, $old) = run($::SETTINGS->{extension}->{gconf}->{command}, '--config-source', get_source(), '--direct', '--get', $key);
   return 0 if $rv || ! defined $old || $old ne $self->substitute($new); 
   
   return 1;
}


sub set($$;$)
{
   my ($self, $key, $new, $type) = @_;

   $type = 'string' unless defined $type;
   run($::SETTINGS->{extension}->{gconf}->{command}, '--config-source', get_source(), '--direct', '--type', $type, '--set', $key, $self->substitute($new));

   return $self->check_set($key, $new);
}


# 1: cleared, 0: set/error
sub check_clear($)
{
   my ($key) = @_;

   my ($rv, $value) = run($::SETTINGS->{extension}->{gconf}->{command}, '--config-source', get_source(), '--direct', '--get', $key);
   return 0 if defined $value;

   return 1;
}


sub clear($)
{
   my ($key) = @_;

   my ($rv, $value) = run($::SETTINGS->{extension}->{gconf}->{command}, '--config-source', get_source(), '--direct', '--unset', $key);

   return check_clear($key);
}


sub get_source()
{
   return $SOURCE if defined $SOURCE;
 
   my $rv;
   ($rv, $SOURCE) = run($::SETTINGS->{extension}->{gconf}->{command}, '--get-default-source');
   fail "Failed to obtain GConf default source"
      if $rv || ! $SOURCE;

   return $SOURCE;
}


1;

