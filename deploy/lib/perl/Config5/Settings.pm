package Config5::Settings;

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

# Config5::Settings - Global Program Settings
#
# $Id: Settings.pm 182 2012-08-29 11:36:00Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Settings.pm $

use strict;
use warnings;

use Config5::Util;

# PROTOTYPES
sub load_dir($);
sub report_stages();


sub new
{
   my ($perlclass, $base) = @_;

   my $self = { base => $base };

   my $config = "$base/etc/settings.pl";
   $_ = $self;
   require $config;

   bless $self, $perlclass;

   $self->load_dir("$base/etc/extensions.d");
   $self->load_dir("$base/etc/custom.d");

   return $self;
}


sub load_dir($)
{
   my ($self, $dir) = @_;
   
   opendir my $dh, $dir or return;
   foreach my $file (sort grep { /\.pl$/ } readdir($dh))
   {
      $_ = $self;
      require "$dir/$file";
   }
   closedir $dh;
}


sub report_stages()
{
   my ($self) = @_;

   foreach my $name (sort keys %{$self->{stage}->{stages}})
   {
      my $flag = $self->{stage}->{stages}->{$name};
      $flag .= " (default)" if $name eq $self->{system}->{defaults}->{stage};
      info "$name: -$flag";
   }
}


sub report_changes()
{
   my ($self) = @_;

   foreach my $change (sort keys %{$self->{change}->{keywords}})
   {
      my $real = $self->{change}->{keywords}->{$change};
      info "$change ($real)";
   }
}


1;
