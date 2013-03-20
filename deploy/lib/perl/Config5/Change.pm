package Config5::Change;

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

# Config5::Change - Base Class for all Change Classes
#
# $Id: Change.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Change.pm $

use strict;
use warnings;

use Module::Load::Conditional qw(can_load);

use Config5::Permissions;
use Config5::Util qw(tokenize error fail info);

# PROTOTYPES
sub check($;$);
sub dump();
sub factory($$$$$);
sub identify();
sub parse($$);
sub parse_featurefile($);
sub parse_flags($);
sub parse_owner($);
sub parse_path($);
sub parse_permissions($;$);
sub parse_substitutions($);


sub factory($$$$$)
{
   my ($feature, $class, $keyword, $line, $lineno) = @_;

   my $name = $::SETTINGS->{change}->{keywords}->{$keyword};
   fail "Unknown change keyword '$keyword' in " . $feature->identify()
      unless defined $name;

   my $perlclass = $::SETTINGS->{change}->{classes}->{$name};
   fail "No handling class for keyword '$keyword' in " . $feature->identify()
      unless defined $perlclass;

   fail "Cannot load module '$perlclass' for keyword '$keyword' in " . $feature->identify()
      unless can_load( modules => { $perlclass => undef } );
   
   return new $perlclass $feature, $class, $keyword, $line, $lineno;
}


sub new
{
   my ($perlclass, $feature, $class, $keyword, $line, $lineno) = @_;
   
   my $self = {};
   $self->{feature} = $feature;
   $self->{keyword} = $keyword;
   $self->{name} = $::SETTINGS->{change}->{keywords}->{$keyword};
   $self->{class} = $class;
   $self->{line} = $line;
   $self->{lineno} = $lineno;
   $self->{pass} = 1;
   $self->{flags} = {};
   bless $self, $perlclass;

   $self->{args} = $self->parse_flags($line);

   $self;
}


sub dump()
{
   my ($self) = @_;

   info '    ' . $self->{keyword} . ' ' . $self->{line} . "\n";
}


sub identify()
{
   my ($self) = @_;

   $self->{feature}->identify() . ', change in line number ' . $self->{lineno} . ': ' . $self->{keyword} . ' ' . $self->{line};
}


sub parse_flags($)
{
   my ($self, $args) = @_;

   # Accumulate and remove all flags
   my $flags = '';
   my ($token, $tmp) = tokenize $args, 1;
   while ($token && $token =~ /^-(.*)/)
   {
      $flags .= $1;
      $args = $tmp;
      ($token, $tmp) = tokenize $args, 1;
   }   

   # Extract pass number from flags
   while ($flags =~ /^(\D*)(\d)(.*)/) {
      $flags = $1.$3;
      $self->{pass} = $2;
   }

   # Store in hashes
   my %stages;
   map { $stages{$_} = 1 } values %{$::SETTINGS->{stage}->{stages}};
   map { $stages{$_} ? $self->{stages}->{$_} = 1 : $self->{flags}->{$_} = 1 } split(//, $flags);

   $args;
}


sub parse_path($)
{
   my ($self, $args) = @_;

   my ($file, $rest) = $self->parse($args, 1);
   fail "Path '$file' is not absolute in " . $self->identify()
      unless $file =~ /^\//;

   ($file, $rest);
}


sub parse_featurefile($)
{
   my ($self, $args) = @_;

   my ($file, $rest) = $self->parse($args, 1);
   fail "No file '$file' in " . $self->identify()
      unless $file =~ /^\// || -f $self->{feature}->{dir} . '/' . $file;

   ($file, $rest);
}


sub parse_owner($)
{
   my ($self, $args) = @_;

   my ($user, $group, $rest) = $self->parse($args, 2);

   my $owner = new Config5::Owner( $self, $user, $group); 

   ($owner, $rest);
}


sub parse_permissions($;$)
{
   my ($self, $args, $withmode) = @_;

   my ($user, $group, $rest) = $self->parse($args, 2);

   my $mode;
   ($mode, $rest) = $self->parse($rest, 1)
      if $withmode;

   my ($context, $tmp) = tokenize $rest, 1;
   if (defined $context && ($context !~ /=/ || $context eq '-')) {
      $rest = $tmp;
   } else {
      $context = '-';
   }

   my $perms = new Config5::Permissions($self, $user, $group, $mode, $context); 

   ($perms, $rest);
}


sub parse_substitutions($)
{
   my ($self, $args) = @_;
  
   my %subst;
   foreach my $pair (tokenize $args)
   {
      fail("Invalid substitution '$pair' in " . $self->identify()), next
         unless $pair =~ /^([^=]+)=(.+)/;
      $subst{$1} = $2;
   }

   (\%subst, '');
}


sub check($;$)
{
   my ($self, $args, $flags) = @_;

   # Check for training garbage
   fail "Garbage '$args' in " . $self->identify()
      if tokenize $args;

   # Check for invalid flags
   $flags = 'ntT' unless defined $flags;
   foreach my $flag (keys %{$self->{flags}})
   {
      fail "Invalid flag '$flag' for " . $self->identify()
         unless $flags =~ /$flag/;
   }   

   $self;
}


sub parse($$)
{
   my ($self, $args, $count) = @_;

   my @result = tokenize $args, $count;
   fail "Insufficient arguments in " . $self->identify()
     if @result <= $count;

   return @result;
}


1;
