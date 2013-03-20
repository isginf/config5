package Config5::FeatureSet;

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

# Config5::FeatureSet - Feature Set
#
# $Id: FeatureSet.pm 198 2013-03-19 15:14:36Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/FeatureSet.pm $

use strict;
use warnings;

use Config5::Util;
use Config5::Feature;
use Config5::ChangeSet;

# PROTOTYPES
sub apply($);
sub check($);
sub dump();
sub get_changeset($);
sub get_matches($);
sub report_classes();
sub report_files();
sub report_matches($);


sub new
{
   my ($perlclass, $dir, @list) = @_;

   my $self = { dir => $dir };
   bless $self, $perlclass;

   unless (@list)
   {
      opendir my $dh, $dir or fail "Cannot read feature list in '$dir'";
      map { push @list, $_ unless /^\./ } sort readdir $dh;
      closedir $dh;
   }

   foreach my $name (@list) {
      next unless -d "$dir/$name";
      $self->{features}->{$name} = new Config5::Feature($self, "$dir/$name", $name);
   }
  
   # Check config only with current system info but with all changes
   my $changeset = new Config5::ChangeSet(undef);
   map { $self->{features}->{$_}->all_changes($changeset) } sort keys %{$self->{features}};

   $changeset->check();

   $self;
}


sub check($)
{
   my ($self, $system) = @_;

   my $set = $system->get_variations()
      or return;

   map { $self->get_changeset($_) } @{$set};
}


sub dump()
{
   my ($self) = @_;

   foreach my $name (sort keys %{$self->{features}})
   {
      info "$name:";
      $self->{features}->{$name}->dump();
   }
}


sub report_matches($)
{
   my ($self, $system) = @_;

   my $matches = $self->get_matches($system);

   foreach my $name (sort keys %{$self->{features}})
   {
      my $class = $self->{features}->{$name}->get_best_match($matches);
      info "$name: " . (defined $class ? $class : "(no match)");
   }
}


sub report_files()
{
   my ($self) = @_;

   my %paths;
   foreach my $name (sort keys %{$self->{features}})
   {
      map { $paths{$_} = 1 } $self->{features}->{$name}->list_files();
   }

   map { info $_ } sort keys %paths;
}


sub report_classes()
{
   my ($self) = @_;

   my %names;
   foreach my $name (sort keys %{$self->{features}})
   {
      map { $names{$_} = 1 } $self->{features}->{$name}->list_classes();
   }

   map { info $_ } sort keys %names;
}


sub get_changeset($)
{
   my ($self, $system) = @_;

   my $changeset = new Config5::ChangeSet($system);
   my $matches = $self->get_matches($system);

   foreach my $name (sort keys %{$self->{features}})
   {
      my $feature = $self->{features}->{$name};
      my $class = $feature->get_best_match($matches) or next;
      $feature->resolve_class($class, $class, $changeset, {});
   }

   $changeset->check();

   return $changeset;
}


sub apply($)
{
   my ($self, $system) = @_;

   $self->get_changeset($system)->apply();
}


sub get_matches($)
{
   my ($self, $system) = @_;

   my $matches = [];
   my $classes = {};

   foreach my $name (sort keys %{$self->{features}}) {
      map { $classes->{$_} = 1 } $self->{features}->{$name}->list_classes();
   }

   return $system->get_matches($classes);
}


1;
