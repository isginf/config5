package Config5::Feature;

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

# Config5::Feature - Feature
#
# $Id: Feature.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Feature.pm $

use strict;
use warnings;

use Config5::Util qw(info error fail debug slurp tokenize);
use Config5::Change;

# PROTOTYPES
sub all_changes($);
sub check_recursion($$);
sub dump();
sub get_best_match($);
sub identify();
sub is_triggered(;$);
sub list_classes();
sub list_files();
sub resolve_class($$$$);
sub trigger($);


sub new
{
   my ($perlclass, $featureset, $dir, $name) = @_;
   
   my $path = "$dir/" . $::SETTINGS->{spec}->{name};
   fail "Feature '$name' does not contain a '$::SETTINGS->{spec}->{name}' file"
      unless -r $path;
  
   my $self = { name => $name, dir => $dir, featureset => $featureset };
   bless $self, $perlclass;

   my $class;
   my ($n,$last);
   foreach $_ (slurp $path)
   {
      $n++;
      $_ = $last . $_, $last = undef if defined $last;
      $last = $1, next if /^(.*)\\$/;

      next if /^\s*$/;
      next if /^\s*#/;

      if (/^(\S+)\s*:\s*(.*)/)
      {
         $class = $1;
         my $sub = $2;

         fail "Duplicate class '$class' in feature '$name'"
            if defined $self->{classes}->{$class};

         @{$self->{classes}->{$class}} = ();
         @{$self->{sub}->{$class}} = ();

         foreach my $token (tokenize $sub)
         {
            if ($token =~ /^([^=]+)=(.+)/) {
               $self->{subst}->{$class}->{$1} = $2;
            } elsif ($token ne '') {
               push @{$self->{sub}->{$class}}, $token;
            }
         }
         next;
      }
     
      if (/^\s+(\S+)\s+(.*)/)
      {
         
         my $change = Config5::Change::factory($self, $class, $1, $2, $n);

         fail "Change '" . $change->{name} . "' in feature '$name' without class'"
            unless defined $class;

         push @{$self->{classes}->{$class}}, $change;
         $self->{changes}->{$change} = $class;
         next;
      }

      fail "Unparsable line $n in 'spec' file for feature '$name': $_"; 
   }

   foreach my $class (sort keys %{$self->{classes}})
   {
      next unless $self->{sub}->{$class};
      
      foreach my $sub (@{$self->{sub}->{$class}})
      {
         error("Reference to undefined class '$sub' in class '$class' in feature '$name'"), next
            unless defined $self->{classes}->{$sub};

         $self->check_recursion($class, {});
      }
   }

   $self;
}


sub dump()
{
   my ($self) = @_;

   foreach my $class (sort keys %{$self->{classes}})
   {
      my $line = "  $class:";
      map { $line .= " $_" } @{$self->{sub}->{$class}};
      info $line;

      foreach my $change (@{$self->{classes}->{$class}}) {
         $change->dump();
      }
   }
}


sub list_files()
{
   my ($self) = @_;

   my @paths;
   foreach my $class (sort keys %{$self->{classes}})
   {
      foreach my $change (@{$self->{classes}->{$class}}) {
         push @paths, $change->{path} if $change->{list_file};
      }
   }

   @paths;
}


sub list_classes()
{
   my ($self) = @_;

   return sort keys %{$self->{classes}};
}


sub all_changes($)
{
   my ($self, $changeset) = @_;

   foreach my $class (sort keys %{$self->{classes}}) {
      map { $changeset->add($_, $class, {}) } @{$self->{classes}->{$class}};
   }
}


sub identify()
{
   my ($self) = @_;

   "feature '" . $self->{name} . "'";
}


sub trigger($)
{
   my ($self, $class) = @_;

   $self->{triggered}->{$class} = 1 if defined $class;
   $self->{triggered}->{''} = 1;
}


sub is_triggered(;$)
{
   my ($self, $class) = @_;
   
   $class = '' unless defined $class;
   return $self->{triggered}->{$class};
}


sub check_recursion($$)
{
   my ($self, $class, $parents) = @_;

   # Detect and prevent loops
   error("Recursive reference to class '$class' in " . $self->identify()), return
     if $parents->{$class};

   my %parents = %{$parents};
   $parents{$class} = 1;

   map { $self->check_recursion($_, \%parents) } @{$self->{sub}->{$class}}
      if $self->{sub}->{$class};
}


sub resolve_class($$$$)
{
   my ($self, $class, $topclass, $changeset, $subst) = @_;

   # Push down substitutions to referenced classes
   my %subst = %{$subst};
   %subst = ( %{$self->{subst}->{$class}}, %subst )
      if $self->{subst}->{$class};

   map { $self->resolve_class($_, $topclass, $changeset, \%subst) } @{$self->{sub}->{$class}}
      if $self->{sub}->{$class};

   map { $changeset->add($_, $topclass, \%subst) } @{$self->{classes}->{$class}}
      if $self->{classes}->{$class};
}


sub get_best_match($)
{
   my ($self, $matches) = @_;

   foreach my $string (@{$matches}) {
      return $string if defined $self->{classes}->{$string};
   }

   return;
}


1;

