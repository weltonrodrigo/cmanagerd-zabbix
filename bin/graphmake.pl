#!/usr/bin/perl

use warnings;
use strict;
use XML::Simple; #qw(:strict);
use Data::Dumper;
use Color::Mix;

# Read file.
my $file = pop @ARGV;
$file or die "$0: Nenhum arquivo especificado.";
my $graphtmpl = XMLin($file, KeepRoot => 1, KeyAttr  => 1, ForceArray => 1);
print Dumper $graphtmpl;
exit;

# Create colors.
my @colors = Color::Mix->new->analogous('0000ff', 27, 27);

# Generate items.
my @items;
foreach my $ip (1..27){ 

	my $rede  = "172.17.$ip.0/24";
	my $color = shift @colors; 

	my $item = {
		   'yaxisside' => '0',
		   'periods_cnt' => '5',
		   'item' => "Template_Openfire_CManagerd_teste:cmanagerd.clientesporrede[$rede]",
		   'sortorder' => '0',
		   'drawtype' => '1',
		   'color' => $color,
		   'type' => '0',
		   'calc_fnc' => '2',
		   };
	push @items, $item;
}

$graphtmpl->{'graph_elements'}->{'graph_element'} = \@items;
print Dumper $graphtmpl;

print XMLout($graphtmpl);
