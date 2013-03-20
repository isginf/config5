package Config5::Action;

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

# Config5::Action - Base Class for all Action Classes
#
# $Id: Action.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Action.pm $

use strict;
use warnings;

use File::Temp qw(mktemp);
use File::Basename;
use Module::Load;
use Module::Load::Conditional qw(can_load);
use POSIX qw(lchown);

use Config5::Util qw(info error fail debug slurp_raw is_verbose);

# PROTOTYPES
sub action_error($);
sub check_flag($);
sub commit();
sub factory($$$$);
sub ignore_errors();
sub in_place();
sub is_untriggered();
sub make_temp($);
sub prepare();
sub progress($$$$);
sub rename_temp($$);
sub substitute($;$$);
sub trigger($);
sub write_file($$@);

use constant {
   SKIP_WRONG_STAGE => -3,
   SKIP_NOT_TRIGGERED => -2,
   SKIP_CHROOT_NOT_SUPPORTED => -1,
   SKIP_NO_CHANGE => 0,
   CHANGE_PROPERTIES => 1,
   CHANGE_CONTENT => 2,
   CHANGE_CREATE => 3,
   CHANGE_REMOVE => 4,
   CHANGE_ALWAYS => 9,
   ACTION_OK => 0,
   ACTION_DELAYED => -1,
   ACTION_ERROR => 1,
};

my %STATUS =
(
   SKIP_WRONG_STAGE() => "SKIPPED (not in current stage)",
   SKIP_NOT_TRIGGERED() => "SKIPPED (not triggered)",
   SKIP_CHROOT_NOT_SUPPORTED() => "SKIPPED (chroot not supported)",
   SKIP_NO_CHANGE() => "NO CHANGE",
   CHANGE_PROPERTIES() => "CHANGED PROPERTIES",
   CHANGE_CONTENT() => "CHANGED",
   CHANGE_CREATE() => "MISSING",
   CHANGE_REMOVE() => "EXISTS",
   CHANGE_ALWAYS() => "ALWAYS",
);

our @EXPORT = qw(SKIP_NO_CHANGE CHANGE_PROPERTIES CHANGE_CONTENT CHANGE_CREATE CHANGE_REMOVE CHANGE_ALWAYS SKIP_CHROOT_NOT_SUPPORTED SKIP_NOT_TRIGGERED SKIP_WRONG_STAGE ACTION_OK ACTION_DELAYED ACTION_ERROR);
our @EXPORT_OK = qw(SKIP_NO_CHANGE CHANGE_PROPERTIES CHANGE_CONTENT CHANGE_CREATE CHANGE_REMOVE CHANGE_ALWAYS SKIP_CHROOT_NOT_SUPPORTED SKIP_NOT_TRIGGERED SKIP_WRONG_STAGE ACTION_OK ACTION_DELAYED ACTION_ERROR);
our @ISA = qw(Exporter);


sub factory($$$$)
{
   my ($change, $class, $system, $subst) = @_;

   my $perlclass = $::SETTINGS->{action}->{classes}->{$change->{name}};
   fail "No handling class for keyword in " . $change->identify()
      unless defined $perlclass;

   fail "Cannot load module '$perlclass' for keyword in " . $change->identify()
      unless can_load( modules => { $perlclass => undef } );

   return new $perlclass $change, $class, $system, $subst;
}


sub new
{
   my ($perlclass, $change, $class, $system, $subst) = @_;
   
   my $self = {
      change => $change,
      class => $class,
      subst => $subst,
      system => $system
   };

   %{$self->{status}} = %STATUS;

   bless $self, $perlclass;
}


sub progress($$$$)
{
   my ($self, $part1, $part2, $code) = @_;

   my $name = $self->{change}->{name};

   $part1 = $::SETTINGS->{display}->{changes}->{$name} unless $part1;
   $part1 = $name unless $part1;
   $part2 = ": $part2" if $part2 ne '';

   my $id = '(' . $self->{change}->{feature}->{name} . ':' . $self->{class} . (is_verbose(3) ? '->' . $self->{change}->{class} : '') . ')';
   my $msg = "$part1 $id$part2" . ($code == CHANGE_ALWAYS ? '' : ' - ' . $self->{status}->{$code});

   if ($code <= SKIP_NO_CHANGE) {
      info $msg, 2;
   } else {
      info $msg;
   }
}


sub prepare()
{
}


sub commit()
{
}


sub check_flag($)
{
   my ($self, $flag) = @_;

   $self->{change}->{flags}->{$flag};
}


sub ignore_errors()  { return $_[0]->check_flag('n'); }
sub in_place()  { return $_[0]->check_flag('i'); }


sub action_error($)
{
   my ($self, $error) = @_;

   error $error
      unless $self->ignore_errors();
}


sub trigger($)
{
   my ($self, $code) = @_;
   
   $self->{change}->{feature}->trigger($self->{change}->{class})
      if $code != CHANGE_ALWAYS && $code >= CHANGE_CONTENT;
}


# 1: trigger required but not set, undef: no trigger required or triggered
sub is_untriggered()
{
   my ($self) = @_;

   my $flag;

   if ($self->check_flag('T'))
   {
      return if $self->{change}->{feature}->is_triggered();
      $flag = 1;
   }

   if ($self->check_flag('t'))
   {
      return if $self->{change}->{feature}->is_triggered($self->{change}->{class});
      $flag = 1;
   }

   return $flag;
}


sub substitute($;$$)
{
   my ($self, $data, $change, $subst) = @_;

   return $data if $self->check_flag('b');

   # Builtin substitutions
   $change = $self->{change} unless defined $change;
   my %subst = 
   (
      auto_feature => $self->{change}->{feature}->{name},
      auto_class => $self->{class},
      auto_class_lc => lc $self->{class},
      auto_dynamic_rnd => $self->{system}->{dynamic_rnd},
      auto_static_rnd => $self->{system}->{static_rnd},
      auto_program_version => $::VERSION,
      auto_base => $::BASE,
   );

   # All system items
   foreach my $item (keys %{$::SETTINGS->{system}->{items}})
   {
      next unless defined $self->{system}->{$item};

      if($::SETTINGS->{system}->{items}->{$item}->[2]) {
         map { $subst{'info_' . lc $item . '_' . lc $_} = 1 } @{$self->{system}->{$item}};
      } else {
         $subst{'info_' . lc $item} = $self->{system}->{$item};
      }
   }

   $subst = $self->{subst} unless $subst;
   %subst = ( %subst , %{$subst} ) if $subst;
   %subst = ( %subst , %{$change->{subst}}) if $change->{subst};

   #debug 'Substitutions: ' . join(':', keys %subst) . '->' . join(':', values %subst) . ' in ' . $change->identify;

   my $engine = Template->new( );
   my $output;

   fail 'Problem with template (' . $change->identify . '): ' . $engine->error()
      unless $engine->process(\$data, \%subst, \$output);

   return $output;
}


# 1: success, undef: error
sub rename_temp($$)
{
   my ($self, $tmp, $file) = @_;

   if ($::SETTINGS->{os}->{selinux}->{enable})
   {
      load Config5::SELinux;

      # Try to copy but do not fail 
      Config5::SELinux::copy_context($file, $tmp)
         unless $self->{change}->{permissions} && $self->{change}->{permissions}->has_context();
   }

   unless (rename $tmp, $file)
   {
      error "Unable to rename temporary to '$file'";
      unlink $tmp;
      return;
   }

   return 1; # created
}


sub make_temp($)
{
   my ($self, $file) = @_;

   dirname($file) . '/' . mktemp(".config5.XXXXXXXXXXXXXXXXXXXXXXXXX");
}


sub write_file($$@)
{
   my ($self, $file, @data) = @_;

   my $tmp = $self->make_temp($file);

   my ($mode, $uid, $gid) = (lstat $file)[2,4,5];
   $self->action_error("Unable to get properties of '$file'"), return
      unless defined $mode && defined $uid && defined $gid;
   $mode &= 07777;

   $self->action_error("Unable to open '$tmp' for writing"), return
      unless open(my $fh, '>', $tmp);

   $self->action_error("Unable to chown '$tmp' to $uid:$gid"), unlink($tmp), return 0
      unless lchown($uid, $gid, $tmp);
   $self->action_error("Unable to chmod '$tmp' to " . sprintf('%lo', $mode)), unlink($tmp), return 0
      unless CORE::chmod $mode, $tmp;

   $self->action_error("Unable to write to '$tmp'"), unlink($tmp), return
      unless print $fh @data;
   $self->action_error("Unable to write to '$tmp'"), unlink($tmp), return
      unless close $fh;

   return $self->rename_temp($tmp, $file);
}


1;
