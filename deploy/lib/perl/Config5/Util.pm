package Config5::Util;

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

# Config5::Util - Utility Functions
#
# $Id: Util.pm 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Config5/Util.pm $

use strict;
use warnings;

use File::Temp 'tempfile';
use Sys::Syslog;
use Fcntl 'SEEK_SET';

require Exporter;

# PROTOTYPES
sub change_root($);
sub debug($);
sub error($);
sub fail($);
sub had_output();
sub has_errors();
sub has_spooled();
sub info($;$);
sub is_change_root();
sub is_dummy();
sub is_verbose(;$);
sub run($;@);
sub runas($$$;@);
sub set_debug($);
sub set_dummy($);
sub set_root($);
sub set_verbose($);
sub slurp($);
sub slurp_raw($);
sub spool($;$);
sub tokenize($;$);
sub unspool();

my $DEBUG;
my $VERBOSE;
my $DUMMY;
my $ERRORS = 0;
my $OUTPUT;
my $SPOOL;

my %QUOTE = ( '"' => 1, "'" => 1, '`' => 1 );
my %SPACE = ( ' ' => 1, "\t" => 1 );

our @EXPORT = qw(info spool unspool has_spooled had_output debug error fail set_debug set_verbose has_errors is_dummy is_verbose run change_root is_change_root);
our @EXPORT_OK = qw(info spool has_spooled unspool had_output debug error fail set_debug set_verbose run runas slurp tokenize has_errors is_verbose is_dummy slurp_raw set_dummy set_verbose set_root get_root);
our @ISA = qw(Exporter);

openlog $::SETTINGS->{os}->{syslog}->{identifier}, 'nofatal', $::SETTINGS->{os}->{syslog}->{facility}
   if $::SETTINGS->{os}->{syslog}->{enable};


sub set_root($)
{
   $::SETTINGS->{os}->{root} = $_[0];
}


sub get_root()
{
   return $::SETTINGS->{os}->{root};
}


sub is_change_root()
{
   return $::SETTINGS->{os}->{root} ne '/';
}


sub change_root($)
{
   my ($path) = @_;

   return $path unless $path =~ /^\//;
   my $root = $::SETTINGS->{os}->{root};
   $root = $1 if $root =~ /^(.*)\/+$/;

   return $root . $path;
}


sub run($;@)
{
   my ($cmd, @args) = @_;
 
   runas(undef, undef, $cmd, @args);
}


sub runas($$$;@)
{
   my ($uid, $gid, $cmd, @args) = @_;

   my $fh = new File::Temp( UNLINK => 1 );
 
   if (my $pid = fork)
   {
      waitpid $pid, 0;
      $fh->flush();
      seek($fh, 0, SEEK_SET);
      my (@output) = (<$fh>);
      chomp @output;
      return wantarray ? ($?>>8, @output) : $?>>8;    
   }
   elsif (defined $pid)
   {
      open STDIN, '<', '/dev/null';
      open STDERR, '>', '/dev/null';
      open STDOUT, '>&', $fh; 

      if (defined $gid)
      {
         $( = $gid;
         $) = "$gid $gid";
      }

      if (defined $uid)
      {
         $< = $uid;
         $> = $uid;
      } 
    
      exec $cmd, @args or exit 127;
   }
   else 
   {
      return 127;
   }
}


sub slurp($)
{
   my @data;
   open my $fh, "<$_[0]" or return @data;
   chomp (@data = (<$fh>));
   @data;
}


sub slurp_raw($)
{
   open my $fh, "<$_[0]" or return;
   do { local $/; <$fh> };
}


sub set_dummy($)
{
   $DUMMY = $_[0];
}


sub set_debug($)
{
   $DEBUG = $_[0];
}


sub set_verbose($)
{
   $VERBOSE = $_[0];
}


sub debug($)
{
   return unless $DEBUG;
   print 'DEBUG: ' . $_[0] . "\n";
   $OUTPUT = 1;
}


sub info($;$)
{
   $_[1] = 1 unless defined $_[1];
   return unless $VERBOSE >= $_[1];
   print($SPOOL), undef $SPOOL if defined $SPOOL;
   print $_[0] . "\n";
   $OUTPUT = 1;
}


sub spool($;$)
{
   $_[1] = 1 unless defined $_[1];
   return unless $VERBOSE >= $_[1];
   $SPOOL .= $_[0] . "\n";
}


sub unspool()
{
   undef $SPOOL;
}


sub has_spooled()
{
   return defined $SPOOL;
}


sub error($)
{
   print '** ' . $_[0] . "\n";
   syslog('err',$_[0]) if $::SETTINGS->{os}->{syslog}->{enable};
   $ERRORS++;
   $OUTPUT = 1;
}


sub fail($)
{
   print '** ' . $_[0] . "\n";
   syslog('crit',$_[0]) if $::SETTINGS->{os}->{syslog}->{enable};
   exit 1;
}


sub has_errors()
{
   return $ERRORS;
}


sub is_dummy()
{
   return $DUMMY;
}


sub is_verbose(;$)
{
   return $VERBOSE >= (defined $_[0] ? $_[0] : 1);
}


sub had_output()
{
   return $OUTPUT;
}


sub tokenize($;$)
{
   my ($line, $count) = @_;
   my ($token, $quote, $escape, @tokens);

   return @tokens unless defined $line;

   my @chars = split //, $line;
   while (@chars)
   {
      $_ = shift @chars;

      # Deal with escaped characters such as \n, \" or \'
      if ($escape)
      {
         $_ = "\n" if $_ eq 'n';
         $token = defined $token ? $token . $_ : $_;
         $escape = 0;
         next;
      }

      # Escape character
      if ($_ eq '\\')
      {
         $escape = 1;
         next;
      }
      
      # Search for end quote
      if ($quote)
      {
         if ($_ eq $quote)
         {
            $quote = 0;
         } 
         else
         {
            $token .= $_;
         }
         next;
      }

      # Skip whitespaces and trailing comments
      if ($SPACE{$_})
      {  
         push(@tokens, $token), $token = undef if defined $token;
         next;
      }
      elsif ($_ eq '#')
      {
         last;
      }

      # Stop after $count tokens, leave remaining line as last token
      if (defined $count && ! defined $token && ! $count--)
      {
        $token = join '', $_, @chars;
        last;
      }

      # Start new token 
      if ($QUOTE{$_})
      {
         $quote = $_;
         $token = '' unless defined $token;
      }
      else
      {
         $token = defined $token ? $token . $_ : $_;
      }
   }
   
   push @tokens, $token if defined $token;
   push @tokens, '' if defined $count && $count != -1 && @tokens;

   @tokens;
}


1;
