#!/usr/bin/perl -w
use strict;
use warnings;


##############################################################
# HMC: GET LPAR DEFAULT PROFILE NAME
##############################################################

sub _get_vios_profile_name {

  my ($HMC, $FRAMEID, $HOSTNAME) = @_; 	
  my $lpar_prof; 
  my $ERR;

	print "\n /usr/bin/ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC lssyscfg -r lpar -m $FRAMEID --filter \"lpar_names=$HOSTNAME\" -F curr_profile ";
        open (OUTPUT,"/usr/bin/ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC lssyscfg -r lpar -m $FRAMEID --filter \"lpar_names=$HOSTNAME\" -F curr_profile|");
        $lpar_prof = <OUTPUT>;
        close (OUTPUT);
                $ERR=$?;
                if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; exit; }

        chomp($lpar_prof);

return($lpar_prof);
}


##############################################################
# HMC: GET VIOS FOR FRAME
##############################################################

sub _get_vios_names {

  my ($HMC, $FRAMEID) = @_; 	
  my $ERR;

#  my $violist = "name,state,lpar_env";
  my $violist = "name";

  print "\n /usr/bin/ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC lssyscfg -r lpar -m $FRAMEID -F $violist";
  open (OUTPUT,"/usr/bin/ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC lssyscfg -r lpar -m $FRAMEID -F $violist|");
  my @vios = <OUTPUT>;
  close (OUTPUT);
        $ERR=$?;
        if ($ERR != 0) { print "\n Something went wrong with ssh to HMC... $! >>> RC = $ERR \n"; exit; }

  @vios = grep { /vio/ } @vios;
  @vios = sort(@vios);

return(@vios);
}


##############################################################
# HMC: DLPAR REMOVE FC ADAPTERS
##############################################################

sub _dlpar_remove_fcs {

  my ($HMC, $FRAMEID, $HOSTNAME, $SN, $SIMULATE, $PAUSE) = @_; 	
  my $ERR;

print "\n ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC chhwres -r virtualio -m $FRAMEID -o r -p $HOSTNAME --rsubtype fc -s $SN ";

if ($SIMULATE eq "false") {
	if ($PAUSE==1) { print "\n\n Press ENTER to continue: \n"; <STDIN>; }
	system "ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC chhwres -r virtualio -m $FRAMEID -o r -p $HOSTNAME --rsubtype fc -s $SN";
	        $ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; exit; }
}
}



##############################################################
# HMC: DLPAR ADD FC ADAPTERS
##############################################################

sub _dlpar_add_fcs {

# (hmc, frameid, hostname, remote_host, slotnum, remote_slotnum)

  my ($HMC, $FRAMEID, $HOSTNAME, $RHOST, $SN, $RSN, $SIMULATE) = @_; 	
  my $ERR;

  print "\n ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC chhwres -r virtualio -m $FRAMEID -o a -p $HOSTNAME --rsubtype fc -s $SN -a \"adapter_type=server,remote_lpar_name=$RHOST,remote_slot_num=$RSN\"";

  system "ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC chhwres -r virtualio -m $FRAMEID -o a -p $HOSTNAME --rsubtype fc -s $SN -a \"adapter_type=server,remote_lpar_name=$RHOST,remote_slot_num=$RSN\"";
	$ERR=$?;
	if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; exit; }
}



##############################################################
# HMC: BACKUP DEFAULT PROFILE
##############################################################
sub _backup_default_profile {

  my ($HMC, $FRAMEID, $HOSTNAME, $lpar_prof, $date) = @_; 	
  my $ERR;

	print "\n /usr/bin/ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC mksyscfg -r prof -m $FRAMEID -o save -p $HOSTNAME -n $lpar_prof.$date";
	system "/usr/bin/ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC mksyscfg -r prof -m $FRAMEID -o save -p $HOSTNAME -n $lpar_prof.$date";
       		$ERR=$?;
       		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; exit; }
}



##############################################################
# HMC: SAVE CURRENT PROFILE
##############################################################
sub _save_vio_profile {

  my ($HMC, $FRAMEID, $HOSTNAME, $lpar_prof) = @_; 	
  my $ERR;

	print "\n ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC mksyscfg -r prof -m $FRAMEID -o save -p $HOSTNAME -n $lpar_prof --force";
	system "ssh -o connecttimeout=3 -o StrictHostKeyChecking=no hscroot\@$HMC mksyscfg -r prof -m $FRAMEID -o save -p $HOSTNAME -n $lpar_prof --force";
	        $ERR=$?;
       	 if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; exit; }
}



##############################################################
# VIO: RUN CFGDEV
##############################################################
sub _vio_cfgdev {

  my ($vio) = @_; 	
  my $ERR;

	print "\n ssh -o connecttimeout=3 -o StrictHostKeyChecking=no root\@$vio /usr/ios/cli/ioscli cfgdev";
	system "ssh -o connecttimeout=3 -o StrictHostKeyChecking=no root\@$vio /usr/ios/cli/ioscli cfgdev";
       		$ERR=$?;
       		if ($ERR != 0) { print "\n Something went wrong with cfgdev... $! >>> RC = $ERR \n"; exit; }
}






return(1);

