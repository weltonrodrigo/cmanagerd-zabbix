#!/usr/bin/perl

use warnings;
use strict;
use Color::Mix;
use Data::Dumper;

my $color = Color::Mix->new;


my @analogous = $color->analogous('0000ff', 27, 36);

print Dumper \@analogous;
