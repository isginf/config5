package Config5::Action::Extensions::Augeas;
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

# Config5::Action::Extensions::Augeas - Action
#
# $Id: Augeas.pm 198 2013-03-19 15:14:36Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/Augeas/lib/perl/Config5/Action/Extensions/Augeas.pm $

use strict;
use warnings;

use Config::Augeas;
use Config5::Util qw(error get_root);

# PROTOTYPES
sub apply();
sub check();
sub check_insert($$);
sub check_remove($);
sub check_replace($$);
sub check_set($$);
sub commit();
sub insert($$$);
sub prepare();
sub progress($);
sub remove($);
sub replace($$$);
sub set($$);

my $AUG;


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
   my $path = $self->{change}->{path};

   my $rv;

   if ($action eq 'remove') {
      $rv = remove($path);
   } elsif ($action eq 'set') {
      $rv = $self->set($path, $self->{change}->{value});
   } elsif ($action eq 'replace') {
      $rv = $self->replace($path, $self->{change}->{pattern}, $self->{change}->{value});
   } elsif ($action eq 'insert') {
      $rv = insert($path, $self->{change}->{location}, $self->{change}->{label});
   }

   $self->action_error("Failed to $action path '$path'")
      unless $rv;

   return $rv
}


sub check()
{
   my ($self) = @_;
   
   my $action = $self->{change}->{action};
   my $path = $self->{change}->{path};

   if ($action eq 'remove') {
      return check_remove($path) ? SKIP_NO_CHANGE : CHANGE_CONTENT; 
   } elsif ($action eq 'set') {
      return $self->check_set($path, $self->{change}->{value}) ? SKIP_NO_CHANGE : CHANGE_CONTENT; 
   } elsif ($action eq 'replace') {
      return $self->check_replace($path, $self->{change}->{pattern}) ? SKIP_NO_CHANGE : CHANGE_CONTENT; 
   } elsif ($action eq 'insert') {
      return check_insert($path, $self->{change}->{label}) ? SKIP_NO_CHANGE : CHANGE_CONTENT; 
   }
}


sub progress($)
{
   my ($self, $code) = @_;

   my $action = $self->{change}->{action};
   my $path = $self->{change}->{path};

   my $part2 = "$action ";
   if ($action eq 'remove') {
      $part2 .= $path;
   } elsif ($action eq 'set') {
      $part2 .= "$path: '" . $self->{change}->{value} . "'";
   } elsif ($action eq 'replace') {
      $part2 .= "$path: '" . $self->{change}->{pattern} . "'->'" . $self->{change}->{value} . "'";
   } elsif ($action eq 'insert') {
      $part2 .= $self->{change}->{label} . ' ' . $self->{change}->{location} . " $path";
   }

   $self->SUPER::progress('', $part2, $code);
}


sub prepare()
{
   $AUG = Config::Augeas->new( root => get_root() );
}


sub commit()
{
   error "Augeas failed to commit changes"
      unless $AUG->save();
}


# 1: all set, 0: at least one not set
sub check_set($$)
{
   my ($self, $path, $new) = @_;

   $new = $self->substitute($new);

   my @paths = $AUG->match($path);
   if (! @paths)
   {
      return 1 if $path =~ /[\[\]\*]/;
      push @paths, $path;
   }

   foreach (@paths)
   {
      my $old = $AUG->get($_);
      return 0 if ! defined $old || $old ne $new;
   }

   return 1;
}


sub set($$)
{
   my ($self, $path, $new) = @_;

   my $new2 = $self->substitute($new);

   my @list = $AUG->match($path);
   push @list, $path unless @list;

   map { $AUG->set($_, $new2) } @list;

   return $self->check_set($path, $new);
}


# 1: all set, 0: at least one not set
sub check_replace($$)
{
   my ($self, $path, $pattern) = @_;

   $pattern = $self->substitute($pattern);

   my @paths = $AUG->match($path) or return 0;

   foreach (@paths)
   {
      my $old = $AUG->get($_);
      return 0 if defined $old && $old eq $pattern;
   }

   return 1;
}


sub replace($$$)
{
   my ($self, $path, $pattern, $new) = @_;

   my $pattern2 = $self->substitute($pattern);
   my $new2 = $self->substitute($new);

   foreach my $p ($AUG->match($path))
   {
      my $old = $AUG->get($p);
      $AUG->set($p, $new2)
         if defined $old && $old eq $pattern2;
   }

   return $self->check_replace($path, $pattern);
}

# 1: all removed, 0: paths exists
sub check_remove($)
{
   my ($path) = @_;

   return 0 if $AUG->match($path);

   return 1;
}


sub remove($)
{
   my ($path) = @_;

   map { $AUG->remove($_) } $AUG->match($path);

   return check_remove($path);
}


# 1 all exist, 0: at least one missing
sub check_insert($$)
{
   my ($path, $label) = @_;

   foreach my $p ($AUG->match($path))
   {
      $p =~ s/^(.*)\/[^\/]+$/$1\/$label/;
      return 0 unless $AUG->match($p);
   }

   return 1;
}


sub insert($$$)
{
   my ($path, $where, $label) = @_;

   foreach my $p ($AUG->match($path))
   {
      my $new = $p;
      $new =~ s/^(.*)\/[^\/]+$/$1\/$label/;
      next if $AUG->match($new);

      $AUG->insert($label, $where, $p);
   }

   return check_insert($path, $label);
}


1;

