package Config5::ChangeSet;

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

# Config5::ChangeSet - Set of Relevant Changes Compiled from Feature Set
#
# $Id: ChangeSet.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/ChangeSet.pm $

use strict;
use warnings;

use Config5::Util;
use Config5::Action;

# PROTOTYPES
sub add($$;$);
sub apply();
sub apply_pass($);
sub check();


sub new
{
   my ($perlclass, $system) = @_;

   my $self = { system => $system };
   bless $self, $perlclass;
}


sub add($$;$)
{
   my ($self, $change, $class, $subst) = @_;

   my @triplet = ($change, $class, $subst);
   push @{$self->{changes}}, \@triplet;
}


sub check()
{
   my ($self) = @_;

   foreach my $pass (0..9)
   {
      my $phases = $::SETTINGS->{process}->{phases};

      foreach my $phase (sort { $phases->{$a}->[0] <=> $phases->{$b}->[0] } keys %$phases)
      {
         my (@actions, @generators, %actions);

         foreach (@{$self->{changes}})
         {
            my ($change) = @$_;
            next unless $change->{pass} == $pass;
            next unless $::SETTINGS->{change}->{phases}->{$change->{name}} eq $phase;
            $change->{is_generator} ? push (@generators, $change) : push (@actions, $change);
         }
 
         my $key = $phases->{$phase}->[2];

         if (defined $key)
         {
            foreach my $change (@actions)
            {
               my $value = $change->{$key};
               fail "Conflict for '$value' between " . $change->identify() . " and " . $actions{$value}->identify()
                  if $actions{$value} && $actions{$value}->{feature} != $change->{feature};

               $actions{$value} = $change;
            }
      
            foreach my $change (@generators)
            {
               # Generators can only be used with a key to identify the object to generate something for
               my $value = $change->{$key};
               fail "'$value' needs to be created for " . $change->identify()
                  unless $actions{$value};
               fail "'$value' is of wrong type for " . $change->identify()
                  unless $actions{$value}->{can_generate};
            }
         }
      }
   }
}


sub apply()
{
   my ($self) = @_;

   my $verbose = is_verbose $::SETTINGS->{display}->{entities}->{pass};
   my $flag = had_output; 

   foreach my $pass (0..9) {
      spool "" if $flag && ! $verbose;
      spool "" if $verbose && had_output;
      spool "Pass " . $pass . ":" if $verbose;
      $self->apply_pass($pass);
      $flag = 0 unless has_spooled;
      unspool;
   }
}


sub apply_pass($)
{
   my ($self, $pass) = @_;
   my @changes; 

   map { push @changes, $_ if $_->[0]->{pass} == $pass } @{$self->{changes}};
   return unless @changes;

   my $phases = $::SETTINGS->{process}->{phases};
   my $stage = $::SETTINGS->{stage}->{stages}->{$self->{system}->{stage}};

   foreach my $phase (sort { $phases->{$a}->[0] <=> $phases->{$b}->[0] } keys %$phases)
   {
      my (@actions, @generators, %actions);
      foreach (@changes)
      {
         my ($change, $class, $subst) = @$_;
         next unless $::SETTINGS->{change}->{phases}->{$change->{name}} eq $phase;
         push (@generators, $_), next if $change->{is_generator}; 
         push @actions, Config5::Action::factory($change, $class, $self->{system}, $subst);
      }

      my $order = $phases->{$phase}->[1];
      my $key = $phases->{$phase}->[2];

      if (defined $key)
      {
         foreach my $action (@actions) {
            $actions{$action->{change}->{$key}} = $action;
         }
        
         foreach (@generators)
         {
            my ($change, $class, $subst) = @$_;
            my $value = $change->{$key};

            next if $change->{stages} && ! $change->{stages}->{$stage};

            $actions{$value}->generate($change, $class, $subst);
         }
      }

      if ($order eq 'sorted') {
         undef @actions;
         map { push @actions, $actions{$_} } sort keys %actions;
      }

      if ($order eq 'reversed') {  
         undef @actions;
         map { push @actions, $actions{$_} } reverse sort keys %actions;
      }

      # Find all classes of changes in this phase
      my %classes;
      map { $classes{$::SETTINGS->{action}->{classes}->{$_->{change}->{name}}} = 1 } @actions;

      # Run all prepare() functions
      map { eval $_ . "::prepare();" } keys %classes;

      foreach my $action (@actions)
      {
         $action->progress(SKIP_WRONG_STAGE), next
            if defined $action->{change}->{stages} && ! $action->{change}->{stages}->{$stage};
         $action->progress(SKIP_NOT_TRIGGERED), next
            if $action->is_untriggered();

         my $code = $action->check();
         $action->progress($code);
         next if $code <= SKIP_NO_CHANGE;

         $action->trigger($code), next
            if is_dummy();

         my $status = $action->apply($code);
         if ($status)
         {
            if ($status == 1)
            {
               my $code2 = $action->check();
               $action->action_error("Failed to correctly apply change"), next
                  unless $code2 <= SKIP_NO_CHANGE || $code2 eq CHANGE_ALWAYS;
            }

            $action->trigger($code);
         }
      }

      # Run all commit() functions
      map { eval $_ . "::commit();" } keys %classes;
   }
}


1;
