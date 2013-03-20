package File::ApplicationLock;

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

# File::ApplicationLock - Lock File for Applications
#
# $Id: ApplicationLock.pm 139 2011-11-28 10:27:12Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/lib/perl/File/ApplicationLock.pm $

use strict;
use warnings;

use Fcntl qw(:flock :DEFAULT);


sub new
{
   my ( $perlclass, $file, $time ) = @_;

   # Truncate
   open my $fh, '+>', $file or return;

   if ($time)
   {
      # Poll lockfile, catches a released lock one second later at worst
      while (! flock $fh, LOCK_NB | LOCK_EX)
      {
         close($fh), return
            if $time-- <= 0;
         sleep 1;
      }
   }
   else
   {
      # Blocking lock, catches released locks immediately
      close($fh), return
         unless flock $fh, LOCK_EX;
   }
  
   my $self = { file => $file, fh => $fh };

   bless $self, $perlclass;
}


sub DESTROY
{
    my ($self) = @_;

    return unless defined $self;

    # Remove and unlock lock file
    unlink $self->{file};
    flock $self->{fh}, LOCK_UN;
    close $self->{fh};
}


1;

