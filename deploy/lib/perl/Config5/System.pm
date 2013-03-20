package Config5::System;

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

# Config5::System - Base Class for all System Info Classes
#
# $Id: System.pm 198 2013-03-19 15:14:36Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/System.pm $

use strict;
use warnings;

use Sys::Hostname;
use POSIX qw(uname);
use Socket;
use Module::Load;
use Module::Load::Conditional qw(can_load);

use Config5::Util qw(fail info run slurp change_root is_change_root get_root);

# PROTOTYPES
sub append($$);
sub build_match($$;$);
sub check();
sub convert($$);
sub dump($);
sub get_ip($);
sub get_ip6($);
sub get_matches(;$);
sub get_variations();
sub is_in_list($$);
sub report_classorder();
sub report_items();
sub set($$);


sub new
{
   my ($perlclass, $nolocal) = @_;

   my $items = $::SETTINGS->{system}->{items};

   my $self = {
      root => get_root(),
      dynamic_rnd => (unpack("%32C*", localtime) * 1103515245) & 0xffffffff,
      date => scalar localtime,
      stage => $::SETTINGS->{system}->{defaults}->{stage}
   };
   
   bless $self, $perlclass;

   return $self if $nolocal;

   # Properties
   $self->set('properties', join ' ', slurp(change_root($::SETTINGS->{system}->{properties}->{file})))
      if $items->{properties};

   # These items can only be determined if not chrooted
   unless (is_change_root())
   {
      # Architecture (machine type)
      $self->set('arch', (uname)[4]) if $items->{arch};

      # Hostname
      my $name = hostname;
      $name = $1 if $name =~ /^([^\.]+)\./;
      $self->set('host', $name);

      # IP, IP6, FQHN and FQDN
      my ($fqhn, $fqhn6);
      $fqhn = $self->get_ip($name) if $items->{ip};
      $fqhn6 = $self->get_ip6($name) if $items->{ip6};

      $fqhn = $fqhn6 unless defined $fqhn; # Use IP4 host name if possible

      if (defined $fqhn)
      { 
         $self->set('fqhn', $fqhn) if $items->{fqhn};
         $self->set('fqdn', $1) if $items->{fqdn} && $fqhn =~ /^[^\.]+\.?(.*)/;
      }
   }

   $self;
}


sub set($$)
{
   my ($self, $item, $value) = @_;
   
   return unless $::SETTINGS->{system}->{items}->{$item};
   
   delete $self->{$item};
   return if ! defined $value || $value eq '';

   if ($::SETTINGS->{system}->{items}->{$item}->[2]) {
      map { push @{$self->{$item}}, convert($item, $_) if $_ ne '' } split /[,: ]/, $value;
   } else {
      $self->{$item} = convert($item, $value);
   }
}


sub append($$)
{
   my ($self, $item, $value) = @_;
  
   return unless $::SETTINGS->{system}->{items}->{$item} && $::SETTINGS->{system}->{items}->{$item}->[2];

   $value = convert($item, $value);
   push @{$self->{$item}}, $value
      unless grep { $value eq $_ } @{$self->{$item}};
}


sub is_in_list($$)
{
   my ($self, $item, $value) = @_;

   return unless $::SETTINGS->{system}->{items}->{$item} && $::SETTINGS->{system}->{items}->{$item}->[2];

   $value = convert($item, $value);
   return grep { $value eq $_ } @{$self->{$item}};
}


sub check()
{
   my ($self) = @_;

   my $items = $::SETTINGS->{system}->{items};

   foreach my $item (keys %$items)
   {
      fail "Mandatory system information item '$item' could not be determined"
         if $items->{$item}->[1] && ! defined $self->{$item};
   }

   fail "Undefined stage '$self->{stage}'"
      unless defined $::SETTINGS->{stage}->{stages}->{$self->{stage}};

   # Complete built-in items
   $self->{static_rnd} = (unpack("%32C*", $self->{host}) * 1103515245) & 0xffffffff;
}


sub dump($)
{
   my ($self, $raw) = @_;

   my $items = $::SETTINGS->{system}->{items};

   foreach my $item (sort { $items->{$a}->[0] <=> $items->{$b}->[0] } keys %$items)
   {
      next unless defined $self->{$item};

      my $line;
      
      if ($raw)
      {
         $line = "$item=";
      }
      else
      {
         $line = $items->{$item}->[4] . ':';
         do { $line .= ' ' } while length $line < 20;
      }

      $line .= $items->{$item}->[2] ? join(' ', @{$self->{$item}}) : $self->{$item};
      info $line;
   }
}


sub report_items()
{
   my ($self) = @_;

   my $items = $::SETTINGS->{system}->{items};

   foreach my $item (sort { $items->{$a}->[0] <=> $items->{$b}->[0] } keys %$items)
   {
      my $line = $items->{$item}->[4] . ':';
      do { $line .= ' ' } while length $line < 20;

      $line .= $item;

      my @meta;
      push @meta, 'mandatory' if $items->{$item}->[1];
      push @meta, 'list' if $items->{$item}->[2];
      push @meta, $items->{$item}->[3] if $items->{$item}->[3];
      $line .= ' (' . join(', ', @meta) . ')' if @meta;
      
      info $line;
   }
}


sub report_classorder()
{
   my ($self) = @_;

   my $matches = $self->get_matches();

   map { info $_ } @$matches;
}


sub get_ip($)
{
   my ($self, $name) = @_;

   my ($fqhn, $addr) = (gethostbyname $name)[0,4];
   return unless defined $addr;

   $self->set('ip', inet_ntoa($addr));

   return $fqhn;
}


sub get_ip6($)
{
   my ($self, $name) = @_;

   return unless can_load( modules => { 'Socket6' => undef } );
   load 'Socket6', ':all';

   my ($fqhn, $addr) = (gethostbyname2($name, AF_INET6))[0,4];
   return unless defined $addr;
   return if $addr eq '::1';

   $self->set('ip6', inet_ntop(AF_INET6, $addr));

   return $fqhn;
}


sub convert($$)
{
   my ($item, $value) = @_;

   return unless defined $value;

   my $method = $::SETTINGS->{system}->{items}->{$item}->[3];

   return uc $value if $method eq 'toupper';
   return lc $value if $method eq 'tolower';
   $value =~ s/\s+//g if $method eq 'nows';
   $value =~ s/\s+/_/g if $method eq 'wstounderscore';

   return $value;
}


sub get_variations()
{
   my $dir = $::SETTINGS->{system}->{variations_directory}
      or return;

   my @set;

   opendir my $dh, $dir or fail "Cannot read directory '$dir'";
   foreach my $file (sort readdir $dh)
   {
      next if $file =~ /^\./;
      my $system = new Config5::System(1);
      map { $system->set($1, $2)  if /^([^=]+)=(.+)/ } slurp "$dir/$file";
      push @set, $system;
   }
   closedir $dh;
   
   return \@set;
}


sub get_matches(;$)
{
   my ($self, $classes) = @_;

   my $matches = [];

   map { $self->build_match($_, $matches, $classes) } @{$::SETTINGS->{class}->{match}};

   return $matches;
}


sub build_match($$;$)
{
   my ($self, $string, $matches, $classes) = @_;

   while ($string =~ /\{([a-z]+)\}/)
   {
      my ($pre, $item, $post) = ($`, $1, $');

      fail "Undefined system information item '$item'"
         unless defined $::SETTINGS->{system}->{items}->{$item};
      my $value = $self->{$item} or return;

      if ($::SETTINGS->{system}->{items}->{$item}->[2])
      {
         map { $self->build_match($pre . $_ . $post, $matches, $classes) } @$value;
         return;
      }

      $string = $pre . $value . $post;
   }

   push @$matches, $string
      if (! $classes) || $classes->{$string};
}

1;
