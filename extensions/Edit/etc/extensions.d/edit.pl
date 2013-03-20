
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

# extensions.d/edit.pl - Configuration File for the Edit Extension
#
# $Id: sebool.pl 647 2011-08-04 08:42:35Z walteste $
# $HeadURL: file:///import/svn/repositories/config5-rhel6/svn/trunk/etc/extensions.d/sebool.pl $

my $self = $_;

# Map change names to change classes
$self->{change}->{classes}->{edit} = 'Config5::Change::Extensions::Edit';

# Map change names to action classes
$self->{action}->{classes}->{edit} = 'Config5::Action::Extensions::Edit';

# Map change types as used in the spec files to names
$self->{change}->{keywords}->{edit} = 'edit';

# Map change names to phases
$self->{change}->{phases}->{edit} = 'modify';

1;

