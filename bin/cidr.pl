#!/usr/bin/perl

use warnings;
use strict;
use Net::IP;

my $ip = new Net::IP (@ARGV) or die (Net::IP::Error());

print ("IP  : ".$ip->ip()."\n");
  print ("Sho : ".$ip->short()."\n");
  print ("Bin : ".$ip->binip()."\n");
  print ("Int : ".$ip->intip()."\n");
  print ("Mask: ".$ip->mask()."\n");
  print ("Last: ".$ip->last_ip()."\n");
  print ("Len : ".$ip->prefixlen()."\n");
  print ("Size: ".$ip->size()."\n");
  print ("Type: ".$ip->iptype()."\n");
  print ("Rev:  ".$ip->reverse_ip()."\n");
