#!/usr/bin/perl

use warnings;
use strict;

use Linux::Proc::Net::TCP;
use Net::IP;

# GLOBALS
my $Port   = shift;
my $Wanted = shift;


# Returns array ref containing uniq ip address connected at a 
# given port on this host.
sub get_clients {
	my $port = shift;

	my %wanted;
	foreach ( @{Linux::Proc::Net::TCP->read(ip6 => 1)} ){
		$wanted{$_->rem_address}++ if $_->local_port eq $port;
	}
	
	return sort keys %wanted;
}

my $ipinfo = new IP::Info::Local;

my $count = 0;
foreach my $entry (get_clients($Port)){
	$count++ if $ipinfo->find_state_for_ip($entry) eq $Wanted;
}

print "$count\n";

exit 0;

package IP::Info::Local;

use String::Similarity;
use IP::Info;
use Locale::SubCountry;
use Cache::File;
use Net::IP;

my $apikey = '100.w6jjyff5vx863wdahfeg';
my $secret = 'WygHppTp';

sub new{
	my $class = shift;

	my $self = {
		cache  => new Cache::File( cache_root  => '/tmp/origem-cache'),
		ipinfo => new IP::Info($apikey, $secret),
		locale => Locale::SubCountry->new('BR'),
	};
	$self->{states} = $self->{locale}->all_full_names();

	return bless $self, $class;
}

# Find the two-digit state code for a ip. Eg: DF, SP, CE.
sub find_state_for_ip {
	my $self  = shift;
	my $query = shift;
	my $ip    = new Net::IP($query) or die (Net::IP::Error());

	my $state = $self->{cache}->get($query) || $ip->iptype eq 'PUBLIC' ? query_remote($query) : query_local($query);

	if ($state){
		$self->{cache}->set($query, $state, '10000 minutes'); 		
		return  $state;
	}

}

# Search for a ip on a corporative database
sub query_local{
	my $self = shift;
	my $ip   = shift;

	# Shortcut for testing;
	return 'local';
}


# Search for a ip on a remote database
sub query_remote{
	my $self  = shift;
	my $query = shift;
		
	my $response = $self->{ipinfo}->ipaddress($query);

	my $state = $response->state();

	return unless defined $state;

	# States are returned lowercase, without diacritics.
	# Need to find the closest to Locale::SubCountry to find code.

	foreach my $name ( @{$self->{states}} ) {
		my $sim_level = similarity ("\E$state", "\E$name");

		return $self->{locale}->code($name) if $sim_level > 0.7;
	}

	# No result found.
	return 'unknow';

}

1;
