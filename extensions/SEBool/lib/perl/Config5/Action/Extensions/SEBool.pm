package Config5::Action::Extensions::SEBool;
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

# Config5::Action::Extensions::SEBool - Action
#
# $Id: SEBool.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/SEBool/lib/perl/Config5/Action/Extensions/SEBool.pm $

use strict;
use warnings;

use Config5::Util qw(run fail error is_change_root);

# PROTOTYPES
sub apply();
sub check();
sub clear($);
sub commit();
sub is_cleared($);
sub is_set($);
sub progress($);
sub set($);
sub update_cache();

my %CACHE;
my %CHANGES;
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
   my $bool = $self->{change}->{boolean};
      
   my $rv;
   if ($action eq 'set') {
      $rv = set($bool);
   } elsif ($action eq 'clear') {
      $rv = clear($bool);
   }

   $self->action_error("Unknown SELinux boolean '$bool'")
         unless $rv;

   return -1;
}


sub check()
{
   my ($self) = @_;
   
   return SKIP_CHROOT_NOT_SUPPORTED if is_change_root();

   my $action = $self->{change}->{action};
   my $bool = $self->{change}->{boolean};

   if ($action eq 'set') {
      return is_set($bool) ? SKIP_NO_CHANGE : CHANGE_CONTENT; 
   } elsif ($action eq 'clear') {
      return is_cleared($bool) ? SKIP_NO_CHANGE : CHANGE_CONTENT; 
   }
}


sub progress($)
{
   my ($self, $code) = @_;

   $self->SUPER::progress('', $self->{change}->{action} . ' ' . $self->{change}->{boolean}, $code);
}


sub commit()
{
   return unless %CHANGES;

   my @args;
   map { push @args, $_.'='.$CHANGES{$_} } keys %CHANGES;
  
   run('setsebool', '-P', @args);

   $CLEAN=0;
   update_cache();

   foreach my $bool (keys %CHANGES)
   {
      error "Failed to " . ($CHANGES{$bool} ? 'set' : 'clear') . " SELinux boolean '$bool'"
         unless defined $CACHE{$bool} && $CACHE{$bool} eq $CHANGES{$bool};
   }

   undef %CHANGES;
}


# 1: set, 0: cleared or unknown
sub is_set($)
{
   my ($bool) = @_;

   return $CHANGES{$bool} if defined $CHANGES{$bool};

   update_cache();
   return defined $CACHE{$bool} && $CACHE{$bool} == 1
}


# 1: cleared, 0: set or unknown
sub is_cleared($)
{
   my ($bool) = @_;

   return $CHANGES{$bool} if defined $CHANGES{$bool};

   update_cache();
   return defined $CACHE{$bool} && $CACHE{$bool} == 0;
}


# 1: set, 0: cleared or unknown
sub set($)
{
   my ($bool) = @_;

   return 1 if is_set($bool);
   return 0 unless defined $CACHE{$bool};
 
   $CHANGES{$bool} = 1;
   return 1;
}


# 1: cleared, 0: set or unknown
sub clear($)
{
   my ($bool) = @_;

   return 1 if is_cleared($bool);
   return 0 unless defined $CACHE{$bool};
 
   $CHANGES{$bool} = 0;
   return 1;
}


sub update_cache()
{
   return if $CLEAN;

   my ($rv, @list) = run('getsebool', '-a');
   fail "Cannot get list of SELinux booleans" if $rv;

   undef %CACHE;
   foreach (@list)
   {
      next unless /^(\S+)\s+-->\s+(\S+)/;
      $CACHE{$1} = $2 eq 'on' ? 1 : 0;
   } 

   $CLEAN = 1;
}



1;

