package Config5::SELinux;

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

# Config5::SELinux - SELinux Support
#
# $Id: SELinux.pm 139 2011-11-28 10:27:12Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/SELinux.pm $

use strict;
use warnings;

use File::ExtAttr ':all';

use Config5::Util;

# PROTOTYPES
sub canonicalize_context($);
sub copy_context($$);
sub get_context($);
sub is_valid_context($);
sub set_context($$);


# undef: error
sub get_context($)
{
   my ($path) = @_;

   my $attr = File::ExtAttr::getfattr($path, 'selinux', { namespace => 'security' } )
      or return;

   # The attribute returned by getfattr has a \0 attached!
   $attr =~ s/\0//;

   return $attr;
}

# 1: success, 0/undef: error
sub set_context($$)
{
   my ($path, $context) = @_;

   debug "Set SELinux context '$context' on '$path'";

   return setfattr($path, 'selinux', $context, { namespace => 'security' } );
}


# 1: success, 0/undef: error
sub copy_context($$)
{
   my ($from, $to) = @_;

   my $context = get_context($from)
      or return;
   set_context($to, $context);
}


# 1: valid, undef: invalid
sub is_valid_context($)
{
   my ($context) = @_;

   return defined canonicalize_context($context);
}


# undef: invalid
sub canonicalize_context($)
{
   my ($context) = @_;

   return "system_u:object_r:$context:s0"
      if $context =~ /^[^:]+_t$/;
   return "$context:s0"
      if $context =~ /^[^:]+_u\:[^:]+_r\:[^:]+_t$/;
   return $context
      if $context =~ /^[^:]+_u\:[^:]+_r\:[^:]+_t\:s0$/;
   
   return;
}


1;
