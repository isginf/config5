package Config5::Action::Extensions::Edit;
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

# Config5::Action::Extensions::Edit - Action
#
# $Id: GConf.pm 647 2011-08-04 08:42:35Z walteste $
# $HeadURL: file:///import/svn/repositories/config5-rhel6/svn/trunk/lib/perl/Config5/Action/Extensions/GConf.pm $

use strict;
use warnings;

use Config5::Util qw(slurp change_root);
use Config5::Permissions;

# PROTOTYPES
sub add($$$);
sub apply();
sub check();
sub check_add($$$);
sub check_re($$);
sub commit();
sub load($);
sub modify($$$);
sub progress($);
sub remove($$);
sub replace($$$);
sub write($$);

my %CHANGES;
my %DATA;


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
   my $path = change_root($self->{change}->{path}); 
      
   my $rv;
   if ($action eq 'add') {
      $rv = $self->add($path, $self->{change}->{line}, $self->{change}->{re});
   } elsif ($action eq 'remove') {
      $rv = $self->remove($path, $self->{change}->{re});
   } elsif ($action eq 'replace') {
      $rv = $self->replace($path, $self->{change}->{re}, $self->{change}->{line});
   } elsif ($action eq 'modify') {
      $rv = $self->modify($path, $self->{change}->{re}, $self->{change}->{line});
   }

   $self->action_error("Failed to $action line in '$path'"), return 0
      unless $rv;

   return ACTION_DELAYED;
}


sub check()
{
   my ($self) = @_;
   
   my $action = $self->{change}->{action};
   my $path = change_root($self->{change}->{path}); 

   if ($action eq 'add') {
      return $self->check_add($path, $self->{change}->{line}, $self->{change}->{re}) ? SKIP_NO_CHANGE : CHANGE_CONTENT; 
   } else { # 'remove', 'replace' and 'modify'
      return $self->check_re($path, $self->{change}->{re}) ? SKIP_NO_CHANGE : CHANGE_CONTENT; 
   }
}


sub progress($)
{
   my ($self, $code) = @_;

   my $action = $self->{change}->{action};
   my $path = $self->{change}->{path};

   my $part2 = "$path: $action ";
   if ($action eq 'add') {
      $part2 .= "line '" . $self->{change}->{line} . "'";
   } elsif ($action eq 'remove') {
      $part2 .= "lines matching '" . $self->{change}->{re} . "'";
   } else { # 'replace' and 'modify'
      $part2 .= "lines matching '" . $self->{change}->{re} . "' with '" . $self->{change}->{line} . "'";
   }

   $self->SUPER::progress('', $part2, $code);
}


sub commit()
{
   foreach my $path (keys %CHANGES)
   {
      my $action = $CHANGES{$path};

      map { $_ .= "\n" } @{$DATA{$path}};

      $action->write_file($path, @{$DATA{$path}});
   }

   undef %CHANGES;
   undef %DATA;
}


# 1: line present/re matches, 0: line not present/re does not match, undef: cannot check
sub check_add($$$)
{
   my ($self, $path, $line, $re) = @_;

   return unless load($path);

   if (defined $re) {
      $re = $self->substitute($re);
      return grep(/$re/, @{$DATA{$path}}) ? 1 : 0;
   } else {
      $line = $self->substitute($line);
      return grep(/^\Q$line\E$/, @{$DATA{$path}}) ? 1 : 0 ;
   }
}


sub add($$$)
{
   my ($self, $path, $line, $re) = @_;

   if (load($path))
   {
      push @{$DATA{$path}} , $self->substitute($line);
      $CHANGES{$path} = $self unless $CHANGES{$path};
   }

   return $self->check_add($path, $line, $re);
}


# 1: re does not match, 0: re matches, undef: cannot check
sub check_re($$)
{
   my ($self, $path, $re) = @_;

   $re = $self->substitute($re);

   return unless load($path);
   return grep(/$re/, @{$DATA{$path}}) ? 0 : 1 
}


sub remove($$)
{
   my ($self, $path, $re) = @_;

   my $re2 = $self->substitute($re);

   if (load($path))
   {
      my @new;
      map { push @new, $_ unless /$re2/ } @{$DATA{$path}};
      $DATA{$path} = \@new;
      $CHANGES{$path} = $self unless $CHANGES{$path};
   }

   return $self->check_re($path, $re);
}


sub replace($$$)
{
   my ($self, $path, $re, $line) = @_;

   my $re2 = $self->substitute($re);
   my $line2 = $self->substitute($line);

   if (load($path))
   {
      map { $_ = $line2 if /$re2/ } @{$DATA{$path}};
      $CHANGES{$path} = $self unless $CHANGES{$path};
   }

   return $self->check_re($path, $re);
}


sub modify($$$)
{
   my ($self, $path, $re, $line) = @_;

   my $re2 = $self->substitute($re);
   my $line2 = $self->substitute($line);

   if (load($path))
   {
      map { eval "\$_ =~ s/$re2/$line2/g;" } @{$DATA{$path}};
      $CHANGES{$path} = $self unless $CHANGES{$path};
   }

   return $self->check_re($path, $re);
}


sub load($)
{
   my ($path) = @_;

   return 1 if defined $DATA{$path};
   return unless -r $path;

   @{$DATA{$path}} = slurp($path);

   1;
}


1;

