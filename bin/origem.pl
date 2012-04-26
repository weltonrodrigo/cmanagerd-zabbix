#!/usr/bin/perl

use warnings;
use strict;

use String::Similarity;
use IP::Info;
use Cache::File;
use Locale::SubCountry;
use Net::IP;

my $apikey = '100.w6jjyff5vx863wdahfeg';
my $secret = 'WygHppTp';
my $ipinfo = new IP::Info($apikey, $secret);

my $cache = new Cache::File( cache_root  => '/tmp/origem-cache');

my $locale = Locale::SubCountry->new('BR'); 
my @states = $locale->all_full_names();


# Find the two-digit state code for a ip. Eg: DF, SP, CE.
sub find_state_for_ip {
	my $query = shift;
	my $ip    = new Net::IP($query) or die (Net::IP::Error());

	my $state = $cache->get($query) || query_remote($query) if $ip->iptype eq 'PUBLIC' || query_local($query);

	if ($state){
		$cache->set($query, $state, '10000 minutes'); 		
		return  $state;
	}

}


# Search for a ip on a corporative database
sub query_local{
	my $ip = shift;

	# Shortcut for testing;
	return 'local';
}


# Search for a ip on a remote database
sub query_remote{
	my $query = shift;
		
	my $response = $ipinfo->ipaddress($query);

	my $state = $response->state();

	return unless defined $state;

	# States are returned lowercase, without diacritics.
	# Need to find the closest to Locale::SubCountry to find code.

	foreach my $name ( @states ) {
		my $sim_level = similarity ("\E$state", "\E$name");

		return $locale->code($name) if $sim_level > 0.7;
	}

	# No result found.
	return 'unknow';

}

my $query = shift @ARGV;
my $state = find_state_for_ip($query);

print "$state\n" if $state;
