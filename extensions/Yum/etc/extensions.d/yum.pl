
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

# extensions.d/yum.pl - Configuration File for the Yum Extension
#
# $Id: yum.pl 180 2012-08-27 14:09:33Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/Yum/etc/extensions.d/yum.pl $

my $self = $_;

# Map change names to change classes
$self->{change}->{classes}->{yum} = 'Config5::Change::Extensions::Yum';

# Map change names to action classes
$self->{action}->{classes}->{yum} = 'Config5::Action::Extensions::Yum';

# Map change types as used in the spec files to names
$self->{change}->{keywords}->{yum} = 'yum';

# Map change names to phases
$self->{change}->{phases}->{yum} = 'packages';

1;

