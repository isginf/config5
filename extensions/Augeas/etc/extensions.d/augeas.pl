
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

# extensions.d/augeas.pl - Configuration File for the Augeas Extension
#
# $Id: augeas.pl 177 2012-08-23 14:08:42Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/extensions/Augeas/etc/extensions.d/augeas.pl $

my $self = $_;

# Map change names to change classes
$self->{change}->{classes}->{augeas} = 'Config5::Change::Extensions::Augeas';

# Map change names to action classes
$self->{action}->{classes}->{augeas} = 'Config5::Action::Extensions::Augeas';

# Map change types as used in the spec files to names
$self->{change}->{keywords}->{augeas} = 'augeas';

# Map change names to phases
$self->{change}->{phases}->{augeas} = 'configure';

1;

