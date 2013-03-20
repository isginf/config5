package Config5::Permissions;
use base Config5::Owner;

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

# Config5::Permissions - Permissions
#
# $Id: Permissions.pm 195 2013-03-19 07:18:17Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Permissions.pm $

use strict;
use warnings;

use POSIX qw(lchown);
use Module::Load;

use Config5::Util qw(info error fail debug);

# PROTOTYPES
sub apply($);
sub chcon($);
sub check($);
sub chmod($);
sub chown($);
sub has_context();


sub new
{
   my ($perlclass, $change, $user, $group, $mode, $context) = @_;

   my $self = $perlclass->SUPER::new($change, $user, $group);
   
   load Config5::SELinux if $::SETTINGS->{os}->{selinux}->{enable};

   if (defined $mode && $mode ne '-')
   {
      $self->{modebits} = oct($mode)
         if $mode =~ /^[01234567]+$/;
      error "Invalid mode '$mode' in " . $change->identify()
         unless defined $self->{modebits};
   }

   if (defined $context and $context ne '-' and $::SETTINGS->{os}->{selinux}->{enable})
   {
      $self->{canonicalcontext} = Config5::SELinux::canonicalize_context($context);
      error "Invalid SELinux context '$context' in " . $change->identify()
         unless defined $self->{canonicalcontext};
   }

   $self->{mode} = $mode;
   $self->{context} = $context;

   bless $self, $perlclass;

   $self;
}


sub has_context()
{
   my ($self) = @_;

   return defined $self->{canonicalcontext};
}


sub check($)
{
   my ($self, $path) = @_;

   my (undef, undef, $modebits, undef, $uid, $gid) = lstat $path or return 1;

   my $cgid = $self->get_gid();
   my $cuid = $self->get_uid();

   return 1 if defined $cgid and $cgid != -1 and $gid != $cgid;
   return 1 if defined $cuid and $cuid != -1 and $uid != $cuid;
   return 1 if defined $self->{mode} and $self->{mode} ne '-' and ($modebits & 07777) != $self->{modebits};

   return 0 unless defined $self->{canonicalcontext};

   my $context = Config5::SELinux::get_context($path) or return 1;

   return $context eq $self->{canonicalcontext} ? 0 : 1;
}


# 1: success, 0: error
sub apply($)
{
   my ($self, $path) = @_;

   my $rv = $self->chown($path);
   $rv &= $self->chmod($path);
   return $rv & $self->chcon($path);
}


# 1: success, 0: error
sub chmod($)
{
   my ($self, $path) = @_;
  
   return 1 unless defined $self->{mode};
   return 1 if $self->{mode} eq '-';
 
   error("Unable to chown '$path' to mode " . $self->{mode} . ' in ' . $self->{change}->identify()), return 0
      unless CORE::chmod $self->{modebits}, $path;

   return 1;
}


# 1: success, 0: error
sub chown($)
{
   my ($self, $path) = @_;

   my $uid = $self->get_uid();
   my $gid = $self->get_gid();
 
   error("Unable to chown '$path' to '" . $self->{user} . ':' . $self->{group} . ' in ' . $self->{change}->identify()), return 0
      unless lchown $uid, $gid, $path;
 
   return 1;
}


# 1: success, 0: error
sub chcon($)
{
   my ($self, $path) = @_;

   return 1 unless defined $self->{canonicalcontext};

   error("Unable to chcon '$path' to '" . $self->{canonicalcontext} . ' in ' . $self->{change}->identify()), return 0
      unless Config5::SELinux::set_context($path, $self->{canonicalcontext});

   return 1;
}


1;
