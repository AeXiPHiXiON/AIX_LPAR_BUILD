#!/usr/bin/perl -w
use strict;
use warnings;

require '/root/web/perl/_sub_HMC_functions.pl';
require '/root/web/perl/_sub_get_vlans.pl';

# UNDER CONSTRUCTION MESSAGE
#     print "\n ***********************************************************************"; 
#     print "\n *****  This script is under construction, please try again later  *****"; 
#     print "\n *********************************************************************** \n\n"; 
#     exit;

my @INPUT = @ARGV;

if ( ! defined($INPUT[0]) || $INPUT[0] eq "test" ) {
  print "\n usage: ./_php_create_lpar_part_1.pl FRAMEID HMC HOSTNAME MEM ENT VP POOL_NAME IP SIMULATE \n\n";
  exit;
}

my $SSH="/usr/bin/ssh -q -o connecttimeout=3 -o StrictHostKeyChecking=no";

# get date format to backup current VIO HMC profile
sub _print_date {
  my($sec, $min, $hour, $day, $month, $year)=(localtime)[0,1,2,3,4,5];
  $month+=1;
  $year+=1900;
  my $date="${year}_${month}-${day}_${hour}:${min}:${sec}";
  print "\n\n date   : $date";
  return $date;
}

my $date=_print_date;

print "\n INPUT      : @INPUT";
print "\n INPUT COUNT: $#INPUT \n";

### check for already running build
  my $filePath="/tmp/_php_create_lpar_part_1.running";
  if (-f $filePath) {
     print "\n Another build is already running, please try again \t $date"; 
     print "\n File exists: $filePath"; 
     exit;
  }
  else {
    system "touch $filePath"; 
  }


my $FRAMEID=$INPUT[0];
my $HMC=$INPUT[1];
my $HOSTNAME=$INPUT[2];
my $MEM=$INPUT[3]*1024;
my $ENT=$INPUT[4];
my $VP=$INPUT[5];
my $POOL_NAME=$INPUT[6];
my $IP=$INPUT[7];
my $SIMULATE=$INPUT[8];

my $emailaddr="unixteam storage";
if ( $#INPUT > 8 ) { 
  my @emaillist = split(/\:/,$INPUT[9]);
  my $templist = join(' ',@emaillist);
  $emailaddr=$emailaddr . " " . $templist;
}

my $item;          # hash counter
my $i=0;           # counter
my $ia=0;          # counter
my $ib=0;          # counter
my $count=0;       # counter
my $ERR=0;         # return code


print "\n\n ////////////////////////////////////////////////////////////////";
print "\n ///////////////////////////////////////////////////////////////";
print "\n ///   $HMC: CREATE PROFILE FOR $HOSTNAME ";
print "\n ///////////////////////////////////////////////////////////////";
print "\n ///////////////////////////////////////////////////////////////";
print "\n INPUT    : \"@INPUT\"";
print "\n FRAMEID  : \"$FRAMEID\"";
print "\n HMC      : \"$HMC\"";
print "\n HOSTNAME : \"$HOSTNAME\"";
print "\n MEM      : \"$MEM\"";
print "\n ENT      : \"$ENT\"";
print "\n POOL_NAME: \"$POOL_NAME\"";
print "\n VP       : \"$VP\"";
print "\n IP       : \"$IP\"";
print "\n SIMULATE : \"$SIMULATE\"";
print "\n EMAIL    : \"$emailaddr\"";


_print_date;
print "\n\n ####################################################################";
print "\n\n >>> $HOSTNAME: get vlan ID for $IP";
print "\n #################################################################### \n\n";
  my $vlan;
  my @nettemp;
  my $net;
  my $loc;

  @nettemp = split(/\./,$IP);
  $net = join (".",$nettemp[0],$nettemp[1],$nettemp[2]);

# $vlandata[0]=$vlan;		# VLAN ID
# $vlandata[1]=$nimnet;		# NIM network name
# $vlandata[2]=$GW;		# GATEWAY
# $vlandata[3]=$SUB;		# SUBNET
# $vlandata[4]=$loc;		# LOCATION

  my @vlandata = _getvlans($net);
  if ( $vlandata[0] == 0 ) { print "\n Bad IP entered, exiting \n"; system "rm $filePath"; exit; }
  else {
    $vlan=$vlandata[0];
    $loc=$vlandata[4];
    print "\n\t VLAN   : $vlan";
  }




_print_date;
print "\n\n ####################################################################";
print "\n # $HMC: Check available resources on $FRAMEID";
print "\n ####################################################################";

  print "\n $SSH hscroot\@$HMC lshwres -r mem -m $FRAMEID --level sys -F curr_avail_sys_mem ";
  open (OUTPUT,"$SSH hscroot\@$HMC lshwres -r mem -m $FRAMEID --level sys -F curr_avail_sys_mem|");
  my $memframe = <OUTPUT>;
  close (OUTPUT);
	$ERR=$?;
	if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }
  chomp($memframe);

  print "\n $SSH hscroot\@$HMC lshwres -r proc -m $FRAMEID --level sys -F curr_avail_sys_proc_units ";
  open (OUTPUT,"$SSH hscroot\@$HMC lshwres -r proc -m $FRAMEID --level sys -F curr_avail_sys_proc_units|");
  my $cpuframe = <OUTPUT>;
  close (OUTPUT);
	$ERR=$?;
	if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }
  chomp($cpuframe);

  if ( $MEM > $memframe || $ENT > $cpuframe ) { 
    print "\n *********************************************";
    print "\n     Not enough resources to build LPAR.";
    print "\n *********************************************";
    print "\n\t Available CPU: $cpuframe";
    print "\n\t Requested CPU: $ENT";
    print "\n\t Available MEM: $memframe";
    print "\n\t Requested MEM: $MEM";
    print "\n ***********************************";
    print "\n     Exiting.";
    print "\n ***********************************";
    print "\n\n";
    system "rm $filePath"; exit;
  }
  else {
    print "\n >>> CPU/MEMORY resources OK";
    print "\n -------------------------------------";
    print "\n available mem: $memframe";
    print "\n available cpu: $cpuframe";
  }



_print_date;
#print "\n\n ####################################################################";
print "\n\n >>> $HOSTNAME: set min/max profile data";
#print "\n #################################################################### \n\n";
  my $minmem=$MEM/2;
  my $maxmem=$MEM*2;
  my $minent=$ENT/2;
  my $maxent=$ENT*2;
  my $minvp;
  if ( $VP == 1 ) { $minvp=$VP; }
  else { $minvp=$VP/2; }
  my $maxvp=$VP*2;
  print "\n\t min mem: $minmem";
  print "\n\t max mem: $maxmem";
  print "\n\t min ent: $minent";
  print "\n\t max ent: $maxent";
  print "\n\t min vp : $minvp";
  print "\n\t max vp : $maxvp";




_print_date;
#print "\n\n ##################################################################";
print "\n\n >>> $HMC: get VIO servers for $FRAMEID";
#print "\n ################################################################## \n\n";

  my @vio=_get_vios_names($HMC,$FRAMEID);

  my $vio01=$vio[0];
  my $vio02=$vio[1];
  chomp($vio01);
  chomp($vio02);

  print "\n\t vio01  : $vio01";
  print "\n\t vio02  : $vio02";



_print_date;
print "\n\n ##################################################################";
print "\n # $HMC: PROFILE DETAILS for $HOSTNAME";
print "\n ##################################################################";

my %lpar_profile;   # hash contains all lpar attributes

# REQUIRES LICENSE ENABLEMENT ON FRAME
# ---------------------------------------------
# $lpar_profile{mem_expansion}="1.00";
# $lpar_profile{remote_restart_capable}="0";
# ---------------------------------------------

$lpar_profile{name}="$HOSTNAME";				# USER DEFINED

$lpar_profile{profile_name}="default";
$lpar_profile{lpar_env}="aixlinux";
$lpar_profile{allow_perf_collection}="1";
$lpar_profile{all_resources}="0";
$lpar_profile{boot_mode}="norm";
$lpar_profile{auto_start}="0";
$lpar_profile{redundant_err_path_reporting}="0";
$lpar_profile{suspend_capable}="0";
$lpar_profile{conn_monitoring}="1";
$lpar_profile{power_ctrl_lpar_ids}="none";
$lpar_profile{work_group_id}="none";
$lpar_profile{vtpm_enabled}="0";

# MEMORY
$lpar_profile{min_mem}="$minmem";				# USER DEFINED
$lpar_profile{desired_mem}="$MEM";				# USER DEFINED
$lpar_profile{max_mem}="$maxmem";				# USER DEFINED
$lpar_profile{mem_mode}="ded";

# CPU
$lpar_profile{min_proc_units}="$minent";			# USER DEFINED
$lpar_profile{desired_proc_units}="$ENT";			# USER DEFINED
$lpar_profile{max_proc_units}="$maxent";			# USER DEFINED
$lpar_profile{min_procs}="$minvp";				# USER DEFINED
$lpar_profile{desired_procs}="$VP";				# USER DEFINED
$lpar_profile{max_procs}="$maxvp";				# USER DEFINED
$lpar_profile{proc_mode}="shared";
$lpar_profile{shared_proc_pool_name}="$POOL_NAME";
$lpar_profile{sharing_mode}="uncap";
$lpar_profile{uncap_weight}="128";

# VIRTUAL I/O
$lpar_profile{max_virtual_slots}="40";
$lpar_profile{virtual_serial_adapters}="0/server/1/any//any/1,1/server/1/any//any/1";
$lpar_profile{virtual_eth_vsi_profiles}="none";
$lpar_profile{lpar_io_pool_ids}="none";



_print_date;
#print "\n\n ##################################################################";
#print "\n # $HOSTNAME: VIRTUAL ETHERNET";
#print "\n ################################################################## \n\n";
# virtual-slot-number/		2
# is-IEEE/			0
# port-vlan-ID/			520 USER DEFINED
# [additional-vlan-IDs]/	''
# [trunk-priority]/		0
# is-required/			0
# [/[virtual-switch][/[MAC-address]/[allowed-OS-MAC-addresses]/[QoS-priority]]]
# ETHERNET0               ''                 all                   none
$lpar_profile{virtual_eth_adapters}="2/0/$vlan//0/0/ETHERNET0//all/none";




_print_date;
	#############################################
	# $HOSTNAME: FIBER CHANNEL
	#	DETERMINE VALUE OF NEXT FC SLOT ON VIO SERVERS
	#############################################
	my $vio01_fc;		# VIO01 ORIGINAL FC data
	my $vio02_fc;		# VIO02 ORIGINAL FC data
	my $vio01_prof;		# VIO01 current profile name
	my $vio02_prof;		# VIO02 current profile name

	##############################################
	# get the vios current profile names
	##############################################
	$vio01_prof=_get_vios_profile_name($HMC,$FRAMEID,$vio01);
	$vio02_prof=_get_vios_profile_name($HMC,$FRAMEID,$vio02);

	print "\n vio01 profile : $vio01_prof";
	print "\n vio02 profile : $vio02_prof";
	print "\n ";


_print_date;
	#######################################################################
	# get list of vios server virtual fiber channel adapters for vio01
	#######################################################################
        print "\n $SSH hscroot\@$HMC lssyscfg -r prof -m $FRAMEID -F virtual_fc_adapters --filter \"lpar_names=$vio01,profile_names=$vio01_prof\" ";
        open (OUTPUT,"$SSH hscroot\@$HMC lssyscfg -r prof -m $FRAMEID -F virtual_fc_adapters --filter \"lpar_names=$vio01,profile_names=$vio01_prof\"|");
        $vio01_fc = <OUTPUT>;
        close (OUTPUT);
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }

_print_date;
	#######################################################################
	# get list of vios server virtual fiber channel adapters for vio02
	#######################################################################
        print "\n $SSH hscroot\@$HMC lssyscfg -r prof -m $FRAMEID -F virtual_fc_adapters --filter \"lpar_names=$vio02,profile_names=$vio02_prof\" ";
        open (OUTPUT,"$SSH hscroot\@$HMC lssyscfg -r prof -m $FRAMEID -F virtual_fc_adapters --filter \"lpar_names=$vio02,profile_names=$vio02_prof\"|");
        $vio02_fc = <OUTPUT>;
        close (OUTPUT);
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }


	my $slotnum=0;      # get largest FC slot num
	my $slotnum2=0;     # slotnum+1

#	print "\n\n vio01_fc: $vio01_fc";
#	print "\n vio02_fc: $vio02_fc";


_print_date;
        #############################################
        # $HOSTNAME: SPLIT FC DATA TO ARRAY
        #############################################
	my @vio01data;      # VIO01 FC data array
	my @vio02data;      # VIO02 FC data array
	my @fc01data;       # VIO01 FC elements
	my @fc02data;       # VIO02 FC elements

        @vio01data = split(/,/,$vio01_fc);                   # split FC data to array
        @vio02data = split(/,/,$vio02_fc);                   # split FC data to array

	print "\n\n vio01data: @vio01data";
	print "\n vio02data: @vio02data";

	print "\n\n vio01data count: $#vio01data";
	print "\n vio02data count: $#vio02data";

	if ( $#vio01data == 0 || $#vio02data == 0 ) { $slotnum=99; }
	else {
          for ($i=0; $i < @vio01data; $i++) {
            $vio01data[$i] =~ s/"//g;                             # clean double quotes
            $vio01data[$i] =~ s/\n//g;                            # clean new line
            $vio02data[$i] =~ s/"//g;                             # clean double quotes
            $vio02data[$i] =~ s/\n//g;                            # clean new line

            @fc01data = split(/\//,$vio01data[$i]);                       # split slot data to array
            @fc02data = split(/\//,$vio02data[$i]);                       # split slot data to array
	    print "\n fc01data: @fc01data";
	    print "\n fc02data: @fc02data";

            if ($slotnum < $fc01data[0]) { $slotnum=$fc01data[0]; print "\n slotsum : $slotnum"; }
            if ($slotnum < $fc02data[0]) { $slotnum=$fc02data[0]; print "\n slotsum : $slotnum"; }
          }
	}

        $slotnum++;
        $slotnum2=$slotnum+1;



_print_date;
#########################
# LPAR: VIRTUAL FIBER CHANNEL
#########################
# *** need to first get remote slot number from VIO server
# virtual-slot-number/		10,20
# client-or-server/		client
# [remote-lpar-ID]/		optional, use vio name instead
# [remote-lpar-name]/		$vio01,$vio02
# remote-slot-number/		get from VIO
# [wwpns]/			do not use, auto-generated
# is-required			0
$lpar_profile{virtual_fc_adapters}="10/client//$vio01/$slotnum//0,11/client//$vio01/$slotnum2//0,20/client//$vio02/$slotnum//0,21/client//$vio02/$slotnum2//0";



_print_date;
#############################################
# LPAR: LPAR PRE BUILD
#############################################
my @lpar_config;    # array to be converted to CSV
my $lpar_load;	    # attributes to be written to load file

# ----------------------------------
# PRINT KEY SORTED HASH TO STDOUT
# ----------------------------------
foreach $item (sort (keys (%lpar_profile))) {
  print "\n lpar_profile : $item=$lpar_profile{$item}";
}


# ----------------------------------
# PUSH HASH ITEMS ONTO ARRAY
# ----------------------------------
foreach $item (keys (%lpar_profile)) {
  push @lpar_config, "\"$item=$lpar_profile{$item}\"";
}
#  print "\n\n lpar_config :\n @lpar_config ";


# ----------------------------------
# JOIN ARRAY TO CSV 
# ----------------------------------
$lpar_load = join(",", @lpar_config);
#  print "\n\n lpar_load   :\n $lpar_load ";


print "\n\n # ------------------------------------------------------------";
print "\n # WRITE LOAD DATA TO FILE: /tmp/LPAR_NEW_$HOSTNAME.prof";
print "\n # ------------------------------------------------------------";

print "\n > /tmp/LPAR_NEW_$HOSTNAME.prof";
open (INPUT, "> /tmp/LPAR_NEW_$HOSTNAME.prof") || die "Could not open file: $!";
print INPUT "$lpar_load\n" || die "Could not print to file: $!";
close (INPUT);
	$ERR=$?;
	if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }




_print_date;
#################################################################################
# END SIMULATION MODE
#################################################################################
if ($SIMULATE ne "false") { 
	print "\n\n ###############################################################";
	print "\n     Simulation only, exiting."; 
	print "\n ############################################################### \n\n";
	system "rm $filePath"; 
	exit;
}

if ($HOSTNAME eq "HOSTNAME" || $IP eq "0.0.0.0") { 
	print "\n\n ###############################################################";
	print "\n     HOSTNAME = $HOSTNAME"; 
	print "\n     IP       = $IP"; 
	print "\n     Please check HOSTNAME or IP, exiting."; 
	print "\n ############################################################### \n\n";
	system "rm $filePath"; 
	exit;
}


_print_date;
  if ($POOL_NAME ne "DefaultPool") { 
    _check_cpu_pool($ENT, $HMC, $FRAMEID, $POOL_NAME, $HOSTNAME); 
  }


_print_date;
	print "\n\n ###############################################################";
	print "\n # $HMC: CREATE PROFILE FOR $HOSTNAME ON $FRAMEID";
	print "\n ###############################################################";

	print "\n >>> COPY LOAD FILE TO HMC \n";
	system "scp /tmp/LPAR_NEW_$HOSTNAME.prof hscroot\@$HMC:/home/hscroot";
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }

        ############################################################## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        # if procpool is set to 0, then this will fail                 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        ############################################################## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	print "\n >>> RUN MKSYSCFG AGAINST LOAD FILE \n";
	system "$SSH hscroot\@$HMC mksyscfg -r lpar -m $FRAMEID -f /home/hscroot/LPAR_NEW_$HOSTNAME.prof";
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }

	print "\n >>> REMOVE LOAD FILE FROM HMC \n";
	system "$SSH hscroot\@$HMC rm /home/hscroot/LPAR_NEW_$HOSTNAME.prof";
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }

	print "\n ------------------------------------------------------------";
	print "\n $HMC: $HOSTNAME profile has been created on $FRAMEID";
	print "\n ------------------------------------------------------------ \n\n";




_print_date;
print "\n\n /////////////////////////////////////////////////////////////////";
print "\n /////////////////////////////////////////////////////////////////";
print "\n /// $HMC: START VIO SERVER CONFIG FOR $HOSTNAME";
print "\n /////////////////////////////////////////////////////////////////";
print "\n ///////////////////////////////////////////////////////////////// \n\n";


	print "\n\n ###############################################################";
	print "\n # $FRAMEID: BACKUP $vio01 and $vio02 DEFAULT PROFILES";
	print "\n ############################################################### \n";

	_backup_default_profile($HMC,$FRAMEID,$vio01,$vio01_prof,$date);
	_backup_default_profile($HMC,$FRAMEID,$vio02,$vio02_prof,$date);

	print "\n ------------------------------------------------------------";
	print "\n >>> VIO profile has been saved as $vio01_prof.$date";
	print "\n >>> VIO profile has been saved as $vio02_prof.$date";
	print "\n ------------------------------------------------------------ \n\n";



_print_date;
################################################
# DEFINE VIO DATA VARIABLES
################################################
my @vio01_map;      # LSMAP (vio01)
my @vio02_map;      # LSMAP (vio02)
my @vfcdata01;    # LSMAP TEMP ARRAY FOR VFCHOST (vio01)
my @vfcdata02;    # LSMAP TEMP ARRAY FOR VFCHOST (vio02)
my @vfcnt01;      # LSMAP PHYSICAL FC DEVICE NAMES MAPPED TO VIRTUAL (vio01)
my @vfcnt02;      # LSMAP PHYSICAL FC DEVICE NAMES MAPPED TO VIRTUAL (vio02)
my @vio01_dev;    # LSDEV (vio01)
my @vio02_dev;    # LSDEV (vio02)
my @fcnames01;    # LSDEV ALL AVAILABLE PHYSICAL FC DEVICE NAMES (vio01)
my @fcnames02;    # LSDEV ALL AVAILABLE PHYSICAL FC DEVICE NAMES (vio02)
my @devdata01;    # LSDEV TEMP ARRAY FOR DEVICE DATA (vio01)
my @devdata02;    # LSDEV TEMP ARRAY FOR DEVICE DATA (vio02)
my %vfchost01;    # COUNT VFCHOST MAPPED FCS ADAPTERS
my %vfchost02;    # COUNT VFCHOST MAPPED FCS ADAPTERS
my @vfchostID01;
my @vfchostID02;



_print_date;
print "\n\n ###############################################################";
print "\n # HMC: DLPAR VIO WITH NEW SERVER FC SLOT";
print "\n ############################################################### \n";

_dlpar_add_fcs($HMC, $FRAMEID, $vio01, $HOSTNAME, $slotnum, 10);
_dlpar_add_fcs($HMC, $FRAMEID, $vio01, $HOSTNAME, $slotnum2, 11);
_dlpar_add_fcs($HMC, $FRAMEID, $vio02, $HOSTNAME, $slotnum, 20);
_dlpar_add_fcs($HMC, $FRAMEID, $vio02, $HOSTNAME, $slotnum2, 21);

print "\n ------------------------------------------------------------";
print "\n >>> VIO has been updated with new server FC adapter";
print "\n ------------------------------------------------------------ \n\n";




_print_date;
	print "\n\n ###############################################################";
	print "\n # HMC: SAVE CURRENT PROFILES TO DEFAULT";
	print "\n ############################################################### \n";

	_save_vio_profile($HMC, $FRAMEID, $vio01, $vio01_prof);
	_save_vio_profile($HMC, $FRAMEID, $vio02, $vio02_prof);

	print "\n ------------------------------------------------------------";
	print "\n >>> VIO current config has been saved to the default profile";
	print "\n ------------------------------------------------------------ \n\n";





_print_date;
	print "\n\n //////////////////////////////////////////////////////////////////";
	print "\n //////////////////////////////////////////////////////////////////";
	print "\n ///   VIO: GET LEAST USED PHYSICAL FC ADAPTER";
	print "\n //////////////////////////////////////////////////////////////////";
	print "\n ////////////////////////////////////////////////////////////////// \n\n";


	print "\n\n ###############################################################";
	print "\n # VIO: RUN CFGMGR AND GET NEW VFCHOST ADAPTER";
	print "\n ############################################################### \n";

	_vio_cfgdev($vio01);
	_vio_cfgdev($vio02);

	print "\n ------------------------------------------------------------";
	print "\n >>> VIO cfgdev completed";
	print "\n ------------------------------------------------------------ \n\n";



_print_date;
	print "\n #########################################################";
	print "\n # GET LSMAP DATA for $vio01";
	print "\n #########################################################";
        open (OUTPUT,"$SSH root\@$vio01 /usr/ios/cli/ioscli lsmap -all -npiv -fmt :|");
        @vio01_map = <OUTPUT>;
        close (OUTPUT);
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }

_print_date;
	print "\n #########################################################";
	print "\n # GET LSMAP DATA for $vio02";
	print "\n #########################################################";
        open (OUTPUT,"$SSH root\@$vio02 /usr/ios/cli/ioscli lsmap -all -npiv -fmt :|");
        @vio02_map = <OUTPUT>;
        close (OUTPUT);
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }

#       print "\n vio01_map: \n @vio01_map";
#       print "\n vio02_map: \n @vio02_map";
#       print "\n ";


_print_date;
        my $lparid;
        print "\n ##########################################";
        print "\n # Get LPAR ID for $HOSTNAME";
        print "\n ########################################## \n";
        open (OUTPUT,"$SSH hscroot\@$HMC lssyscfg -r prof -m $FRAMEID -F lpar_id --filter lpar_names=$HOSTNAME|");
        $lparid=<OUTPUT>;
        close (OUTPUT);
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }
        chomp($lparid);
	print "\n # LPAR ID: $lparid \n";



_print_date;
        print "\n ###############################################";
        print "\n # GET VFCHOST FOR $HOSTNAME, LPAR ID: $lparid";
        print "\n ############################################### \n";

        for($i=0; $i < @vio01_map; $i++) {
          @vfcdata01 = split(/:/,$vio01_map[$i]);
	  # SET vfchostID01 to vfchost name
            if ( $vfcdata01[2] eq $lparid ) { 
		$vfchostID01[$ia]=$vfcdata01[0]; 
		print "\n vfchostID01[$ia]=$vfchostID01[$ia]";
		$ia++; 
	    }
	  # SET vfccnt TO PHYSICAL FCS DEVICE NAME
            $vfcnt01[$i]= $vfcdata01[6]; 	
        }

        for($i=0; $i < @vio02_map; $i++) {
          @vfcdata02 = split(/:/,$vio02_map[$i]);
	  # SET vfchostID02 to vfchost name
            if ( $vfcdata02[2] eq $lparid ) { 
		$vfchostID02[$ib]=$vfcdata02[0]; 
		print "\n vfchostID02[$ib]=$vfchostID02[$ib]";
		$ib++; 
	    }
	  # SET vfccnt TO PHYSICAL FCS DEVICE NAME
            $vfcnt02[$i]= $vfcdata02[6]; 	
        }


_print_date;
	print "\n #############################################################";
	print "\n # INCREMENT HASH ITEM FOR EACH MAPPED PHYSICAL FCS DEVICE ";
	print "\n ############################################################# \n";

        # TOTAL PHYSICAL FC DEVICE WITH A MAPPED VIRTUAL DEVICE
        # COUNT FC DEVICES AND STORE COUNT IN HASH WITH DEVICE KEY
        foreach $item (@vfcnt01) { $vfchost01{$item}++ }
        foreach $item (@vfcnt02) { $vfchost02{$item}++ }



_print_date;
        print "\n ###############################################################";
        print "\n # VIO: GET LSDEV DATA FOR FCS ADAPTERS";
        print "\n ############################################################### \n";

        open (OUTPUT,"$SSH root\@$vio01 lsdev -Cc adapter|");
        @vio01_dev = <OUTPUT>;
        close (OUTPUT);
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }

        open (OUTPUT,"$SSH root\@$vio02 lsdev -Cc adapter|");
        @vio02_dev = <OUTPUT>;
        close (OUTPUT);
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }

        # GREP FCS DEVICES
        @vio01_dev = grep { /fcs/ } @vio01_dev;        # grep fcs devices
        @vio01_dev = grep { /8Gb|16Gb/ } @vio01_dev;        # grep 8Gb or 16Gb (not FCoE)

        @vio02_dev = grep { /fcs/ } @vio02_dev;        # grep fcs devices
        @vio02_dev = grep { /8Gb|16Gb/ } @vio02_dev;        # grep 8Gb or 16Gb (not FCoE)


_print_date;
	print "\n #####################################################################";
	print "\n # ASSIGN ALL AVAILABLE PHYSICAL FCS DEVICE NAMES TO fcnames01";
	print "\n #####################################################################";
        for($i=0; $i < @vio01_dev; $i++) {
          @devdata01 = split(/ /,$vio01_dev[$i]);
          $devdata01[0] =~ s/ +/ /g;                      # clean spaces
          $devdata01[0] =~ s/\n//g;                       # clean newline
          $fcnames01[$i] = $devdata01[0];
        }
	print "\n fcnames01: @fcnames01";

_print_date;
	print "\n #####################################################################";
	print "\n # ASSIGN ALL AVAILABLE PHYSICAL FCS DEVICE NAMES TO fcnames02";
	print "\n #####################################################################";
        for($i=0; $i < @vio02_dev; $i++) {
          @devdata02 = split(/ /,$vio02_dev[$i]);
          $devdata02[0] =~ s/ +/ /g;                      # clean spaces
          $devdata02[0] =~ s/\n//g;                       # clean newline
          $fcnames02[$i] = $devdata02[0];
        }
	print "\n fcnames02: @fcnames02";



	my @newdev01;     # FC ADAPTER WITH FEWEST MAPPINGS (vio01)
	my @newdev02;     # FC ADAPTER WITH FEWEST MAPPINGS (vio02)

	# $fcnames01[$i]: contains the pFC names on vios01
	# $vfchost01{$fcnames01[$i]} : contains the count of mapped vfchosts to pFC adapter 
	# newdev01[0] = vio01 fcsx, newdev01[1] = vio01 fcsy
	# newdev02[0] = vio02 fcsx, newdev02[1] = vio02 fcsy

_print_date;
	print "\n ############################################";
        print "\n # SET newdev01 to least used fcs device";
	print "\n ############################################ \n";
	$count=999;  
	$ia=@fcnames01-1;
        for($i=0; $i < @fcnames01; $i++) {
          if (defined($vfchost01{$fcnames01[$i]})) {
		print "\n FCS $fcnames01[$i]: $vfchost01{$fcnames01[$i]} vfchosts mapped";

                if ($vfchost01{$fcnames01[$i]} < $count) {
                  $count = $vfchost01{$fcnames01[$i]};		# set count to lowest number of fcs mappings

		  if ( $i < $ia  ) { $newdev01[0]=$fcnames01[$i]; $newdev01[1]=$fcnames01[$i+1]; }
		  else { $newdev01[0]=$fcnames01[$i-1]; $newdev01[1]=$fcnames01[$i]; }
		}
          } else { 
		if ( $i < $ia  ) { $newdev01[0]=$fcnames01[$i]; $newdev01[1]=$fcnames01[$i+1]; }
		else { $newdev01[0]=$fcnames01[$i-1]; $newdev01[1]=$fcnames01[$i]; }
		last; 
		}
        }

# this is required for frames 770e and 770f due to different physical fcs names
_print_date;
	print "\n ############################################";
        print "\n # SET newdev02 to least used fcs device";
	print "\n ############################################ \n";

	$count=999;  
	$ia=@fcnames02-1;
        for($i=0; $i < @fcnames02; $i++) {
          if (defined($vfchost02{$fcnames02[$i]})) {
		print "\n FCS $fcnames02[$i]: $vfchost02{$fcnames02[$i]} vfchosts mapped";

                if ($vfchost02{$fcnames02[$i]} < $count) {
                  $count = $vfchost02{$fcnames02[$i]};		# set count to lowest number of fcs mappings

		  if ( $i < $ia  ) { $newdev02[0]=$fcnames02[$i]; $newdev02[1]=$fcnames02[$i+1]; }
		  else { $newdev02[0]=$fcnames02[$i-1]; $newdev02[1]=$fcnames02[$i]; }
		}
          } else { 
		if ( $i < $ia  ) { $newdev02[0]=$fcnames02[$i]; $newdev02[1]=$fcnames02[$i+1]; }
		else { $newdev02[0]=$fcnames02[$i-1]; $newdev02[1]=$fcnames02[$i]; }
		last; 
		}
        }

#      this can be used if all frames have same physical fcs names
#        for($i=0; $i < @newdev01; $i++) {
#	  $newdev02[$i]=$newdev01[$i];
#	}



_print_date;
	print "\n\n ###############################################################";
	print "\n # VIO: MAP VFCHOST ADAPTER TO PHYSICAL FC";
	print "\n ############################################################### \n\n";


	for($i=0; $i < @vfchostID01; $i++) {
		print "\n $SSH root\@$vio01 /usr/ios/cli/ioscli vfcmap -vadapter $vfchostID01[$i] -fcp $newdev01[$i]";
		system "$SSH root\@$vio01 /usr/ios/cli/ioscli vfcmap -vadapter $vfchostID01[$i] -fcp $newdev01[$i]";
	}
	for($i=0; $i < @vfchostID01; $i++) {
		print "\n $SSH root\@$vio02 /usr/ios/cli/ioscli vfcmap -vadapter $vfchostID02[$i] -fcp $newdev02[$i]";
		system "$SSH root\@$vio02 /usr/ios/cli/ioscli vfcmap -vadapter $vfchostID02[$i] -fcp $newdev02[$i]";
	}







_print_date;
print "\n\n ###############################################################";
print "\n # $HMC: POWER ON LPAR IN SMS MODE";
print "\n ############################################################### \n\n";
system "$SSH hscroot\@$HMC chsysstate -r lpar -m $FRAMEID -o on -f default -b sms -n $HOSTNAME";

my $lpar_state="Inactive";

# check lpar is in "Open Firmware" state before logging in wwns
while($lpar_state ne "Open Firmware") {
	print "\n LPAR STATE: $lpar_state";
	sleep(10);
	open (OUTPUT, "$SSH hscroot\@$HMC lssyscfg -r lpar -m $FRAMEID -F state --filter lpar_ids=$lparid|");
	$lpar_state = <OUTPUT>;
	close(OUTPUT);
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }
	chomp($lpar_state);
}
print "\n LPAR STATE: $lpar_state";


_print_date;
print "\n\n ###############################################################";
print "\n # $HMC: LOGIN WWNS";
print "\n ############################################################### \n\n";

print "\n # $SSH hscroot\@$HMC chnportlogin -o login -m $FRAMEID --id $lparid \n";
system "$SSH hscroot\@$HMC chnportlogin -o login -m $FRAMEID --id $lparid";
print "\n wwns logged in";


_print_date;
print "\n\n ###############################################################";
print "\n # $HMC: Enable performance collection and profile sync";
print "\n ############################################################### \n\n";

print "\n # $SSH hscroot\@$HMC chsyscfg -r lpar -m $FRAMEID -i \"lpar_id=$lparid,allow_perf_collection=1,sync_curr_profile=1\" \n";
system "$SSH hscroot\@$HMC chsyscfg -r lpar -m $FRAMEID -i \"lpar_id=$lparid,allow_perf_collection=1,sync_curr_profile=1\"";
print "\n Performance collection and profile sync enabled ";

_print_date;
print "\n\n ###############################################################";
print "\n # MAIL: SEND WWNS TO STORAGE TEAM";
print "\n ############################################################### \n\n";

	open (OUTPUT, "$SSH hscroot\@$HMC lssyscfg -r prof -m $FRAMEID -F virtual_fc_adapters --filter lpar_names=$HOSTNAME|");
	my @wwns = <OUTPUT>;
	close(OUTPUT);
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }

	open (INPUT,"|/usr/bin/mail -s \"NEW LPAR BUILD STORAGE REQUEST: $HOSTNAME [$lparid] $FRAMEID\" $emailaddr");
	print INPUT "Storage team,";
	print INPUT "\n\n Please zone (2) 100GB luns for ROOTVG to the following wwn's \n";

	my @temp = split(/","/,$wwns[0]);
	my @temp2;

 	for($i=0; $i < @temp; $i++) {
	  $temp[$i] =~ s/"//g;
	  @temp2 = split(/\//,$temp[$i]);
	  print       "\n FCS.$i $temp2[0] : $temp2[3] : $temp2[4] : $temp2[5]";
	  print INPUT "\n FCS.$i $temp2[0] : $temp2[3] : $temp2[4] : $temp2[5]";
	}

	print INPUT "\n\n Please add permissions to the following share for $HOSTNAME. *** OS install will fail if mount permissions are not complete ***  \n";

	if ($loc eq "atl") {
	  print INPUT "\n RW,ROOT \t /mksysb      \t atlnetapp05data01:/vol/mksysb_backups";
	  print INPUT "\n RW,ROOT \t /home_share  \t atlclus02-nas01-nfs-lif1-7:/home_directories";
	  print INPUT "\n RO      \t /scripts     \t atlnetapp06data01:/vol/vio_scripts";
	  print INPUT "\n RO      \t /nim         \t atlnetapp06data01:/vol/vio_software";
	}
	if ($loc eq "dal") {
	  print INPUT "\n RW,ROOT \t /mksysb      \t dalclus01-nas02-nfs-lif2:/mksysb_backups";
	  print INPUT "\n RW      \t /home_share  \t dalclus01-nas01-nfs-lif3:/home_directories";
	  print INPUT "\n RO      \t /scripts     \t dalclus01-nas02-nfs-lif2:/vio_scripts";
	  print INPUT "\n RO      \t /nim         \t dalclus01-nas02-nfs-lif2:/vio_software";
	}

	close (INPUT);
		$ERR=$?;
		if ($ERR != 0) { print "\n Something went wrong... $! >>> RC = $ERR \n"; system "rm $filePath"; exit; }

print "\n ###############################################################";
print "\n MAIL sent to storage team and requested rootvg luns.";
print "\n LPAR BUILD part 1 complete.";
print "\n ############################################################### \n\n";

system "rm $filePath"; 

_print_date;




# print "\n\n ###############################################################";
# print "\n # MAIL: OPEN SERVICE REQUEST AND ASSIGN TO SAN TEAM";
# print "\n ############################################################### \n\n";

#	open (INPUT,"|/usr/bin/mail -s \"NEW LPAR BUILD STORAGE REQUEST: $HOSTNAME [$lparid] $FRAMEID\" $emailaddr");
#	print INPUT "\n Storage team,";
#	print INPUT "\n Please zone (2) 100GB luns for ROOTVG to the following wwn's \n";

##############################################
# get these values from PHP form
#  my $REQUESTEDFOR="UID";
#  my $OPENBY="first last <first_last\@domain.com>";
#  my $NEEDBY="2016-07-26";
##############################################

##############################################
# STATIC VALUES
#  my $GROUP="GPC IT SAN Storage";
#  my $CATEGORY="hardware";
#  my $SHORTDESC="NEW LPAR BUILD STORAGE REQUEST: $HOSTNAME [$lparid] $FRAMEID";
#  my $DESC="Please zone (2) 100GB luns for ROOTVG to the following wwn's";
#  my $PURPOSE="NEW LPAR BUILD STORAGE REQUEST: $HOSTNAME [$lparid] $FRAMEID";
#  my $SIMULATE="false";
##############################################

#  my $DATA="$REQUESTEDFOR::::$OPENBY::::$NEEDBY::::$GROUP::::$CATEGORY::::$SHORTDESC::::$DESC::::$PURPOSE::::$SIMULATE";

# print "\n\n Open Service Request \n /root/web/SR_email_send.sh \"$DATA\" \n\n";
# system "/root/web/SR_email_send.sh \"$DATA\"";

        # END MAIN
######################


##############################################################################
# SUB CHECK CPU POOL
##############################################################################
 sub _check_cpu_pool {
   # _check_cpu_pool($ENT, $HMC, $FRAMEID, $POOL_NAME, $HOSTNAME); 
   my $ENT_COUNT=shift;
   my $HMC=shift;
   my $FRAMEID=shift;
   my $POOL_NAME=shift;
   my $HOSTNAME=shift;

   my $MAX_POOL_SIZE=0;
   my @POOL_LIST;
   my $i;
   my @temp;

   print "\n\n ###############################################################";
   print "\n # $HMC: Check $POOL_NAME max_pool_proc_units size";
   print "\n ############################################################### \n\n";

   ##########################
   # GET MAX POOL SIZE
   ##########################
     $MAX_POOL_SIZE = `$SSH hscroot\@$HMC lshwres -r procpool -m $FRAMEID --filter \"pool_names=$POOL_NAME\" -F max_pool_proc_units`;
     chomp($MAX_POOL_SIZE);
     print "\n $POOL_NAME max pool proc units is: $MAX_POOL_SIZE";

   ##################################
   # GET list of lpar in POOL_NAME
   ##################################
     @POOL_LIST = `$SSH hscroot\@$HMC lshwres -r proc -m $FRAMEID  --level lpar -F curr_shared_proc_pool_name,curr_proc_units  --filter pool_names=$POOL_NAME`;

     for($i=0; $i < @POOL_LIST; $i++) {
        chomp($POOL_LIST[$i]);
        @temp = split(",",$POOL_LIST[$i]);
        $ENT_COUNT=$ENT_COUNT+$temp[1];
     }
     print "\n Total entitled allocation of lpars in $POOL_NAME is: $ENT_COUNT";

   #####################################################
   # Increase max pool size if less than ent count
   #####################################################

    if ( $MAX_POOL_SIZE < $ENT_COUNT ) {
       print "\n Increase max pool size.";
       $ENT_COUNT=int($ENT_COUNT+0.5);
       print "\n $SSH hscroot\@$HMC chhwres -r procpool -m $FRAMEID -o s --poolname $POOL_NAME -a \"max_pool_proc_units=$ENT_COUNT\" \n";
       system "$SSH hscroot\@$HMC chhwres -r procpool -m $FRAMEID -o s --poolname $POOL_NAME -a \"max_pool_proc_units=$ENT_COUNT\"";

       # NOTIFY DBA GROUP OF NEW POOL SIZE
 	open (INPUT,"|/usr/bin/mail -s \"NEW LPAR BUILD PROC POOL INCREASE: [$HOSTNAME] $FRAMEID\" aixteam oracle");
 	print INPUT "\n DBAs, \n";
 	print INPUT "\n Proc pool *** $POOL_NAME *** was increased to: $ENT_COUNT \n";
         close (INPUT);
     }

 }
