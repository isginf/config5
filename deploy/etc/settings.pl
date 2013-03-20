
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

# settings.pl - Main Settings for Config5
#
# $Id: settings.pl 189 2013-03-18 08:44:08Z walteste $
# $HeadURL: https://svn.isg.inf.ethz.ch/svn/isg/config5/trunk/deploy/etc/settings.pl $

my $self = $_;

# Default umask for script execution
$self->{os}->{umask} = 022;

# SELinux support is disabled by default
$self->{os}->{selinux}->{enable} = 0;

# Syslog settings
$self->{os}->{syslog}->{enable} = 1;
$self->{os}->{syslog}->{identifier} = 'config5';
$self->{os}->{syslog}->{facility} = 'local5';

# Root path
$self->{os}->{root} = '/';
 
# Environment changes
$self->{os}->{env} = {
   'LANG' => undef,      # Use system locale
};

# Path of the disable file
$self->{disable}->{file} = '/etc/config5-disabled';

# Path of the lock file
$self->{lock}->{file} = '/var/lock/config5';

# Timeout for locking (0 means blocking forever)
$self->{lock}->{timeout} = 30;

# Name of the directory containing the feature set
$self->{features}->{name} = 'features';

# Name of the specification file
$self->{spec}->{name} = 'spec';

# Class that implements system information gathering
$self->{system}->{class} = 'Config5::System::LSB';

# Properties file
$self->{system}->{properties}->{file} = '/etc/config5-properties';

# Append the OS code name to the id (LSB system information only)
$self->{system}->{lsb}->{append_code} = 0;

# System information items
$self->{system}->{items} =
{
   'date' => [ 10, 0, 0, '', 'Date' ],
   'host' => [ 20, 1, 0, '', 'Host name' ],
   'arch' => [ 30, 1, 0, '', 'Architecture' ],
   'os' => [ 40, 1, 0, '', 'OS' ],
   'release' => [ 50, 1, 0, '', 'Release' ],
   'ip' => [ 60, 0, 0, '', 'IP' ],
   'ip6' => [ 70, 0, 0, '', 'IP6' ],
   'fqhn' => [ 80, 0, 0, '', 'FQHN' ],
   'fqdn' => [ 90, 0, 0, '', 'FQDN' ],
   'properties' => [ 100, 0, 1, '', 'Properties' ],
   'root' => [ 110, 1, 0, '', 'Root' ],
   'stage' => [ 120, 1, 0, '', 'Stage' ],
};

# The default stage
$self->{system}->{defaults}->{stage} = 'production';

# Disable command execution when root not '/'
$self->{builtin}->{execute}->{allow_chroot} = 0;

# Map change names to change classes
$self->{change}->{classes} =
{
   'append'    => 'Config5::Change::Append',
   'copy'      => 'Config5::Change::Copy',
   'truncate'  => 'Config5::Change::Truncate',
   'directory' => 'Config5::Change::Directory',
   'properties' => 'Config5::Change::Properties',
   'symlink'   => 'Config5::Change::Symlink',
   'link'      => 'Config5::Change::Link',
   'remove'    => 'Config5::Change::Remove',
   'execute'   => 'Config5::Change::Execute',
};

# Map change names to phases
$self->{change}->{phases} =
{
   'append'    => 'create',
   'copy'      => 'create',
   'truncate'  => 'create',
   'directory' => 'create',
   'properties' => 'create',
   'symlink'   => 'create',
   'link'      => 'create',
   'remove'    => 'remove',
   'execute'   => 'commands',
};

# Map change keywords as used in the spec files to change names
$self->{change}->{keywords} =
{
   'append' => 'append',
   'copy' => 'copy',
   'truncate' => 'truncate',
   'directory' => 'directory',
   'properties' => 'properties',
   'symlink' => 'symlink',
   'link' => 'link',
   'remove' => 'remove',
   'execute' => 'execute',
};

# Map change names to action classes
$self->{action}->{classes} =
{
   'copy'      => 'Config5::Action::File',
   'truncate'  => 'Config5::Action::File',
   'directory' => 'Config5::Action::Directory',
   'properties' => 'Config5::Action::Properties',
   'symlink'   => 'Config5::Action::Symlink',
   'link'      => 'Config5::Action::Link',
   'remove'    => 'Config5::Action::Remove',
   'execute'   => 'Config5::Action::Execute',
};

# Phases with priority and processing order
$self->{process}->{phases} =
{
   'packages' => [ 10, 'ordered' ],
   'remove' => [ 20, 'reversed', 'path' ],
   'create' => [ 30, 'sorted', 'path' ],
   'modify' => [ 40, 'sorted', 'path' ],
   'configure' => [ 50, 'ordered' ],
   'commands' => [ 60, 'ordered' ]
};

# Stages of the target system
$self->{stage}->{stages} =
{
   'installation' => 'I',
   'production' => 'P'
};

# Things to display at what verbosity level
$self->{display}->{entities} =
{
   'system' => 1,
   'pass' => 1,
   'status' => 1
};

# Keywords to display for changes when printed
$self->{display}->{changes} =
{
   'append'    => 'append',
   'copy'      => 'file',
   'truncate'  => 'file',
   'directory' => 'directory',
   'properties' => 'properties',
   'symlink'   => 'symlink',
   'link'      => 'link',
   'remove'    => 'remove',
   'execute'   => 'execute',
};

# Search order for best class match in each feature (first match wins)
$self->{class}->{match} =
[
   '{host}_{os}_{release}_{arch}',
   '{host}_{os}_{release}',
   '{host}_{os}_{arch}',
   '{host}_{os}',
   '{host}_{arch}',
   '{host}',
   '{properties}_{os}_{release}_{arch}',
   '{properties}_{os}_{release}',
   '{properties}_{os}_{arch}',
   '{properties}_{os}',
   '{properties}_{arch}',
   '{properties}',
   '{os}_{release}_{arch}',
   '{os}_{release}',
   '{os}_{arch}',
   '{os}',
];

1;

