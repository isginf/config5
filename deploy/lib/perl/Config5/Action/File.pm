package Config5::Action::File;
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

# Config5::Action::File - Action
#
# $Id: File.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Action/File.pm $

use strict;
use warnings;

use Template;
use File::Temp qw(mktemp);
use Digest::MD5 qw(md5_hex);

use Config5::Util qw(slurp_raw debug fail info is_dummy is_verbose change_root);
use Config5::Permissions;

# PROTOTYPES
sub apply($);
sub check();
sub generate($$$);
sub progress($);
sub write($$$);


sub new
{
   my ($perlclass, $change, $class, $system, $subst) = @_;

   my $self = $perlclass->SUPER::new($change, $class, $system, $subst);
   $self->{data} = '';
   bless $self, $perlclass;

   if ($change->{name} eq 'copy')
   {
      $self->generate($change, $class, $subst)
         unless $change->{stages} && ! $change->{stages}->{$::SETTINGS->{stage}->{stages}->{$self->{system}->{stage}}};
   }

   return $self;
}


sub apply($)
{
   my ($self, $code) = @_;

   info "===== Content =====\n" . $self->{data} . "===================", 4 if $self->{textdata};

   my $path = change_root($self->{change}->{path});

   if ($code >= CHANGE_CONTENT)
   {
      unlink($path), rmdir($path) unless -f $path && ! -l $path;

      if ($self->in_place())
      {
         return
            unless $self->write($path, $self->{change}->{permissions}, $self->{data});
      }
      else
      {
         my $tmp = $self->make_temp($path);

         unlink($tmp), return
            unless $self->write($tmp, $self->{change}->{permissions}, $self->{data});

         return $self->rename_temp($tmp, $path); 
      }
   }
   
   return $self->{change}->{permissions}->apply($path);
}


sub check()
{
   my ($self) = @_;

   my $path = change_root($self->{change}->{path});

   return CHANGE_CREATE unless -f $path && ! -l $path;

   my $data = slurp_raw $path;
   return CHANGE_CONTENT unless defined $data;
   return CHANGE_CONTENT unless md5_hex($self->{data}) eq md5_hex($data);
   return CHANGE_PROPERTIES if $self->{change}->{permissions}->check($path);

   return SKIP_NO_CHANGE;
}


sub generate($$$)
{
   my ($self, $change, $class, $subst) = @_;

   my $input = change_root($change->{input});
   my $path = change_root($change->{path});

   my $file = $input; 
   $file = $change->{feature}->{dir} . '/' . $file
      unless $file =~ /^\//;

   $self->SUPER::progress($path . ': ' . $::SETTINGS->{display}->{changes}->{$change->{name}}, $input, CHANGE_ALWAYS)
      if is_verbose(3);

   my $data = slurp_raw $file;
   fail "Unable to append data in '$input' to '$path'"
      unless defined $data or is_dummy();

   $self->{data} .= $self->substitute($data, $change, $subst);
   $self->{textdata} = 1;
}


sub progress($)
{
   my ($self, $code) = @_;

   $self->SUPER::progress($self->{change}->{path} . ': ' . $::SETTINGS->{display}->{changes}->{$self->{change}->{name}}, '', $code);
}


# 1: success, undef: error
sub write($$$)
{
   my ($self, $file, $permissions, $data) = @_;

   $self->action_error("Unable to open '$file' for writing"), return
      unless open (my $fh, '>', $file);

   $permissions->apply($file);

   $self->action_error("Unable to write to '$file'"), return
      unless print $fh $data;
   $self->action_error("Unable to write to '$file'"), return
      unless close $fh;

   return 1;
}


1;
