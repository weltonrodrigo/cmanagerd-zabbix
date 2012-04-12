#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
use Color::Mix;
use File::Slurp;

# Read file.
my $file = pop @ARGV;
$file or die "$0: Nenhum arquivo especificado.";

my $xml = read_file($file);
my $template = q| <graph_element item="Template_Openfire_CManagerd_teste:cmanagerd.clientesporrede[%rede%]">
              <drawtype>1</drawtype>
              <sortorder>0</sortorder>
              <color>%color%</color>
              <yaxisside>0</yaxisside>
              <calc_fnc>2</calc_fnc>
              <type>0</type>
              <periods_cnt>5</periods_cnt>
            </graph_element>
|;

# Create colors.
my @colors = Color::Mix->new->analogous('0000ff', 28, 28);
print join ", ", @colors;

# Generate items.
my $items;
foreach my $ip (1..27){ 

	my $rede = "172.17.$ip.0/24";
	my $color = shift @colors;

	my $item = $template;

	$item =~ s/%rede%/$rede/;
	$item =~ s/%color%/$color/;

	$items .= $item;
}

# Incluir os graficos no arquivo original.
$xml =~ s/%elementos%/$items/;

print $xml;
