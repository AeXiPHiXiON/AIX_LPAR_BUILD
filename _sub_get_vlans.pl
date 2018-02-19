#!/usr/bin/perl -w
use strict;
use warnings;

#######################################
# 
#######################################

sub _getvlans {
  my ($net) = @_; 	#  network address

  my @vlan;

$vlan[0]=0; 	# vlan id
$vlan[1]=0;	# nim network name
$vlan[2]=0; 	# gateway
$vlan[3]=0;	# subnet
$vlan[4]=0;	# location

# ATLANTA
if ( $net eq "192.168.1"  ) { $vlan[0]="192"; $vlan[1]="net192";   $vlan[2]="192.168.1.1";  $vlan[3]="255.255.255.0"; $vlan[4]="atl"; return(@vlan); }


print "\n\n*** $net NETWORK NOT DEFINED, EXITING. ***\n\n"; 
return(@vlan);

}


return(1);


