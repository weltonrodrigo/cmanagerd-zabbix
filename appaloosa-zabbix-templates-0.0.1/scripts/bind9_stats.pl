#!/usr/bin/perl
# Copyright 2010 (c) PalominoDB.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.

use strict;
use warnings FATAL => 'all';
use Net::DNS;
use Time::HiRes qw(gettimeofday tv_interval);
use constant DEBUG => $ENV{DEBUG} || 0;

# Path set to empty so that this script can be run SUID root.
$ENV{PATH} = "";

# The path to rndc. Redhat default shown below.
my $rndc = '/usr/sbin/rndc';

# The path to the stats file produced by named when 'rndc stats' is called.
# Redhat default shown below.
my $stats_file = '/var/named/chroot/var/named/data/named_stats.txt';

# The path to the zone/cache dump file produce by named when 'rndc dumpdb'
# is called. Redhat default shown below.
my $dump_file = '/var/named/chroot/var/named/data/cache_dump.db';

# Path to the named pidfile - used for determining named memory usage.
# Redhat default shown below.
my $pid_file = '/var/run/named.pid';

# By default, the ip for this nameserver is set to localhost.
# This is used for doing latency queries, and you may want to
# set it to an external ip to get more "representative" latencies.
my $ns_ip = '127.0.0.1';

# The default query to perform for latency timings.
# You probably want to change this to an actually configured zone.
my $ns_query = 'localhost.localdomain';

##############################################################################
# Below here, you shouldn't need to change anything.
##############################################################################

sub rndc {
  my $stats = {};
  my $o;
  unlink($stats_file);
  my $r = qx/$rndc stats 2>&1/;
  chomp($r);
  if($r =~ /failed|error|found/i) {
    DEBUG && print(STDERR "$r\n");
    return {};
  }
  {
    local $/;
    open BIND_STATS, "<$stats_file";
    $o = <BIND_STATS>;
    close BIND_STATS;
  }
  foreach (split "\n", $o) {
    chomp;
    next if(/_bind$/);
    next if(/^---/);
    next if(/^\+\+\+/);
    my ($stat, $val, $domain) = split;
    if(not defined($domain)) {
      $$stats{'global'}{$stat} = int($val);
    }
    else {
      $$stats{$domain}{$stat} = int($val);
    }
  }
  return $stats;
}

sub nrecords {
  my $count = 0;
  my $o;
  my $r = qx/$rndc dumpdb -zones 2>&1/;
  chomp($r);
  if($r =~ /failed|error|found/i) {
    DEBUG && print(STDERR "$r\n");
    return -1;
  }

  open my $bind_dump, "<$dump_file";
  while(<$bind_dump>) {
    chomp;
    # simply count up the number of lines in the file
    # one of the following record types: NS, A, MX, AAAA, PTR.
    # other record types are currently ignored.
    $count++ if(/IN\s+(?:NS|A|MX|AAAA|PTR)/);
  }
  close $bind_dump;
  return $count;
}

if( scalar(@ARGV) < 1 ) {
  print <<EOF;
Usage: bind9_stats.pl <stat> <zone>

Where stat is one of:

native per zone:
These statistics are measured by BIND and we
read them directly from the dump file produced
by 'rndc stats'
  - success
  - referral
  - nxrrset
  - nxdomain
  - recursion
  - failure

If <zone> is specified, then the stats reported will be
just for that zone, otherwise, they are global.

calculated:
These statistics are measured outside BIND, or by
doing a more complicated operation.


  - 'latency' performs a query and measures response time.
  - 'pid'   returns the pid of the named process
  - 'VmPeak' peak memory usage of named.
  - 'VmSize' current memory usage
  - 'VmLck' locked in memory
  - 'VmHWM' high water mark
  - 'VmRSS' resident size
  - 'VmData' data size
  - 'VmStk' stack size
  - 'VmExe' exec size
  - 'VmLib' shared library
  - 'VmPTE' page table entries
  Of the above memory status, only VmSize and VmRSS are likely to be of
  interest. The others are included for completeness.

  - 'zones'  tracks how many zones are configured

  - 'records' number of A, NS, AAAA, MX, and PTR records configured.

NOTE: This script needs to be run as 'root', or the 'named' user
      since it needs to read and delete the rndc stats file.
      A simple way to achieve that is to make the script SUID named.

EOF
  exit(0);
}

my $pid = 0;
my $fh;
my $stats = rndc();
my $stat = shift @ARGV;
my $zone = shift @ARGV;
$zone ||= 'global';

# if no stats returned from RNDC, then clearly there's an error.
if( scalar( keys %$stats ) == 0 ) {
  print("-1\n");
  exit(0);
}

my $res = Net::DNS::Resolver->new( nameservers => [$ns_ip] );
my $t0 = [gettimeofday];
my $pckt = $res->query($ns_query);
$$stats{'global'}{'latency'} = tv_interval( $t0 );
$$stats{'global'}{'zones'} = scalar( keys %$stats );

# Special case the 'records' stat, because
# for very large zones, this could likely be expensive.
# so, it's only computed as necessary.
if( $stat eq 'records' ) {
  $$stats{'global'}{'records'} = nrecords();
}

if( -f $pid_file ) {
  eval {
    {
      local $/;
      open $fh, "<$pid_file" or die("unable to open pidfile");
      $pid = <$fh>;
      close($fh);
    }
  };
  chomp($pid);
  $$stats{'global'}{'pid'} = $pid;
  open $fh, "/proc/$pid/status";
  while( <$fh> ) {
    next unless(/^(Vm|Threads).*/);
    my ($s, $v, $unit) = split(/\s+/, $_);
    $s =~ s/://;
    $$stats{'global'}{$s} = $v;
    if($unit and $unit eq 'kB') {
      $$stats{'global'}{$s} *= 1024;
    }
  }
  close($fh);
}

# print a per-zone stat, if available falling back to
# the global zone, or return -1 on error.
print( (defined $$stats{$zone}{$stat}
          ? $$stats{$zone}{$stat}
            : $$stats{'global'}{$stat} || -1), "\n");
