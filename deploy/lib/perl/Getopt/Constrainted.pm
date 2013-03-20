package Getopt::Constrainted;

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

# Getopt::Constrainted - Getopt::Long with Constraints
#
# $Id: Constrainted.pm 195 2013-03-19 07:18:17Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/Getopt/Constrainted.pm $

use strict;
use warnings;

use Pod::Usage;
use Getopt::Long qw();
use Encode qw(from_to);

require Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(GetOptions);

# PROTOTYPES
sub GetOptions(\%\%);
sub apply_defaults(\%);
sub check(\%;$);
sub check_arguments(\%);
sub check_bool();
sub check_dir();
sub check_file();
sub check_int();
sub check_mandatory_options(\%;$);
sub check_mutex_constraints(\%);
sub check_stray_options(\%;%);
sub check_syntax(\%);
sub check_value_dependencies(\%);
sub convert_argv();
sub derive_names(\%);
sub error($);
sub fail($);
sub gen_name_list(\@;$);
sub is_given($);


our $C;

our $CHECKS =
{
  'directory' => [ \&check_dir, 'an existing directory' ],
  'file' => [ \&check_file, 'an existing file' ],
  'integer' => [ \&check_int, 'a positive integer' ],
  'boolean' => [ \&check_bool, 'a boolean: true, false, 1, 0, on, off, yes, no' ],
};


# ########################################################################## #

#
# Constrainted replacement for Getopt::Long::GetOptions
#
# This is both an exception to the usual naming convention of using C style
# function names as well as that functions are not exported and must be
# accessed using the fully qualified name.
#

sub GetOptions(\%\%)
{
  my $options;
  ($options,$C) = @_;
  
  # Character conversion
  convert_argv();

  # Derive the main option names from the GetOptions specification
  derive_names(%$options);

  # Redirect warn() to our error routines for consistentcy
  my $sig = $SIG{__WARN__};
  $SIG{__WARN__} = sub { my $msg = $_[0]; chomp $msg; error($msg); };

  Getopt::Long::Configure('gnu_getopt');
  Getopt::Long::GetOptions(%$options) || exit 1;
  
  $SIG{__WARN__} = $sig;

  # Check the constraints
  check(%$C);

  # Default options 'help' and 'man'
  ${$C->{names}->{help}} and pod2usage(-exitstatus=>0, -verbose=>0);
  ${$C->{names}->{man}} and pod2usage(-exitstatus=>0, -verbose=>2);
}


# ########################################################################## #

sub check(\%;$)
{
  my ($c,$option) = @_;
  
  apply_defaults(%$c);

  check_mutex_constraints(%$c); 
  check_mandatory_options(%$c,$option);
  check_value_dependencies(%$c);
  check_syntax(%$c);
  check_arguments(%$c);

  if (defined $c->{depend})
  {
    foreach my $opt (keys(%{$c->{depend}})) {
      check(%{$c->{depend}->{$opt}},$opt) if is_given($opt);
    }
  }

  check_stray_options(%$c) if ($c == $C);
}


sub convert_argv()
{
  return unless exists $ENV{'LC_ALL'};
  
  # Figure out the encoding or fall back to ISO-8859-1
  my $enc = "ISO-8859-1";
  $enc = $1 if $ENV{'LC_ALL'} =~ /\w+[-_]\w+\.(.+)/;

  # If the encoding is already UTF-8, we can bail out here.
  return if lc $enc eq "utf-8" || lc $enc eq "utf8";
  
  map { from_to($_,$enc,"utf8") } @ARGV;
}


# ########################################################################## #

#
# Specific checks
#

sub apply_defaults(\%)
{
  my ($c) = @_;

  return unless defined $c->{defaults};

  foreach my $list (@{$c->{defaults}})
  {
    if (ref $list eq "ARRAY")
    {
      my @opts = @$list;
      my $default = shift @opts;
      my $value = shift @opts;
 
      my $flag;
      map { $flag = 1 if is_given($_) } ($default,@opts);
      next if $flag;

      # KLUDGE: Default option must be a scalar
      ${$C->{names}->{$default}} = $value;
    }
  }
}


sub check_mutex_constraints(\%)
{
  my ($c) = @_;

  return unless defined $c->{mutex};
  
  foreach my $set (@{$c->{mutex}})
  {
    my $count = 0;
    map { $count++ if is_given($_) } @$set;
    next if ($count <= 1);

    my $names = gen_name_list(@$set); 
    fail "Options $names are mutually exclusive";
  } 
}


sub check_mandatory_options(\%;$)
{
  my ($c,$option) = @_;

  return unless defined $c->{mandatory};

  foreach my $opt (@{$c->{mandatory}})
  {
    if (ref $opt eq "ARRAY")
    {
      my $flag;
      map { $flag = 1 if is_given($_) } @$opt;
      next if $flag;

      my $names = gen_name_list(@$opt,'or'); 
      fail "One of the options $names is mandatory" . ($option ? " for option $option" : '');
    }
    else 
    {
      next if is_given($opt);
      fail "Option $opt is mandatory" . ($option ? " for option $option" : '');
    }
  }
}


sub check_stray_options(\%;%)
{
  my ($c,%stray) = @_;

  # All options are considered stray at the start
  map { $stray{$_} = 1 if is_given($_) } keys(%{$C->{names}})
    if $c == $C;
  
  # Drop the unconstrainted options
  map { delete $stray{$_} } @{$c->{unconstrainted}}
    if $c->{unconstrainted};
  
  # Drop all mandatory, value-dependent and optional options
  if (exists $c->{mandatory})
  {
    foreach my $opt (@{$c->{mandatory}})
    {
      if (ref $opt) { map { delete $stray{$_} } @$opt }
      else          { delete $stray{$opt} }
    }
  }

  if (defined $c->{optional}) {
    map { delete $stray{$_} } @{$c->{optional}};
  }

  if (defined $c->{onvalue})
  {
    foreach my $set (@{$c->{onvalue}})
    {
      my ($opt,$val,$ref) = @$set;
      next unless ${$C->{names}->{$opt}} eq $val;

      %stray = check_stray_options(%$ref,%stray);
    }
  }
 
  # Drop all options of dependencies
  if (defined $c->{depend})
  {
    foreach my $opt (keys(%{$c->{depend}})) {
      next unless is_given($opt);

      delete $stray{$opt};
      %stray = check_stray_options(%{$c->{depend}->{$opt}},%stray)
        if is_given($opt);
    }
  }

  return %stray unless ($c == $C);

  # What remains generates errors
  foreach my $opt (keys(%stray)) {
    fail "Invalid or stray option $opt";
  }
}


sub check_value_dependencies(\%)
{
  my ($c) = @_;

  return unless defined $c->{onvalue};

  foreach my $set (@{$c->{onvalue}})
  {
    my ($opt,$val,$ref) = @$set;
    next unless ${$C->{names}->{$opt}} eq $val;
    
    check(%$ref,"$opt=$val");
  }
}


sub check_arguments(\%)
{
  my ($c) = @_;

  return unless defined $c->{args};

  if ($c->{args}{syntax})
  {
    my $check = $c->{args}{syntax};

    if (ref $check eq "CODE") {
      map { &$check() or fail "Invalid argument '$_'" } @ARGV;
    };

    if (ref $check eq "ARRAY")
    {
      my $list = gen_name_list(@$check,'or');
      
      foreach my $val (@ARGV) {
        grep {$_ eq $val} @$check 
         or fail "Invalid argument '$val' (must be $list)";
      }
    };

    unless (ref $check)
    {
      my $desc = $CHECKS->{$check}
        or fail "No built-in check '$check'";
      my ($func,$syntax) = @$desc[0,1];

      foreach $_ (@ARGV) {
        &$func() or fail "Invalid argument '$_' (must be $syntax)";
      }
    }
  }

  if ($c->{args}{count})
  {
    my ($min,$max,@options) = @{$c->{args}{count}};

    unless (@options)
    { 
      fail "No arguments allowed"
        if (defined $min && $min == 0 && defined $max && $max == 0 && @ARGV != 0);
      fail "Number of arguments supplied incorrect ($min required)"
        if (defined $min && defined $max && $max == $min && @ARGV != $min);
      fail "Insufficient number of arguments (at least $min)"
        if (defined $min && @ARGV < $min);
      fail "Too many arguments (at most $max)"
        if (defined $max && @ARGV > $max);
    }

    foreach my $opt (@options)
    {
      next unless is_given($opt);

      fail "No arguments allowed with option $opt"
        if (defined $min && $min == 0 && defined $max && $max == 0 && @ARGV != 0);
      fail "Number of arguments supplied with option $opt incorrect ($min required)"
        if (defined $min && defined $max && $max == $min && @ARGV != $min);
      fail "Insufficient number of arguments with option $opt (at least $min)"
        if (defined $min && @ARGV < $min);
      fail "Too many arguments with option $opt (at most $max)"
        if (defined $max && @ARGV > $max);
    }
  }
}


sub check_syntax(\%)
{
  my ($c) = @_;

  return unless defined $c->{syntax};

  foreach my $opt (keys(%{$c->{syntax}}))
  {
    next unless is_given($opt);

    my $check = $c->{syntax}->{$opt};
    my $ref = $c->{names}->{$opt};
    my @vals;

    push @vals, $$ref if ref($ref) eq "SCALAR";
    push @vals, keys(%$ref) if ref($ref) eq "HASH";
    push @vals, @$ref if ref($ref) eq "ARRAY";

    if (ref $check eq "CODE")
    {
      foreach $_ (@vals) {
        &$check() or fail "Invalid value '$_' for option $opt";
      }
    };

    if (ref $check eq "ARRAY")
    {
      my $list = gen_name_list(@$check,'or');
      
      foreach my $val (@vals) {
        grep {$_ eq $val} @$check 
         or fail "Invalid value '$val' for option $opt (must be $list)";
      }
    };

    if (ref $check eq "HASH")
    {
      my @valid = keys %$check;
      my $list = gen_name_list(@valid,'or');
      
      foreach my $val (@vals) {
        grep {$_ eq $val} @valid
         or fail "Invalid value '$val' for option $opt (must be $list)";
      }
    };

    unless (ref $check)
    {
      my $desc = $CHECKS->{$check} or fail "No built-in check '$check'";
      my ($func,$syntax) = @$desc[0,1];

      foreach $_ (@vals) {
        &$func() or fail "Invalid value '$_' for option $opt (must be $syntax)";
      }
    }
  }
}


#
# Built-in checks
#

sub check_int()
{
  /^\d+$/;
}


sub check_dir()
{
  -d $_;
}


sub check_file()
{
  -f $_;
}


sub check_bool()
{
  /^(true|false|yes|no|1|0|on|off)$/i;
}


# ########################################################################## #

#
# Auxilliary functions to deal with option names
#

sub derive_names(\%)
{
  my ($options) = @_;

  foreach my $spec (keys(%$options))
  {
    my $ref = $options->{$spec};
    my $opt = (split(/[=|\+\!\:]/,$spec))[0]; 

    $C->{names}->{$opt} = $ref;
  }
}


sub gen_name_list(\@;$)
{
  my ($set,$word) = @_;

  $word = $word || 'and';

  my @names = @$set;
  my $last = pop @names; 
  
  join(', ',@names) . " $word " . $last;
}


sub is_given($)
{
  my ($opt) = @_;

  my $ref = $C->{names}->{$opt};

  return 1 if ref($ref) eq "SCALAR" and defined($$ref);
  return 1 if ref($ref) eq "HASH" and %$ref;
  return 1 if ref($ref) eq "ARRAY" and @$ref;

  0;
}


# ########################################################################## #

#
# Built-in checks
#

sub error($)
{
   print '** ' . $_[0] . "\n";
}


sub fail($)
{
   print '** ' . $_[0] . "\n";
   exit 1;
}


# ########################################################################## #

1;
