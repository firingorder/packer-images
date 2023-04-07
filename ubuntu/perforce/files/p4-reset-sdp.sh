#!/bin/bash
#==============================================================================
# Copyright and license info is available in the LICENSE file included with
# this package, and also available online:
# https://swarm.workshop.perforce.com/projects/perforce_software-helix-installer/view/main/LICENSE
#------------------------------------------------------------------------------

#==============================================================================
# Declarations
set -u

declare ThisScript="${0##*/}"
declare Version=4.11.7

# The latest SDP release tarfile has a consistent name, sdp.Unix.tgz,
# alongside the version-named tarball (e.g. sdp.Unix.2019.3.26494.tgz).
# This is best when you want the latest officially released SDP.

# An alternate install method uses Helix native DVCS features to get the very
# latest code from a branch ('dev' by default) using a 'p4 clone' command.
# Alternately, the '-d' flag can be used to copy from a local directory.
declare SDPTar="sdp.Unix.tgz"

# See usage info for the '-d' flag in this script.
declare SDPCopyDir="/sdp"
declare SDPURL="https://swarm.workshop.perforce.com/projects/perforce-software-sdp/download/downloads/$SDPTar"
declare SDPInstallMethod=FTP
declare SDPInstallBranch=Unset
declare FTPURL="https://ftp.perforce.com/perforce"
declare WorkshopPort="public.perforce.com:1666"
declare WorkshopUser=ftp
declare WorkshopRemote=
declare WorkshopBaseURL="https://swarm.workshop.perforce.com"
declare HelixInstallerProjectURL="$WorkshopBaseURL/projects/perforce_software-helix-installer"
declare HelixInstallerBaseURL="$HelixInstallerProjectURL/download"
declare HelixInstallerTarURL="$HelixInstallerBaseURL/downloads/helix_installer.tgz"
declare HelixInstallerBranch="main"
declare HelixInstallerURL="$HelixInstallerBaseURL/$HelixInstallerBranch"
declare HelixInstallerFileURL=
declare HxMetadata1=
declare HxMetadata2=
declare HxLogs=
declare DirList=
declare Hostname=
declare Timezone=
declare UseSystemdOption=
declare -i UseSystemd=1
declare -i CMDEXITCODE

# The values for set here are for use in the usage() function if '-man' is
# used. They are set again further down in the code below, after settings
# are loaded from the config file which might change the values set here.
declare HxDepots="hxdepots"
declare BinDir="/$HxDepots/helix_binaries"
declare ApiArch="linux26x86_64"
declare P4BinRel=r22.2
declare P4APIRel=r22.2
declare RunUser="perforce"
declare ResetHome="/$HxDepots/reset"
declare DownloadsDir="/$HxDepots/downloads"
declare SudoersEntry="$RunUser ALL=(ALL) NOPASSWD: ALL"
declare SudoersFile="/etc/sudoers.d/$RunUser"
declare SudoersDir="${SudoersFile%/*}"
declare BinList=
declare ServerBin=
declare SiteBinDir="/p4/common/site/bin"
declare MailSimulator="$SiteBinDir/mail"
declare LimitedSudoersTemplate="$ResetHome/perforce_sudoers.t"

# This lists all files needed to operate the Helix Installer, which can be
# acquired during runtime operation in environments where outbound access to
# the public internet is available, or provisioned ahead of time for
# operation when such access is not available.
declare HelixInstallerFiles="NoTicketExpiration.group.p4s admin.user.p4s configure_sample_depot_for_sdp.sh p4broker_N.service.t p4broker_N.xml.t p4d_N.service.t p4d_N.xml.t p4p_N.service.t p4p_N.xml.t perforce_bash_profile perforce_bashrc protect.p4s perforce_sudoers.t r"
declare SDPHome=
declare SSLDir=
declare SSLConfig=
declare TmpFile=/tmp/tmp.reset_sdp.$$.$RANDOM
declare TmpDir=/tmp/tmp.dir.reset_sdp.$$.$RANDOM
declare ShelvedChange=Unset
declare LocalShelvedChange=Unset
declare CmdLine="${0##*/} $*"
declare -i WarningCount=0
declare -i ErrorCount=0
declare InitMechanism=Unset
declare PackageManager=Unset
declare -A PackageList
declare -A ExtraP4PackageList
declare -A Config ConfigDoc
declare -i BlastDownloadsAndBinaries=0
declare -i StopAfterReset=0
declare -i ExtremeCleanup=0
declare -i InstallDerivedAPIs=0
declare -i PullFromWebAsNeeded=1
declare -i UseSSL=1
declare -i GenDefaultConfig=0
declare -i LimitedSudoers=0
declare -i MultiRun=0
declare -i SetHostname=0
declare -i SetTimezone=0
declare -i SetServerID=0
declare -i SetServerType=0
declare -i SetSimulateEmail=0
declare -i SetListenPort=0
declare -i SetTargetPort=0
declare -i SetTargetServerID=0
declare -i SimulateEmail=0
declare -i UseBroker=0
declare -i UseConfigFile=0
declare ConfigFile=Unset
declare PreserveDirList=Unset
declare RunUserNewHomeDir=
declare RunUserHomeDir=
declare RunGroup=Unset
declare UserAddCmd=
declare P4YumRepo="/etc/yum.repos.d/perforce.repo"
declare P4AptGetRepo="/etc/apt/sources.list.d/perforce.list"
declare PerforcePackageRepoURL="https://package.perforce.com"
declare PerforcePackagePubkeyURL="$PerforcePackageRepoURL/perforce.pubkey"
declare TmpPubKey=/tmp/perforce.pubkey
declare -i AddPerforcePackageRepo=1
declare -i InstallCrontab=1
declare -i UpdatePackages=1
declare -i RunOSTweaks=1
declare SampleDepotTar=
declare CrontabFileInP4=
declare CrontabFile=
declare ThisArch=
declare ThisHost=
declare ThisOS=
declare ThisOSName=
declare ThisOSDistro=
declare ThisOSMajorVersion=
declare FirewallType=
declare FirewallDir=
declare ThisUser=
declare RunArch="x86_64"
declare CBIN="/p4/common/bin"
declare CCFG="/p4/common/config"
declare -i DoSDPVerify=0
declare -i DoFirewall=1
declare -i DoSudo=1
declare SDPVerify="$CBIN/verify_sdp.sh"
declare SDPVerifyCmd=
declare SDPVerifyOptions=
declare SDPVerifySkipTests=
declare SystemdTemplatesDir="/p4/common/etc/systemd/system"
declare SDPSetupDir="/p4/sdp/Server/Unix/setup"
declare SDPUnsupportedSetupDir="/p4/sdp/Unsupported/setup"
declare OSTweaksScript="$SDPSetupDir/os_tweaks.sh"
declare SDPCrontabDir=
declare SDPInstances="1"
declare SDPDefaultInstance=
declare OSTweaksScript=
declare ServerID=
declare ServerType=
declare ListenPort=
declare TargetPort=
declare TargetServerID=
declare MkdirsCmd=

#==============================================================================
# Static Configuration - Package Lists

# The associative array 'PackageList' defines packages required for each
# package manager (yum, apt-get, or zypper).
PackageList['yum']="bc cronie curl gcc gcc-c++ mailx make openssl openssl-devel rsync tar wget which zlib zlib-devel"
PackageList['apt-get']="bc build-essential cron libssl-dev make zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev rsync"
PackageList['zypper']="bc cronie curl gcc gcc-c++ make openssl openssl-devel wget which zlib zlib-devel rsync"
ExtraP4PackageList['yum']="perforce-p4python3"
ExtraP4PackageList['apt-get']="perforce-p4python3"
ExtraP4PackageList['zypper']=

#==============================================================================
# Static Configuration - User Config Data

# User modifiable data is defined in the 'Config' associative array, with
# corresponding user documentation in the 'ConfigDoc' array, corresponding
# to the settings.cfg file the user modifies.

# To add a new setting, define values for both Config['YourNewValue] and
# ConfigDoc['YourNewValue]' in this block. Also, ensure the values are written
# in the appropriate section of the sample config file generated in the
# function gen_default_config().

#------------------------------------------------------------------------------
# Settings Section 1: Localization
# Keep the order that settings are defined here in sync with the 'for c in'
# loop in gen_default_config() for Section 1 below. That defines the desired
# order of appearance in the generated file.

ConfigDoc['SMTPServer']="\\n# Specify email server for the p4review script. Ignore if Helix Swarm is used."
Config['SMTPServer']="smtp.p4demo.com"
ConfigDoc['P4AdminList']="\\n# Specify an email address to receive updates from admin scripts. This may be\\n# a distribution list or comma-separated list of addresses (with no spaces)."
Config['P4AdminList']="P4AdminList@p4demo.com"
ConfigDoc['MailFrom']="\\n# Specify an email address from which emails from admin scripts are sent.\\n# This must be a single email address."
Config['MailFrom']="P4Admin@p4demo.com"
ConfigDoc['DNS_name_of_master_server']="\\n# Specify the DNS alias to refer to he master server, e.g. by end\\n# users. This might be 'perforce' but probably not an actual host name\\n# like 'perforce01', which would be known only to admins."
Config['DNS_name_of_master_server']="helix"
ConfigDoc['SiteTag']="\\n# Specify a geographic site tag for the master server location,\\n# e.g. 'bos' for Boston, MA, USA."
Config['SiteTag']="bos"
ConfigDoc['Hostname']="\\n# Specify the hostname.  This can be left blank. If set on a system that supports\\n# the 'hostnamectl' utility, that utility will be used to set the hostname.  If the\\n# command line parameter '-H <hostname>' is used, that will override this setting."
Config['Hostname']=""
ConfigDoc['Timezone']="\\n# Specify the timezone.  This can be left blank. If set on a system that supports\\n# the 'timedatectl' utility, that utility will be used to set the timezone.  If the\\n# command line parameter '-T <timezone>' is used, that will override this setting."
Config['Timezone']=""

#------------------------------------------------------------------------------
# Settings Section 2: Data Specific
# Keep the order that settings are defined here in sync with the 'for c in'
# loop in gen_default_config() for Section 2 below. That defines the desired
# order of appearance in the generated file.

ConfigDoc['P4_PORT']="\\n# Specify the TCP port for p4d to listen on. Typically this is 1999 if \\n# p4broker is used, or 1666 if only p4d is used."
Config['P4_PORT']="1999"
ConfigDoc['P4BROKER_PORT']="\\n# Specify the TCP port for p4broker to listen on. Must be different\\n# from the P4_PORT."
Config['P4BROKER_PORT']="1666"
ConfigDoc['Instance']="\\n# Specify SDP instance name, e.g. '1' for /p4/1."
Config['Instance']="1"
ConfigDoc['CaseSensitive']="\\n# Helix Core case sensitivity, '1' (sensitive) or '0' (insensitive). If\\n# data from a checkpoint is to be migrated into this instance, set this\\n# CaseSensitive value to match the case handling of the incoming data set\\n# (as shown with 'p4 info')."
Config['CaseSensitive']="1"
ConfigDoc['P4USER']="\\n# Set the P4USER value for the Perforce super user."
Config['P4USER']="perforce"
ConfigDoc['Password']="\\n# Set the password for the super user (see P4USER). If using this Helix Installer to\\n# bootstrap a production installation, replace this default password with your own."
Config['Password']="F@stSCM!"
ConfigDoc['SimulateEmail']="\\n# Specify '1' to avoid sending email from admin scripts, or 0 to send\\n# email from admin scripts."
Config['SimulateEmail']="1"
ConfigDoc['ServerID']="\\n# Specify a ServerID value. Leave this value blank for master/commit servers.\\n# The value for master/commit servers is set automatically."
Config['ServerID']=""
ConfigDoc['ServerType']="\\n# Specify the type of server. Valid values are:\\n# * p4d_master - A master/commit server.\\n# * p4d_replica - A replica with all metadata from the master (not filtered in\\n# any way).\\n# * p4d_filtered_replica - A filtered replica or filtered forwarding replica.\\n# * p4d_edge - An edge server.\\n# * p4d_edge_replica - Replica of an edge server. Also set TargetServerID.\\n# * p4broker - An SDP host running only a broker, with no p4d.\\n# * p4proxy - An SDP host running a proxy (maybe with a broker in front), with\\n# no p4d.\\n#\\n# The ServerID must also be set if the ServerType is any p4d_*\\n# type other than 'p4d_master'."
Config['ServerType']="p4d_master"
ConfigDoc['TargetServerID']="\\n# Set only if ServerType is p4d_edge_replica. The value is the ServerID of\\n# edge server that this server is a replica of, and must match the\\n# 'ReplicatingFrom:' field of the server spec."
Config['TargetServerID']=
ConfigDoc['TargetPort']="\\n# Specify the target port for a p4proxy or p4broker."
Config['TargetPort']=
ConfigDoc['ListenPort']="\\n# Specify the listening port for a p4proxy or p4broker."
Config['ListenPort']=

#------------------------------------------------------------------------------
# Settings Section 3: Deep Customization
# Keep the order that settings are defined here in sync with the code in
# gen_default_config() for Section 3 below. That defines the desired order of
# appearance in the generated file.

ConfigDoc['OSUSER']="\\n# Specify the Linux Operating System account under which p4d and other Helix\\n# services will run as. This user will be created if it does not exist. If\\n# created, the password will match that of the P4USER."
Config['OSUSER']="perforce"
ConfigDoc['OSGROUP']="\\n# Specify the primary group for the Linux Operating System account specified\\n# as OSUSER."
Config['OSGROUP']="perforce"
ConfigDoc['OSUSER_ADDITIONAL_GROUPS']="\\n#Specify a comma-delimited list of any additional groups the OSUSER to be\\n# created should be in.  This is passed to the 'useradd' command the '-G'\\n# flag. These groups must already exist."
Config['OSUSER_ADDITIONAL_GROUPS']=
ConfigDoc['OSUSER_HOME']="\\n# Specify home directory of the Linux account under which p4d and other Helix\\n# services will run as, and the group, in the form <user>:<group>.  This user\\n# and group will be created if they do not exist."
Config['OSUSER_HOME']="/home/perforce"
ConfigDoc['P4BinRel']="\\n# The version of Perforce Helix binaries to be downloaded: p4, p4d, p4broker, and p4p."
Config['P4BinRel']="$P4BinRel"
ConfigDoc['P4APIRel']="\\n# The version of the C++ API to be downloaded, for building dervied APIs such\\n# as P4Perl and P4Python.  This is typically the same as P4BinRel, but\\n# sometimes behind as P4Perl and P4Python can lag behind Helix Core releases."
Config['P4APIRel']="$P4APIRel"
ConfigDoc['HxDepots']="\\n# Define the directory that stores critical digital assets that must be\\n# backed up, including contents of versioned files, metadata checkpoints,\\n# and numbered journal files."
Config['HxDepots']="/hxdepots"
ConfigDoc['HxLogs']="\\n# Define the directory used to store the active journal (P4JOURNAL) and\\n# various logs."
Config['HxLogs']="/hxlogs"
ConfigDoc['HxMetadata1']="\\n# The /HxMetadata1 and /HxMetadata1 settings define two interchangeable\\n# directories that store either active/live metadata databases (P4ROOT) or\\n# offline copies of the same (offline_db). These typically point to the same\\n# directory. Pointing them to the same directory simplifies infrastructure\\n# and enables the fastest recovery options. Using multiple metadata volumes\\n# is typically done when forced to due to capacity limitations for metadata\\n# on a single volume, or to provide operational survivability of the host in\\n# event of loss of a single metadata volume."
Config['HxMetadata1']="/hxmetadata"
ConfigDoc['HxMetadata2']=
Config['HxMetadata2']="/hxmetadata"

#------------------------------------------------------------------------------
# Function: usage (required function)
#
# Input:
# $1 - style, either -h (for short form) or -man (for man-page like format).
#------------------------------------------------------------------------------
function usage
{
   declare style=${1:--h}

   msg "USAGE for $ThisScript v$Version:

$ThisScript [-c <cfg>] [-no_ssl] [-no_cron] [-no_ppr] [-no_systemd] [-no_firewall] [-no_tweaks] [-no_sudo|-ls] [-v] [-fast|-dapi] [-t <ServerType>] [-s <ServerID>] [-ts <TargetServerID>] [-tp <TargetPort>] [-lp <ListenPort>] [-se] [-H <hostname>] [-T <timezone>] [-local|-B] [[-d <sdp_dir>] | [-b <branch>[,@cl]]] [-p <dir1>[,<dir2>,...]>] [-i <helix_installer_branch>] [-D] [-X|-R] [-M]

or

$ThisScript -C > settings.cfg

or

$ThisScript [-h|-man]
"
   if [[ $style == -man ]]; then
      msg "
SAFETY NOTICE:
	This script SHOULD NEVER EXIST on a Production Perforce server.

	It is useful for bootstrapping a new Production server machine
	as well as demo hardware, but this script should be removed after
	it has successfully executed on a Production server.

DESCRIPTION:
	This script simplifies the process of testing an SDP installation,
	repetitively blasting all process by the 'perforce' user and resetting
	the SDP from the ground up, blasting typical SDP folders each time.

	By default, it installs the Perforce Helix Core server (P4D) with a
	P4Broker, and installs the Perforce Sample Depot data set used for
	training and PoC installations. With command line options, it can
	also install a proxy (P4P) server or a server running only a
	P4Broker (e.g. in a DMZ).

	It is helpful when bootstrapping a demo server with a sample data
	set, complete with broker, and optionally Perl/P4Perl and
	Python/P4Python.

	This script handles many aspects of installation. It does the
	following:
	* Creates the OS user that will run the Helix Core p4d process,
	  the 'perforce' user by default, using the 'useradd' command,
	  unless that account already exists.  If a non-local account
	  is to be used, that should be created first before running this
	  script. If the account is created using 'useradd', the password
	  will be set to match that of the admin P4USER, which is also
	  'perforce' by default (matching the OSUSER).
	* Creates the home directory for the OSUSER user, if needed.
	* Creates and enables systemd *.service files if neeeded.
	* Does needed SELinux/systemd configuration if semanage and
	restorecon are available.
	* Adds OS packages as needed for P4Perl/P4Python local builds
	  (if -dapi is specified).

	Following installation, it also does the following to be more
	convenient for demos, and also give a more production-like feel:
	* Grants the perforce user sudo access (full or limited).
	* Creates default ~perforce/.bash_profile and .bashrc files.
	* Connects to the Perforce Package Repository (APT and YUM only).
	* Adds firewalld rules for Helix server and broker ports ('firewalld'
	only; there is no support for the 'ufw' or other firewalls).
	* Installs crontab for ~perforce user.

PLATFORM SUPPORT:
	This works on Red Hat Enterprise Linux, CentOS, and Mac OSX
	10.10+ thru Mojave platforms.  It works on RHEL/CentOS
	6.4-7.6, SuSE Linux 12, and likely on Ubuntu 18 and other Linux
	distros with little or no modification.

	This script currently supports the bin.linux26x86_64 (Linux) and
	bin.maxosx1010x86_64 (Mac OSX/Darwin) architectures.

	This script recognizes SysV, Systemd, and Launchd init mechanisms,
	though does not currently support Launchd on OSX.

	For Mac OSX, note that this requires bash 4.x, and the default
	bash on Mac OSX remains 3.x as of OSX Mojave.  For operating on
	Mac, the /bin/bash shebang line needs to be adjusted to reference
	a bash 4 version, e.g. /usr/local/bin/bash if installed with
	Homebrew.

REQUIREMENTS:
	The following OS packages are installed (unless '-fast' is
	used):

	* Yum: ${PackageList[yum]}

	* AptGet: ${PackageList[apt-get]}

	* Zypper: ${PackageList[zypper]}

	Development utilities such as 'make', the 'gcc' compiler,
	and 'curl' will be available (unless running with '-fast').

	In addition, if the Perforce Package Repository is added,
	these additional packages are installed:

	* Yum: ${ExtraP4PackageList[yum]}

	* AptGet: ${ExtraP4PackageList[apt-get]}

	* Zypper: None, as the Perforce Package Repository does
	not support the Zypper package management system (e.g.
	as used on SuSE Linux).

OPTIONS:
 -c <cfg>
	Specify a config file.  By default, values for various settings
	such as the email to send script logs to are configure with
	demo values, e.g. ${Config['P4AdminList']}.  Optionally, you can
	specify a config file to define your own values.

	For details on what settings you can define in this way, run:
	$ThisScript -C > setings.cfg

	Then modify the generated config file settings.cfg as desired.
	The generated config file contains documentation on settings and
	values.  If no changes are made to the generated file, running with
	'-c settings.cfg' is the equivalent of running without using '-c' at
	all.

 -C	See '-c <cfg>' above.

 -no_ssl
	By default, the Perforce server is setup SSL-enabled.  Specify
	'-no_ssl' to avoid using SSL feature.

 -no_cron
	Skip initialization of the crontab.

 -no_ppr
	Skip addition of the Perforce Package Repository for YUM/APT
	repos.  By default, the Package Repository is added.

 -no_sudo
	Specify that no updates to sudoers are to be made.

	WARNING: If systemd/systemctl is used to manage Perforce
	Helix services, the OSUSER that operates these services
	('perforce' by default) requires sufficient sudo access to
	start and stop services. Using this option may result in
	an unusable service being created.

	If this option is used, consider also using '-no_systemd'.
	Alternately, it is appropriate to use this option if the
	machine it operates on was based on a machine image that
	pre-creates the OSUSER with sufficient sudo accces.

	This option is mutually exclusive with '-ls'.

 -ls	Specify that only limited sudo is to be granted.  By default
 	full sudo access is granted to the OSUSER by adding this file:

	$SudoersFile

	with these contents:

	$SudoersEntry

	If '-ls' is specified, limited sudoers access is provisioned,
	with just enough access to execute commands like:

	systemctl <start|stop|status> p4d_*
	systemctl <start|stop|status> p4dtg_*
	systemctl <start|stop|status> p4broker_*
	systemctl <start|stop|status> p4p_*

	For more detail, see the template file: perforce_sudoers.t

	This option is mutually exclusive with '-no_sudo'.

 -v
 	Specify '-v' to run the verify_sdp.sh script after the SDP
	installation is complete. If '-v' is specified and the
	verify_sdp.sh script is available in the SDP, it is executed.
	If the Sample Depot is loaded, the '-online' flag to the
	verify_sdp.sh script is added.  If '-no_cron' is specified,
	the corresponding '-skip cron' option is added verify_sdp.sh.

 -fast	Specify '-fast' to skip package installation using
	the package manager (yum, apt-get, or zypper).

	The '-fast' flag should not be used if you plan to
	deploy or develop triggers that use P4Python or P4Perl,
	such as the SDP CheckCaseTrigger.py.

 -dapi	Specify '-dapi' (derived API) to attempt install of
	the SDP derived APIs if they are available in the
	SDP package. Those scripts are no longer included
	in the SDP 2020.1+.  This option may be deprecated
	in a future release.

	Pragmatically, this option is only useful if local
	builds are needed for Perl, Ruby, associated derived
	APIs such as P4Perl.

	For Python and P4Pytyon in particular, this option
	is not needed if you are operating on a platform for
	which the perforce-p4python3 package is available.

	The '-fast' and '-dapi' options are mutually exclusive.

 -local
	By default, various files and binaries are downloaded from
	the Perforce Workshop and the Perforce FTP server as needed.
	If the server machine on which the Helix Installer is to be
	run cannot reach the public internet or if using files from
	external sites is not desired, the '-local' flag can be used.

	With '-local', needed files must be acquired and put in place
	on the server machine on which this script is to be run.  Any
	missing files result in error messages.

	The '-local' argument cannot be used with -B.

	For '-local' to work, the following must exist:

	1. Helix Binaries
	
	Helix binaries must exist in $BinDir:

	* $BinDir/p4
	* $BinDir/p4d
	* $BinDir/p4broker
	* $BinDir/p4p

	2. Server Deployment Package (SDP)

	The SDP tarball must be acquired an put in place here:

	* $DownloadsDir/$SDPTar

	3. Helix Installer

	With '-local', the 'reset_sdp.sh' script and all related files must
	be acquired and placed in $ResetHome.

	See EXAMPLES below for sample of acquiring files for use with
	'-local' mode.

 -B	Specify '-B' to blast base SDP dirs, for a clean start.

	Otherwise without '-B', downloaded components from earlier
	runs will be used (which should be fine if they were run
	recently).

	The '-B' flag also replaces files in the $ResetHome
	directory, where this script lives, with those downloaded
	from The Workshop (the versions of which are affected
	by the '-i <helix_installer_branch>' flag, described
	below).

	The '-B' flag also blasts the /tmp/downloads and /tmp/p4perl
	directories, used by reset_sdp_python.sh and
	reset_sdp_perl.sh, if they exist.

 -no_firewall
	Specify '-no_firewall' to skip updates to firewall.

	By default, if on a system for which the host-local firewall
	service available is one this script handles (currently firewalld
	but not ufw), then the firewall service is updated to open
	appropriate ports for the Perforce Helix services installed.

 -no_systemd
	Specify '-no_systemd' to avoid using systemd, even if it
	appears to be available. By default, systemd is used if it
	appears to be available.

	This is helpful in operating in containerized test environments
	where systemd is not available.

	This option is implied if the systemctl command is not available
	in the PATH of the root user.

 -no_tweaks
 	Skip execution of the SDP operating system tweaks script,
	os_tweaks.sh.

 -t <ServerType>
 
 	Specify the type of server. Valid values are:

	* p4d_master - A master/commit server.
	* p4d_replica - A replica with all metadata from the master (not
	  filtered i any way).
	* p4d_filtered_replica - A filtered replica or filtered forwarding
	  replica.
	* p4d_edge - An edge server.
	* p4d_edge_replica - Replica of an edge server. Also set
	  TargetServerID.
	* p4broker - An SDP host running only a p4broker, with no p4d.
	* p4proxy - An SDP host running only a p4proxy, with no p4d no p4d.
	
 -s <ServerID>
 	Specify the ServerID.  A ServerID is required if the ServerType is
       	any p4d_* type other than p4d_master.

 -ts <TargetServerID>
 	Specify the Target ServerID. Set this only if ServerType is
	p4d_edge_replica. The value is the ServerID of edge server that
	this server is a replica of, and must match the ReplicatingFrom:
	field of the server spec.

 -tp <TargetPort>
 	Specify the target port.  For p4broker and p4proxy only.

 -lp <ListenPort>
 	Specify the port to listen on.  For p4broker and p4proxy only.

 -se
 	Specify -se to simulate email. This generates a mail simlator
	script: $MailSimulator

 -H <hostname>
 	Set the hostname.  This is only supported on systems that
	support the 'hostnamectl' command. The hostname is set by
	doing: hostnamectl set-hostname <hostname>

	If the corresponding 'Hostname' setting is defined in the
	configuration file and this '-H <hostname>' flag is used,
	the command line option will override the config file.

 -T <timezone>
 	Set the timezone.  This is only supported on systems that
	support the 'timedatectl' command. The timezone is set by
	doing: timedatectl set-timezone <timezone>

	If the corresponding 'Timezone' setting is defined in the
	configuration file and this '-T <timezone>' flag is used,
	the command line option will override the config file.

 -p <dir1>[,<dir2>,...]>]
	Specify a comma-delimited list of directories under /p4/common
	to preserve that would otherwise be removed.  Directories must
	be specified as paths relative to /p4/common, and cannot contain
	spaces.

	For example, the value '-p config,bin/triggers' would preserve the
	$CCFG and $CBIN/triggers directories.

	Directories specified are moved aside to a temporary working area
	before the SDP folders are removed.  After installation, they are
	moved back via an 'rsync' command with no '--delete' option.  This
	means any files that overlap with the stock install are replaced
	by ones that originally existed, but non-overlapping files are not
	removed.

	This is intended to be useful for developing test suites that
	install server under $CBIN, e.g. Component Based Development
	scripts which install under $CBIN/cbd would use '-p bin/cbd'.

 -d <sdp_dir>
	Specify a directory on the local host containing the SDP to deploy.

	Use the special value '-d default' to use the /sdp directory (as per
	the Docker-based SDP Test Suite environment).

	The directory specified by '-d' is expected to contain either:
	* an SDP tarball ($SDPTar) file, or
	* an already-extracted SDP directory, which must include the SDP
	Version file.

 -b <branch>[,@cl]
	The default SDP install method is to use the latest released SDP
	tarball representing the main branch in The Workshop ($WorkshopPort).

	The latest tarball can be found on this server, consistently named
	$SDPTar. This file appears alongside a version-tagged file
	named something like sdp.Unix.2019.2.25938.tgz.  These appear here:
	https://swarm.workshop.perforce.com/projects/perforce-software-sdp/files/downloads

	Specify '-b' to use a different branch, typically '-b dev'.  This
	changes the install method from a tarball to using a 'p4 clone'
	command using Helix native DVCS features to fetch the very latest
	unreleased files from the branch at any point in time. This is mainly
	of interest when testing the SDP or previewing specific up and
	coming features.

	If '-b' is specified with the optional @cl syntax, where @cl
	specifies a changelist with files shelved on the given branch,
	a form of unshelving is done, enabling a workflow for testing
	shelved changes with the Helix Installer.  So for example,
	specify '-b dev,@23123' to clone from the dev branch, and then
	followed by a fetch of shelved changelist @23123, which is
	expected to have files shelved in the dev branch.

DEBUGGING OPTIONS:
 -i	<helix_installer_branch>

	Specify the branch of the Helix Installer to use.  This affects the
	URL from which Helix Installer files in $ResetHome are pulled from
	The Workshop.  The default is main; an alternative is '-i dev'.

 -D     Set extreme debugging verbosity.

 -X	Extreme reset. This removes the user account for the configured
	OSUSER ('$RunUser' by default) and blasts all SDP-related directories
	at the start of script operations, including the home directory
	for the configured OSUSER and any configurd system services.

	This also clears firewall rules ('firewalld' only).

	Using '-X' does not blast the Helix Installer downloads or
	helix_binaries directories, and thus is compatible with either the
	'-B' or '-local' options.

	This also does not undo the setting of the hostname or the timezone
	with either the command line ('-H <hostname>' and '-T <timezone>')
	or configuration file settings.

 -R	Specify '-R' to reset.  The cleanup logic is the same as with
	-X.  Unlike -X, with -R, processing stops after the cleanup is
	done.

 -M	Specify '-M' to allow multiple runs. This is useful for running
 	a series of tests. This option disables the safety feature that
	self-disables this script after it completes.
	
	to prevent accidentally running this
	script again, e.g. after real data has been migrated to this
	machine after using this script to bootstrap for production.

HELP OPTIONS:
 -h	Display short help message.
 -man	Display this full manual page.

 --help
	Alias for -man.

EXAMPLES:
	=== FAST INSTALLATION (skipping package updates) ===

	su -
    	mkdir -p /hxdepots/reset
	cd /hxdepots/reset
	curl -k -s -O $HelixInstallerURL/src/$ThisScript
	curl -k -s -O $HelixInstallerURL/src/r
	chmod +x ${ThisScript} r
	./r

	Note that the 'r' wrapper script calls the $ThisScript script with
	a pre-defined of flags optimized for fast operation.  The 'r' wrapper
	also handles log capture, writing to the file '${ThisScript/sh/log}'.

	=== COMPREHENSIVE INSTALLATION ===

	su -
    	mkdir -p /hxdepots/reset
	cd /hxdepots/reset
	curl -k -s -O $HelixInstallerURL/src/$ThisScript

	chmod +x $ThisScript
	./$ThisScript 2>&1 | tee ${ThisScript/sh/log}

	=== CONFIGURED INSTALLATION ===

	su -
    	mkdir -p /hxdepots/reset
	cd /hxdepots/reset
	curl -k -s -O $HelixInstallerURL/src/$ThisScript
	chmod +x $ThisScript

 	### Generate a default config file:
	./$ThisScript -C > settings.cfg

 	### Edit settings.cfg, changing the values as desired:
	vi settings.cfg

	./$ThisScript -c settings.cfg 2>&1 | tee log.reset_sdp

	=== LOCAL INSTALL ===

	The following sample commands illustrate how to acquire the
	dependencies for running with '-local' on a machine that can reach
	the public internet.  The resulting file structure, with paths as
	shown, would need to be somehow copied to the machine where the
	this reset_sdp.sh script is to be run.  This can be used to
	facilitate operation on a machine over an \"air gap\" network.

	$ mkdir -p $BinDir
	$ cd $BinDir
	$ curl -k -s -O $FTPURL/$P4BinRel/bin.$ApiArch/p4
	$ curl -k -s -O $FTPURL/$P4BinRel/bin.$ApiArch/p4d
	$ curl -k -s -O $FTPURL/$P4BinRel/bin.$ApiArch/p4broker
	$ curl -k -s -O $FTPURL/$P4BinRel/bin.$ApiArch/p4p

	$ mkdir $DownloadsDir
	$ cd $DownloadsDir
	$ curl -k -s -O $FTPURL/tools/$SampleDepotTar
	$ curl -k -s -O $HelixInstallerTarURL
	$ tar -xzf ${HelixInstallerTarURL##*/}
	$ rsync -a hi/src $ResetHome

	=== SDP DEV BRANCH TESTING ===

	The Helix Installer can be used to test SDP changes shelved to the SDP
	dev branch in The Workshop.  The following example illustrates testing
	a change in shelved changelist 23123:

	su -
    	mkdir -p /hxdepots/reset
	cd /hxdepots/reset
	curl -k -s -O $HelixInstallerURL/src/reset_sdp.sh

	./reset_sdp.sh -b dev,@23123 2>&1 | tee log.reset_sdp.CL23123

	After the first test, an iterative test cycle may follow on the same
	shelved changelist. For each test iteration, the shelved changelist
	is first updated in the workspace from which the change was originally
	shelved, e.g. with a command like 'p4 shelve -f -c 23123'.

	Then a new test can be done by calling reset_sdp.sh with the same
	arguments. The script will re-install the SDP cleanly, and then
	re-apply the updated shelved changelist.

	=== SDP TEST SUITE SUPPORT ===

	The Helix Installer can install the SDP in the Docker-based SDP
	Test Suite.  In that environment, the directory /sdp appears on
	the test VMs, shared from the host machine.  To deploy that SDP,
	use the '-d <sdp_dir>' flag, something like this:

	./reset_sdp.sh -d /sdp -fast 2>&1 | tee log.reset_sdp.test

"
   fi

   exit 1
}

#------------------------------------------------------------------------------
# Functions msg(), dbg(), and bail().
# Sample Usage:
#    bail "Missing something important. Aborting."
#    bail "Aborting with exit code 3." 3
function msg () { echo -e "$*"; }
function warnmsg () { msg "\\nWarning: ${1:-Unknown Warning}\\n"; WarningCount+=1; }
function errmsg () { msg "\\nError: ${1:-Unknown Error}\\n"; ErrorCount+=1; }
function dbg () { msg "DEBUG: $*" >&2; }
function bail () { errmsg "${1:-Unknown Error}"; exit "${2:-1}"; }

#------------------------------------------------------------------------------
# Functions run($cmd, $desc)
#
# This function is similar to functions defined in SDP core libraries, but we
# need to duplicate them here since this script runs before the SDP is
# available on the machine (and we require dependencies for this
# script).
function run {
   cmd="${1:-echo Testing run}"
   desc="${2:-}"
   [[ -n "$desc" ]] && msg "$desc"
   msg "Running: $cmd"
   $cmd
   CMDEXITCODE=$?
   return $CMDEXITCODE
}

#------------------------------------------------------------------------------
# Function: gen_default_config()
#
# This generates a sample configuration settings file. Output is generated to
# stdout, making it easy for external automation to modify. By convention,
# output is generated to a file named settings.cfg, e.g. with '-C settings.cfg'
# flag with output redirected to that file.
#
# The sample file contains all required settings and reasonable sample values.
# The in-code documentation describes how the settings are used.  Settings
# are enumerated in the Config and ConfigDoc associative arrays, with the
# index of the arrays being the setting name.  For example, if the setting
# is ServerID, it can be referenced as ${Config['ServerID']}.
#
# The sections of the file are delineated by comments, with an description of
# what type of settings are in each section. The sections are Section 1:
# Localization, Section 2: Data Specific, and Section 3: Deep Customization.
# A hand-crafted 'for' loop in each section indicates what section any given
# setting belongs in.
#
# Generate a sample settings.cfg file.
function gen_default_config {
   echo -e "\
#------------------------------------------------------------------------------
# Config file for $ThisScript v$Version.
#------------------------------------------------------------------------------
# This file is in bash shell script syntax.
# Note: Avoid spaces before and after the '=' sign.

# For demo and training installations, usually all defaults in this file
# are fine.

# For Proof of Concept (PoC) installation, Section 1 (Localization) settings
# should all be changed to local values. Some settings in Section 2 (Data
# Specific) might also be changed.

# Changing settings in Section 3 (Deep Customization) is generally
# discouraged unless necessary when bootstrapping a production installation or
# a high-realism PoC.

#------------------------------------------------------------------------------
# Section 1: Localization
#------------------------------------------------------------------------------
# Changing all these is typical and expected, even for PoC installations."

   for c in SMTPServer P4AdminList MailFrom DNS_name_of_master_server SiteTag Hostname Timezone; do
      echo -e "${ConfigDoc[$c]}"
      echo "$c=${Config[$c]}"
   done

echo -e "
#------------------------------------------------------------------------------
# Section 2: Data Specific
#------------------------------------------------------------------------------
# These settings can be changed to desired values, though default values are
# preferred for demo installations."

   for c in P4_PORT P4BROKER_PORT Instance CaseSensitive P4USER Password SimulateEmail ServerID ServerType TargetServerID TargetPort ListenPort; do
      echo -e "${ConfigDoc[$c]}"
      echo "$c=${Config[$c]}"
   done

echo -e "
#------------------------------------------------------------------------------
# Section 3: Deep Customization
#------------------------------------------------------------------------------
# Changing these settings is gently discouraged, but may be necessary for
# bootstrapping some production environments with hard-to-change default values
# for settings such as OSUSER, OSGROUP, Hx*, etc.
#
# Changing these settings is gently discouraged because changing these values
# will cause the configuration to be out of alignment with documentation and
# sample instructions for settings that are typically left as defaults.
# However, there are no functional limitations to changing these settings."

   for c in OSUSER OSGROUP OSUSER_ADDITIONAL_GROUPS OSUSER_HOME P4BinRel P4APIRel; do
      echo -e "${ConfigDoc[$c]}"
      echo "$c=${Config[$c]}"
   done

echo -e "
# The following Hx* settings reference directories that store Perforce
# Helix data.  If configuring for optimal performance and scalability,
# these folders can be mount points for storage volumes.  If so, they must
# be mounted prior to running the $ThisScript script (other than to generate
# this configuration file).
#
# See the Server Deployment Package (SDP) for information and guidance on
# provisioning these volumes."

   for c in HxDepots HxLogs; do
      echo -e "${ConfigDoc[$c]}"
      echo "$c=${Config[$c]}"
   done

   # Special case: The ConfigDoc for HxMetadata1 applies to both HxMetadata1
   # and HxMetadata2 settings, so display it only once.
   echo -e "${ConfigDoc['HxMetadata1']}"
   echo "HxMetadata1=${Config['HxMetadata1']}"
   echo "HxMetadata2=${Config['HxMetadata2']}"
}

#==============================================================================
# Command Line Processing

declare -i shiftArgs=0
set +u

while [[ $# -gt 0 ]]; do
   case $1 in
      (-B) BlastDownloadsAndBinaries=1;;
      (-local) PullFromWebAsNeeded=0;;
      (-no_ssl) UseSSL=0;;
      (-no_cron) InstallCrontab=0;;
      (-no_ppr) AddPerforcePackageRepo=0;;
      (-no_systemd) UseSystemd=0; UseSystemdOption="-no_systemd";;
      (-no_firewall) DoFirewall=0;;
      (-no_tweaks) RunOSTweaks=0;;
      (-no_sudo) DoSudo=0;;
      (-ls) LimitedSudoers=1;;
      (-v) DoSDPVerify=1;;
      (-fast) UpdatePackages=0;;
      (-dapi) InstallDerivedAPIs=1;;
      (-s) ServerID="$2"; SetServerID=1; shiftArgs=1;;
      (-t) ServerType="$2"; SetServerType=1; shiftArgs=1;;
      (-ts) TargetServerID="$2"; SetTargetServerID=1; shiftArgs=1;;
      (-tp) TargetPort="$2"; SetTargetPort=1; shiftArgs=1;;
      (-lp) ListenPort="$2"; SetListenPort=1; shiftArgs=1;;
      (-se) SimulateEmail=1; SetSimulateEmail=1;;
      (-H) Hostname="$2"; SetHostname=1; shiftArgs=1;;
      (-T) Timezone="$2"; SetTimezone=1; shiftArgs=1;;
      (-C) GenDefaultConfig=1;;
      (-c) ConfigFile="$2"; UseConfigFile=1; shiftArgs=1;;
      (-d)
         SDPInstallMethod=Copy
         [[ "$2" == "default" ]] || SDPCopyDir="$2"
         shiftArgs=1
      ;;
      (-b)
         # If we are pulling from main and not using the ',@' sytnax,
         # stick with tarball installation. Otherwise, switch to cloning
         # from the specified branch (typically dev).
         if [[ "$2" == *",@"* ]]; then
            SDPInstallMethod=DVCS
            SDPInstallBranch=${2%%,@*};
            ShelvedChange=${2##*,@}
         else
            SDPInstallBranch=$2;
            [[ "$SDPInstallBranch" == "main" ]] || SDPInstallMethod=DVCS
         fi
         shiftArgs=1
      ;;
      (-p) PreserveDirList=$2; shiftArgs=1;;
      (-h) usage -h;;
      (-man|--help) usage -man;;
      (-D) set -x;; # Debug; use 'set -x' mode.
      (-X) ExtremeCleanup=1;;
      (-R) ExtremeCleanup=1; StopAfterReset=1;;
      (-M) MultiRun=1;;
      (-i) HelixInstallerBranch="$2"; shiftArgs=1;;
      (*) bail "Usage Error: Unknown arg ($1).";;
   esac

   # Shift (modify $#) the appropriate number of times.
   shift; while [[ $shiftArgs -gt 0 ]]; do
      [[ $# -eq 0 ]] && bail "Usage Error: Wrong number of args or flags to args."
      shiftArgs=$shiftArgs-1
      shift
   done
done
set -u

#------------------------------------------------------------------------------
# Command Line Validation

[[ "$UseConfigFile" -eq 1 && "$GenDefaultConfig" -eq 1 ]] && \
   bail "The '-c <cfg>' and '-C' options are mutually exclusive."

[[ "$InstallDerivedAPIs" -eq 1 && "$UpdatePackages" -eq 0 ]] && \
   bail "The '-fast' and '-dapi' options are mutually exclusive."

[[ "$DoSudo" -eq 0 && "$LimitedSudoers" -eq 1 ]] && \
   bail "The '-no_sudo' and '-ls' options are mutually exclusive."

#------------------------------------------------------------------------------
# Main Program

ThisUser="$(whoami)"
ThisOS="$(uname -s)"
ThisArch="$(uname -m)"
ThisHost="$(hostname -s)"

#------------------------------------------------------------------------------
# Special Mode:  Generate Default Config File
# In this mode, generate a sample config file on stdout, and exit.

if [[ "$GenDefaultConfig" -eq 1 ]]; then
   gen_default_config
   exit 0
fi

#------------------------------------------------------------------------------
# Regular processing mode.

msg "Started $ThisScript v$Version on host $ThisHost as user $ThisUser at $(date), called as:\\n\\t$CmdLine"

if [[ "$UseConfigFile" -eq 1 ]]; then
   [[ -r "$ConfigFile" ]] || \
      bail "Config file specified with '-c $ConfigFile' is not readable."

   msg "Loading configuration data from $ConfigFile."
   for c in "${!Config[@]}"; do
      value=$(grep ^$c= "$ConfigFile")
      value="${value#*=}"
      Config[$c]="$value"
   done
   SDPInstances="${Config['Instance']}"
   RunGroup="${Config['OSGROUP']}"
   RunUserNewHomeDir="${Config['OSUSER_HOME']}"
else
   # We want to know whether RunGroup was set explicitly in the settings.cfg
   # file or not.  If not, we set it to the value of 'Unset', enabling
   # OS-dependent logic to below to supply a platform-specific default.
   # We don't want platform-specific defaults to override values explicitly
   # defined in settings.cfg if that is used.
   RunGroup=Unset

   # Similarly, we want to apply the home directory specified in account
   # creation if it was defined in settings.cfg, but not otherwise.
   RunUserNewHomeDir=Unset
fi

# After the configuration data is loaded, set variables that depend on
# the loaded configuration.
SDPDefaultInstance="${SDPInstances%% *}"
RunUser="${Config['OSUSER']}"
SudoersFile="/etc/sudoers.d/$RunUser"
SudoersDir="${SudoersFile%/*}"
LimitedSudoersTemplate="$ResetHome/perforce_sudoers.t"

HxDepots="${Config['HxDepots']}"
HxMetadata1="${Config['HxMetadata1']}"
HxMetadata2="${Config['HxMetadata2']}"
HxLogs="${Config['HxLogs']}"

# Trim the leading '/' from Hx* settings to be compatible with SDP mkdirs.cfg
HxDepots="${HxDepots#/}"
HxMetadata1="${HxMetadata1#/}"
HxMetadata2="${HxMetadata2#/}"
HxLogs="${HxLogs#/}"

BinDir="/$HxDepots/helix_binaries"
DownloadsDir="/$HxDepots/downloads"
ResetHome="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SDPHome="/$HxDepots/sdp"
SSLDir="/p4/ssl"
SSLConfig="$SSLDir/config.txt"
SDPSetupDir="$SDPHome/Server/Unix/setup"
SDPCrontabDir="$SDPHome/Server/Unix/p4/common/etc/cron.d"
OSTweaksScript="$SDPSetupDir/os_tweaks.sh"
SudoersEntry="$RunUser ALL=(ALL) NOPASSWD: ALL"

#------------------------------------------------------------------------------
# Command Line Overrides
# Configuration settings in this block have corresponding command options.
# Settings from the config file will be overridden if their corresponding
# command line options is set. So if '-t <ServerID>' is given on the command
# line, the ServerID setting from the config file is ignored.
[[ "$SetHostname" -eq 0 ]] && Hostname="${Config['Hostname']}"
[[ "$SetTimezone" -eq 0 ]] && Timezone="${Config['Timezone']}"
[[ "$SetServerID" -eq 0 ]] && ServerID="${Config['ServerID']}"
[[ "$SetServerType" -eq 0 ]] && ServerType="${Config['ServerType']}"
[[ "$SetSimulateEmail" -eq 0 ]] && SimulateEmail="${Config['SimulateEmail']}"
[[ "$SetListenPort" -eq 0 ]] && ListenPort="${Config['ListenPort']}"
[[ "$SetTargetPort" -eq 0 ]] && TargetPort="${Config['TargetPort']}"
[[ "$SetTargetServerID" -eq 0 ]] && TargetServerID="${Config['TargetServerID']}"
#------------------------------------------------------------------------------

# Do some data validations based on data loaded from the configuration file.
if [[ "$UseConfigFile" -eq 1 ]]; then
   msg "Doing sanity checks on data loaded from the config file."

   if [[ "$ServerType" != "p4d_master" ]]; then
      if [[ -z "$ServerID" ]]; then
         if [[ "$ServerType" == "p4broker" || "$ServerType" = "p4proxy" ]]; then
            ServerID="$ServerType"
	    msg "No ServerID defined for server of type $ServerType. Defaulting to $ServerType as the ServerID."
	 else
            errmsg "ServerID is not set. ServerID must be set if ServerType is any p4d_* type other than p4d_master. ServerType is [$ServerType]."
         fi
      fi
   fi

   if [[ -n "$TargetServerID" ]]; then
      [[ "$ServerType" != "p4d_edge_replica" ]] && \
         errmsg "TargetServerID is set (to $TargetServerID), but ServerType is not p4d_edge_replica. TargetServerID can only be set when ServerType is p4d_edge_replica. ServerType [$ServerType]."
   fi

   if [[ "$ErrorCount" -eq 0 ]]; then
      msg "Config file data passed sanity checks."
   else
      bail "Config file data failed sanity checks. Aborting."
   fi
fi

# Valid ServerType.  Based on ServerType, determine binary and services to
# install.
case "$ServerType" in
   (p4d_master)
      BinList="p4d p4broker"
      UseBroker=1
   ;;
   (p4d_replica)
      BinList="p4d p4broker"
      UseBroker=1
   ;;
   (p4d_filtered_replica)
      BinList="p4d p4broker"
      UseBroker=1
   ;;
   (p4d_edge)
      BinList="p4d p4broker"
      UseBroker=1
   ;;
   (p4d_edge_replica)
      BinList="p4d p4broker"
      UseBroker=1
   ;;
   (p4broker)
      BinList="p4broker"
      UseBroker=1
   ;;
   (p4proxy)
      BinList="p4p"
      UseBroker=0
   ;;
   (*)
      bail "Invalid ServerType specified [$ServerType]. Run $ThisScript -man to see valid values."
   ;;
esac

# Set the ServerBin to the server binary that will be used to create SSL
# certificates. Use whichever server is available based on the server
# type to be installed; it can be p4d, p4p, or p4broker (but not the 'p4'
# client binary).
ServerBin="/p4/${SDPDefaultInstance}/bin/${BinList%% *}_${SDPDefaultInstance}"

# Get just enough detailed OS info in order to fill in
# details in the Perforce package repository files.
if [[ "$ThisOS" == "Linux" ]]; then
   if [[ -r "/etc/redhat-release" ]]; then
      if grep -q ' 6\.' /etc/redhat-release; then
         ThisOSMajorVersion="6"
      elif grep -q ' 7\.' /etc/redhat-release; then
         ThisOSMajorVersion="7"
      elif grep -q ' 8\.' /etc/redhat-release; then
         ThisOSMajorVersion="8"
      fi
      [[ -n "$ThisOSMajorVersion" ]] || \
         warnmsg "Could not determine OS Major Version from contents of /etc/redhat-release."
   elif [[ -r "/etc/lsb-release" ]]; then
      ThisOSName=$(grep ^DISTRIB_ID= /etc/lsb-release)
      ThisOSName=${ThisOSName#*=}
      ThisOSName=${ThisOSName,,}
      ThisOSDistro=$(grep ^DISTRIB_CODENAME= /etc/lsb-release)
      ThisOSDistro=${ThisOSDistro#*=}

      [[ -n "$ThisOSName" && -n "$ThisOSDistro" ]] || \
         warnmsg "Could not determine OS Name and Distro from contents of /etc/lsb-release."
   fi

   if [[ -r "/etc/firewalld/services" ]]; then
      FirewallType="Firewalld"
      FirewallDir="/etc/firewalld/services"
   elif [[ -r "/etc/sysconfig/iptables" ]]; then
      FirewallType="IPTables"
      FirewallDir="/etc/sysconfig"
   fi
fi

if [[ "$ThisUser" != root ]]; then
   bail "Run as root, not $ThisUser."
else
   msg "Verified: Running as root user."
fi

[[ "$BlastDownloadsAndBinaries" -eq 1 && "$PullFromWebAsNeeded" -eq 0 ]] && \
   bail "The '-B' and '-local' arguments are mutually exclusive."

[[ "$SDPInstallBranch" != "Unset" && "$SDPInstallMethod" == "Copy" ]] && \
   bail "The '-b <branch>' and '-d <sdp_dir>' arguments are mutually exclusive."

[[ "$SDPInstallBranch" == Unset ]] && SDPInstallBranch=main

HelixInstallerURL="$HelixInstallerBaseURL/$HelixInstallerBranch"

#------------------------------------------------------------------------------
# Determine Init Mechanism
if [[ "$UseSystemd" -eq 1 && -d "/etc/systemd/system" ]]; then
   InitMechanism="Systemd"

   if [[ -z "$(command -v systemctl)" ]]; then
      warnmsg "systemctl isn't in PATH, bug /etc/systemd/system exists. Acting as if '-no_systemd' was specified."
      UseSystemd=0
   fi
elif [[ -x "/sbin/launchd" ]]; then
   InitMechanism="Launchd"
   UseSystemd=0
elif [[ -d "/etc/init.d" ]]; then
   InitMechanism="SysV"
   UseSystemd=0
else
   bail "Could not determine init mechanism. Systemd, SysV, and Launchd aren't available. Aborting."
fi

#------------------------------------------------------------------------------
# Self-update

cd "$ResetHome" || bail "Could not cd to $ResetHome. Aborting."

msg "\\nEnsuring Helix Installer files are available."

for f in $HelixInstallerFiles; do
   HelixInstallerFileURL="$HelixInstallerURL/src/$f"
   if [[ ! -f "$f" ]]; then
      [[ "$PullFromWebAsNeeded" -eq 0 ]] && \
         bail "Missing Helix Installer file [$f] and '-local' specified. Aborting."
      run "curl -k -s -O $HelixInstallerFileURL" "Getting file $f." ||\
         bail "Failed to download from [$HelixInstallerFileURL]. Aborting."
   else
      if [[ "$BlastDownloadsAndBinaries" -eq 1 ]]; then
         run "curl -k -s -O $HelixInstallerFileURL" \
            "Replacing Helix Installer file $f due to '-B'." ||\
            bail "Failed to download file [$PWD/$f]. Aborting."
      else
         msg "Using existing Helix Installer file $PWD/$f."
      fi
   fi

   if [[ ! -x "$f" ]]; then
      if [[ "$f" == *".sh" || "$f" == r ]]; then
         run "chmod +x $f" "chmod +x $f" || bail "Failed to do: chmod +x $f. Aborting."
      fi
   fi
done

# After the self-update, if '-ls' (Limited Sudo) was specified, ensure the
# Limited Sudoers Template file is available.
[[ "$LimitedSudoers" -eq 1 && ! -r "$LimitedSudoersTemplate" ]] && \
   bail "Missing Sudoers template file: $LimitedSudoersTemplate"

#------------------------------------------------------------------------------
# Blast key directories if '-B' was specified.
if [[ "$BlastDownloadsAndBinaries" -eq 1 ]]; then
   if [[ -d "$BinDir" ]]; then
      run "/bin/rm -rf $BinDir" \
         "Blasting helix_binaries dir [$BinDir] due to '-B'." ||\
          warnmsg "Failed to blast helix_binaries dir."

      for d in /tmp/downloads /tmp/p4perl; do
         if [[ -d "$d" ]]; then
            run "/bin/rm -rf $d" \
               "Blasting $d dir due to '-B'." ||\
                warnmsg "Failed to blast dir $d."
         fi
      done
   fi

   if [[ -d "$DownloadsDir" ]]; then
      run "/bin/rm -r -f $DownloadsDir" \
         "Blasting downloads dir [$DownloadsDir] due to '-B'."
   fi

   run "/bin/rm -rf $SDPHome $SSLDir" \
      "Blasting old SDP Home and SSL dir due to '-B'." ||\
      bail "Failed to remove old $SDPHome and $SSLDir."
fi

#------------------------------------------------------------------------------
# Extreme Cleanup with -X
if [[ "$ExtremeCleanup" -eq 1 ]]; then
   msg "\\nStarted Extreme Cleanup due to -X."
   if id -u "$RunUser" > /dev/null 2>&1; then
      RunUserHomeDir="$(eval echo ~"$RunUser")"
      if run "pkill -9 -u $RunUser" "Blasting processes by OS user $RunUser."; then
         msg "Verified: No processes for user $RunUser are running."
      else
         if [[ "$(pgrep -u "$RunUser" -c)" == "0" ]]; then
            msg "Verified: No processes for user $RunUser were running."
         else
            warnmsg "Failed to blast all processes by OS user $RunUser."
         fi
      fi

      sleep 1
      run "userdel $RunUser" "Removing OS user $RunUser." ||\
         warnmsg "Failed to remove OS user $RunUser."

      run "/bin/rm -rf $RunUserHomeDir" "Removing home dir $RunUserHomeDir" ||\
         warnmsg "Failed to remove $RunUserHomeDir."
   else
      msg "Extreme Cleanup: OS User $RunUser does not exist."
   fi

   if [[ "$DoSudo" -eq 1 ]]; then
      if [[ -f "$SudoersFile" ]]; then
         run "/bin/rm -f $SudoersFile" \
            "Extreme Cleanup: Removing sudoers file: $SudoersFile" ||\
            warnmsg "Failed to remove $SudoersFile."
      fi
   else
      msg "Skipping sudo cleanup due to '-no_sudo'."
   fi

   if [[ "$HxMetadata1" == "$HxMetadata2" ]]; then
      run "/bin/rm -rf /p4 /$HxDepots/p4 /$HxMetadata1/p4 /$HxLogs/p4" \
         "Extreme Cleanup: Blasting several SDP dirs." ||\
         warnmsg "Failed to blast some SDP dirs."
   else
      run "/bin/rm -rf /p4 /$HxDepots/p4 /$HxMetadata1/p4 /$HxMetadata2/p4 /$HxLogs/p4" \
         "Extreme Cleanup: Blasting several SDP dirs." ||\
         warnmsg "Failed to blast some SDP dirs."
   fi

   if [[ "$DoFirewall" -eq 1 ]]; then
      if [[ "$FirewallType" == "Firewalld" ]]; then
         cd "$FirewallDir" || bail "Could not cd to: $FirewallDir"
         msg "Extreme Cleanup: Removing p4*.xml firewall rules (if any).\\n"
         for svcFile in p4*.xml; do
            [[ -r "$svcFile" ]] || continue
            svcName="${svcFile%.xml}"
            run "firewall-cmd --permanent --delete-service=$svcName" \
               "Deleting firewall entry for $svcName" ||\
               warnmsg "Deleting firewall entry for $svcName failed."

            # Firewalld renames the *.xml files to *.xml.old upon deletion of the
            # rule.
            if [[ -r "$PWD/${svcFile}.old" ]]; then
               run "rm -f $PWD/${svcFile}.old" "Removing $PWD/${svcFile}.old" ||\
                  warnmsg "Deleting file $PWD/${svcFile}.old failed."
            fi
         done
         run "firewall-cmd --reload" "Firewall reload after cleanup." ||\
            warnmsg "Firewall reload failed after cleanup."
      fi
   else
      msg "Skipping firewall cleanup due to '-no_firewall'."
   fi

   if [[ "$InitMechanism" == "SysV" ]]; then
      cd /etc/init.d || bail "Could not cd to /etc/init.d."

      msg "Removing Perforce-related SysV services in $PWD."

      for svc in p4*_init; do
         [[ "$svc" == "p4*_init" ]] && break
         run "chkconfig --del $svc"
         run "rm -f $svc"
      done
   elif [[ "$InitMechanism" == "Systemd" && "$UseSystemd" -eq 1 ]]; then
      cd /etc/systemd/system || bail "Could not cd to /etc/systemd/system."

      msg "Disabling and removing Perforce-related Systemd services in $PWD."
      for svcFile in p4*.service; do
         [[ "$svcFile" == "p4*.service" ]] && break
         run "systemctl disable ${svcFile%.service}"
         run "rm -f $svcFile"
      done
      run "systemctl daemon-reload" "Reloading systemd after removing Systemd unit files." ||\
         warnmsg "Failed to reload systemd daemon."
   fi

   if [[ "$StopAfterReset" -eq 0 ]]; then
      msg "Extreme Cleanup complete. Continuing.\\n"
   else
      msg "Extreme Cleanup complete. Stopping.\\n"
      exit 0
   fi
fi

#------------------------------------------------------------------------------
# Digital asset acquisition and availability checks.
[[ ! -d "/$HxDepots" ]] && run "/bin/mkdir -p /$HxDepots"

cd "/$HxDepots" || bail "Could not cd to [/$HxDepots]."

if command -v yum > /dev/null; then
   PackageManager="yum"
elif command -v apt-get > /dev/null; then
   PackageManager="apt-get"
elif command -v zypper > /dev/null; then
   PackageManager="zypper"
else
   UpdatePackages=0
fi

#------------------------------------------------------------------------------
# Set hostname and timezone.
if [[ -n "$Hostname" ]]; then
   if command -v hostnamectl > /dev/null; then
      if hostnamectl set-hostname "$Hostname"; then
         msg "Hostname set to $(hostname); short hostname is $(hostname -s)."
      else
         errmsg "Failed to set hostname with: hostnamectl set-hostname $Hostname";
      fi
   else
      errmsg "Not setting hostname due to lack of 'hostnamectl' utility."
   fi
fi

if [[ -n "$Timezone" ]]; then
   if command -v timedatectl > /dev/null; then
      if timedatectl set-timezone "$Timezone"; then
         msg "Timezone is set. Date is: $(date)"
      else
         errmsg "Failed to set timezone with: timedatectl set-timezone $Timezone";
      fi
   else
      errmsg "Not settting timezone due to lack of 'timedatectl' utility."
   fi
fi

#------------------------------------------------------------------------------
# Update OS Packages
if [[ "$UpdatePackages" -eq 1 ]]; then
   msg "Ensuring needed packages are installed."

   if [[ "$ThisOS" != "Darwin" ]]; then
      [[ "$PackageManager" == "Unset" ]] && \
         bail "Could not find one of these package managers: ${!PackageList[*]}"

      run "$PackageManager install -y ${PackageList[$PackageManager]}" \
         "Installing these packages with $PackageManager: ${PackageList[$PackageManager]}" ||\
         warnmsg "Not all packages installed successfully.  Proceeding."

      if [[ "$InstallDerivedAPIs" -eq 1 ]]; then
         if ! command -v gcc > /dev/null || ! command -v g++ > /dev/null; then
            msg "Warning: No gcc found in the path.  You may need to install it.  Please\\n check that the gcc and gcc-c++ packages are\\n installed, e.g. with:\\n\\t$PackageManager install -y gcc gcc-c++\\nIgnoring missing gcc/g++ due to '-fast'.\\n"
         else
            msg "Verified: gcc and g++ are available and in the PATH."
         fi
      fi
   else
      warnmsg "Skipping package handling on Mac OSX/$ThisOS."
      UpdatePackages=0
   fi
fi

if [[ "$PullFromWebAsNeeded" -eq 1 ]]; then
   if ! command -v curl > /dev/null; then
      bail "No 'curl' found in the path.  You may need to install it or adjust the PATH for the root user to find it.\\n\\n"
   fi
fi

if ! command -v su > /dev/null; then
   bail "No 'su' found in the path.  You may need to install it or adjust the PATH for the root user to find it.\\n\\n"
fi

if [[ "$ThisArch" == "$RunArch" ]]; then
   msg "Verified:  Running on a supported architecture [$ThisArch]."
   ApiArch=UNDEFINED_API_ARCH
   case $ThisOS in
      (Darwin)
         ApiArch="macosx1010x86_64"
         [[ "$RunGroup" == Unset ]] && RunGroup=staff
         SampleDepotTar=sampledepot.mac.tar.gz
      ;;
      (Linux)
         ApiArch="linux26x86_64"
         # Set a platform-specific value for RunGroup if it wasn't defined
         # explicitly in a settings.cfg file.
         if [[ "$RunGroup" == Unset ]]; then
            if [[ -r "/etc/SuSE-release" ]]; then
               RunGroup=users
            else
               # CentOS, RHEL, and Ubuntu default group is same as user name.
               RunGroup=perforce
            fi
         fi
         SampleDepotTar=sampledepot.tar.gz
      ;;
      (*) bail "Unsupported value returned by 'uname -m': $ThisOS. Aborting.";;
   esac
else
   bail "Running on architecture $ThisArch.  Run this only on hosts with '$RunArch' architecture. Aborting."
fi

# In this block, we just check that directories specified to be preserved
# with the '-p' flag actually exist, in which case we abort before further
# processing.
if [[ "$PreserveDirList" != Unset ]]; then
   for d in $(echo "$PreserveDirList" | tr ',' ' '); do
      preserveDir="/$HxDepots/p4/common/$d"
      if [[ -d "$preserveDir" ]]; then
         parentDir=$(dirname "$TmpDir/$d")
         if [[ ! -d "$parentDir" ]]; then
            run "/bin/mkdir -p $parentDir" "Creating parent temp dir [$parentDir]." ||\
               bail "Failed to create parent temp dir [$parentDir]."
         fi
      fi
   done
fi

if [[ ! -d "$BinDir" ]]; then
   [[ "$PullFromWebAsNeeded" -eq 0 ]] && bail "BinDir [$BinDir] is missing and '-local' specified. Aborting."
   run "/bin/mkdir -p $BinDir" ||\
      bail "Could not create dir [$BinDir]."

   cd "$BinDir" || bail "Could not cd to $BinDir."
   msg "Working in [$PWD]."
   run "curl -k -s -O $FTPURL/${Config['P4BinRel']}/bin.$ApiArch/p4" ||\
      bail "Could not get 'p4' binary."
   run "curl -k -s -O $FTPURL/${Config['P4BinRel']}/bin.$ApiArch/p4d" ||\
      bail "Could not get 'p4d' binary."
   run "curl -k -s -O $FTPURL/${Config['P4BinRel']}/bin.$ApiArch/p4p" ||\
      bail "Could not get 'p4p' binary."
   run "curl -k -s -O $FTPURL/${Config['P4BinRel']}/bin.$ApiArch/p4broker" ||\
      bail "Could not get 'p4broker' binary."

   run "chmod +x p4 p4d p4p p4broker" \
      "Doing chmod +x for downloaded Helix binaries."
else
   msg "Using existing helix_binaries dir [$BinDir]."
fi

#------------------------------------------------------------------------------
# Services Shutdown and Cleanup.

if command -v getent > /dev/null; then
   if getent group "$RunGroup" > /dev/null 2>&1; then
      msg "Verified: Group $RunGroup exists."
   else
      run "groupadd $RunGroup" "Creating group $RunGroup." ||\
         bail "Failed to create group $RunGroup."
   fi
fi

if id -u "$RunUser" > /dev/null 2>&1; then
   msg "Verified: User $RunUser exists."
else
   if command -v useradd > /dev/null; then
      UserAddCmd="useradd -s /bin/bash -g $RunGroup"

      # Specify the home dir only if explicitly defined in settings.cfg;
      # otherwise defer to the useradd default.
      [[ "$RunUserNewHomeDir" != Unset ]] && \
         UserAddCmd+=" -d $RunUserNewHomeDir"

      # Specify the -G value to useradd if and only if values for additional
      # groups were defined in settings.cfg.
      [[ -n "${Config['OSUSER_ADDITIONAL_GROUPS']}" ]] && \
         UserAddCmd+=" -G ${Config['OSUSER_ADDITIONAL_GROUPS']}"

      UserAddCmd+=" $RunUser"
      run "$UserAddCmd" "Creating user $RunUser with command: $UserAddCmd" ||\
         bail "Failed to create user $RunUser."

      msg "Setting OS password for user $RunUser."
      echo "${Config['Password']}" > "$TmpFile"
      echo "${Config['Password']}" >> "$TmpFile"
      msg "Running: passwd $RunUser"
      if passwd "$RunUser" < "$TmpFile"; then
         msg "Verified: Password for user $RunUser set successfully."
      else
         warnmsg "Failed to set password for user $RunUser."
      fi

      RunUserHomeDir="$(eval echo ~"$RunUser")"
      if [[ -d "$RunUserHomeDir" ]]; then
         msg "Verified: Home directory for user $RunUser exists."
      else
         run "mkdir -p $RunUserHomeDir" \
            "Creating home dir for $RunUser" ||\
            bail "Failed to create home directory $RunUserHomeDir for OS user $RunUser."
         run "chown -R $RunUser:$RunGroup $RunUserHomeDir" \
            "Ensuring $RunUser owns home dir $RunUserHomeDir." ||\
            warnmsg "Failed to change ownership of home directory $RunUserHomeDir for OS user $RunUser."
      fi

      run "cp $ResetHome/perforce_bash_profile $RunUserHomeDir/.bash_profile" \
         "Creating $RunUserHomeDir/.bash_profile." ||\
         warnmsg "Failed to copy to $RunUserHomeDir/.bash_profile."

      msg "Creating $RunUserHomeDir/.bashrc."
      sed "s:EDITME_SDP_INSTANCE:$SDPDefaultInstance:g" \
         "$ResetHome/perforce_bashrc" > "$RunUserHomeDir/.bashrc" ||\
         warnmsg "Failed to copy to $RunUserHomeDir/.bashrc."

      run "chown $RunUser:$RunGroup $(eval echo ~"$RunUser")/.bash_profile $(eval echo ~"$RunUser")/.bashrc" "Adjusting perms of .bash_profile and .bashrc." ||\
         warnmsg "Adjusting ownership failed."
   else
      bail "User $RunUser does not exist, and the 'useradd' utility was not found."
   fi
fi

for i in $SDPInstances; do
   if [[ "$ThisOS" == "Linux" || "$ThisOS" == "Darwin" ]]; then
      msg "Stopping Perforce-related services for Instance $i."
      for svc in p4d p4broker p4p p4web p4dtg; do
         processCmd="${svc}_${i}"

         # This 'ps' command should work on Linux and Mac (Yosemite+ at least).
         # shellcheck disable=SC2009
         Pids=$(ps -u "$RunUser" -f | grep -v grep | grep "/$processCmd "| awk '{print $2}')

         if [[ -z "$Pids" && $svc == p4d ]]; then
            msg "$processCmd not found for p4d service; looking for _bin variant instead."
            # For the p4d service, the process command may look like 'p4d_1_bin' or just 'p4d_1', so
            # we check for both.
            processCmd="${svc}_${i}_bin"
            # shellcheck disable=SC2009
            Pids=$(ps -u "$RunUser" -f | grep -v grep | grep "/$processCmd "| awk '{print $2}')
         fi

         if [[ -n "$Pids" ]]; then
            run "kill -9 $Pids" \
               "Killing user $RunUser processes for command $processCmd."
            sleep 1
         else
            msg "Verified: No processes by user $RunUser for command [$processCmd] are running."
         fi
      done
   fi
done

#------------------------------------------------------------------------------
if [[ ! -d "$DownloadsDir" ]]; then
   [[ $PullFromWebAsNeeded -eq 0 ]] && bail "DownloadsDir [$DownloadsDir] is missing and '-local' specified. Aborting."
   run "/bin/mkdir -p $DownloadsDir"

   cd "$DownloadsDir" || bail "Could not cd to downloads dir: $DownloadsDir"

   msg "Working in [$PWD]."
   if [[ "$InstallDerivedAPIs" -eq 1 ]]; then
      run "curl -k -s -O $FTPURL/${Config['P4APIRel']}/bin.$ApiArch/p4api.tgz" ||\
         bail "Could not get file 'p4api.tgz'"
   else
      msg "Skipping download of p4api.tgz '-dapi' not being specified."
   fi

   if [[ "$SDPInstallMethod" == FTP ]]; then
      run "curl -k -s -O $SDPURL" ||\
         bail "Could not get SDP tar file from [$SDPURL]."
   fi
else
   msg "Using existing downloads dir [$DownloadsDir]."

   cd "$DownloadsDir" || bail "Could not cd to downloads dir: $DownloadsDir"

   if [[ "$SDPInstallMethod" == FTP ]]; then
      if [[ -r "$SDPTar" ]]; then
         msg "Using existing SDP tarfile [$SDPTar]."
      else
         run "curl -k -s -O $SDPURL" ||\
            bail "Could not get SDP tar file from [$SDPURL]."
      fi
   fi
fi

#------------------------------------------------------------------------------
# Cleanup
cd "/$HxDepots" || bail "Could not cd to [/$HxDepots]. Aborting."

msg "Working in [$PWD]."

if [[ "$HxMetadata1" == "$HxMetadata2" ]]; then
   DirList="/$HxMetadata1 /$HxLogs";
else
   DirList="/$HxMetadata1 /$HxMetadata2 /$HxLogs";
fi

for d in $DirList; do
   if [[ ! -d "$d" ]]; then
      run "/bin/mkdir -p $d" "Initialized empty dir [$d]." ||\
         bail "Failed to create dir [$d]."
   else
      msg "Verified: Dir [$d] exists."
   fi
done

if [[ $PreserveDirList != Unset ]]; then
   run "/bin/mkdir -p $TmpDir" "Creating temp dir [$TmpDir]." ||\
      bail "Failed to create temp dir [$TmpDir]."

   for d in $(echo "$PreserveDirList" | tr ',' ' '); do
      preserveDir="/$HxDepots/p4/common/$d"
      if [[ -d "$preserveDir" ]]; then
         parentDir=$(dirname "$TmpDir/$d")
         if [[ ! -d "$parentDir" ]]; then
            run "/bin/mkdir -p $parentDir" "Creating parent temp dir [$parentDir]." ||\
               bail "Failed to create parent temp dir [$parentDir]."
         fi

         run "/bin/mv $preserveDir $TmpDir/$d" \
            "Moving preserved dir $preserveDir aside for safe keeping."
      else
         bail "Missing expected preserve dir [$preserveDir]. Check that paths specified with '-p' are relative to /$HxDepots/p4/common."
      fi
   done
fi

#------------------------------------------------------------------------------
# SDP Setup
if [[ "$SDPInstallMethod" == FTP ]]; then
   run "tar -xzpf $DownloadsDir/$SDPTar" "Unpacking $DownloadsDir/$SDPTar in $PWD." ||\
      bail "Failed to untar SDP tarfile."
elif [[ "$SDPInstallMethod" == Copy ]]; then
   if [[ -r "$SDPCopyDir/$SDPTar" ]]; then
      if [[ -d "$SDPHome" ]]; then
         run "rm -rf $SDPHome/" \
            "Removing existing SDP directory [$SDPHome]." ||\
            bail "Failed to clean existing SDPHome dir: $SDPHome"
      fi
     
      cd "${SDPHome%/*}" ||\
         bail "Could not cd to parent of SDPHome dir: ${SDPHome%/*}"

      run "tar -xzf $SDPCopyDir/$SDPTar" \
         "Extracting SDP tarball: $SDPCopyDir/$SDPTar" ||\
         bail "Failed to extract SDP tarball."

      cd - > /dev/null || bail "Could not cd back to: $OLDPWD"

   elif [[ -r "$SDPCopyDir/Version" ]]; then
      run "rsync -a --delete $SDPCopyDir/ $SDPHome" "Deploying SDP from: $SDPCopyDir" ||\
         bail "Failed to rsync SDP from $SDPCopyDir."
   else
      bail "The SDP directory [$SDPCopyDir] contains neither an SDP tarball file ($SDPTar) nor a Version file to indicate a pre-extracted SDP tarball. Aborting."
   fi
else
   # SDPInstallMethod is DVCS
   export PATH="$BinDir:$PATH"
   export P4ENVIRO=/dev/null/.p4enviro
   export P4CONFIG=.p4config.local
   run "/bin/mkdir -p $SDPHome" "Creating dir $SDPHome" ||\
      bail "Failed to create dir $SDPHome. Aborting."
   cd "$SDPHome" || bail "Failed to cd to [$SDPHome]."
   WorkshopRemote=perforce_software-sdp_${SDPInstallBranch}

   run "$BinDir/p4 -s -u $WorkshopUser clone -p $WorkshopPort -r $WorkshopRemote" \
      "Cloning SDP $SDPInstallBranch branch from The Workshop." ||\
      bail "Failed to clone SDP from The Workshop."

   run "$BinDir/p4 -s sync -f .p4ignore" \
      "Force-sync .p4ignore file."

   if [[ "$ShelvedChange" != Unset ]]; then
      run "$BinDir/p4 -s fetch -s $ShelvedChange" \
         "Fetching shelved change @$ShelvedChange from The Workshop." ||\
      bail "Failed to fetch shelved change @$ShelvedChange from The Workshop."

      LocalShelvedChange=$("$BinDir"/p4 -ztag -F %change% changes -s shelved -m 1)

      [[ -n "$LocalShelvedChange" ]] || \
         bail "Could not determine local shelved change fetched for shelved change @$ShelvedChange."

      run "$BinDir/p4 -s unshelve -s $LocalShelvedChange" \
         "Unshelving local shelved change @$LocalShelvedChange." ||\
         bail "Failed to unshelve local shelved change @$LocalShelvedChange."
   fi

   unset P4ENVIRO
   unset P4CONFIG
fi

if [[ -r "$SDPHome/Version" ]]; then
   if [[ "$SDPInstallMethod" == DVCS ]]; then
      msg "Version info not displayed as it is unreliable when using DVCS install method to get latest from the dev branch."
   else
      msg "SDP Version in $SDPHome is: $(cat "$SDPHome/Version")"
   fi
else
   bail "Cannot determine SDP Version; file $SDPHome/Version is missing."
fi

run "chown -R $RunUser:$RunGroup $SDPHome $ResetHome" \
   "Changing ownership to $RunUser:$RunGroup for $SDPHome $ResetHome" ||\
   bail "Failed to change ownership to $RunUser:$RunGroup."

cd "$SDPSetupDir" ||\
   bail "Could not cd to [$SDPSetupDir]."

run "/bin/mv -f mkdirs.cfg mkdirs.cfg.orig" \
   "Generating custom mkdirs.cfg in $PWD."

# The values for the P4MASTERHOST setting in the SDP mkdirs.cfg file can be
# 'DNS_name_of_master_server_for_this_instance' or
# 'DNS_name_of_master_server', depending on SDP version. Support both.
sed -e "s:=DNS_name_of_master_server_for_this_instance:=${Config['DNS_name_of_master_server']}:g" \
   -e "s:=DNS_name_of_master_server:=${Config['DNS_name_of_master_server']}:g" \
   -e "s:^MAILTO=.*:MAILTO=${Config['P4AdminList']}:g" \
   -e "s:^MAILFROM=.*:MAILFROM=${Config['MailFrom']}:g" \
   -e "s:mail.example.com:${Config['SMTPServer']}:g" \
   -e "s:^CASE_SENSITIVE=.*:CASE_SENSITIVE=${Config['CaseSensitive']}:g" \
   -e "s:^DB1=.*:DB1=${HxMetadata1}:g" \
   -e "s:^DB2=.*:DB2=${HxMetadata2}:g" \
   -e "s:^DD=.*:DD=${HxDepots}:g" \
   -e "s:^LG=.*:LG=${HxLogs}:g" \
   -e "s|^P4_PORT=.*|P4_PORT=SeeBelow|g" \
   -e "s|^P4BROKER_PORT=.*|P4BROKER_PORT=SeeBelow|g" \
   -e "s|^P4P_TARGET_PORT=.*|P4P_TARGET_PORT=$TargetPort|g" \
   -e "s|# P4_PORT=1666|P4_PORT=${Config['P4_PORT']}|g" \
   -e "s|# P4BROKER_PORT=1667|P4BROKER_PORT=${Config['P4BROKER_PORT']}|g" \
   -e "s:=adminpass:=${Config['Password']}:g" \
   -e "s:=servicepass:=${Config['Password']}:g" \
   -e "s:ADMINUSER=perforce:ADMINUSER=${Config['P4USER']}:g" \
   -e "s:OSUSER=perforce:OSUSER=$RunUser:g" \
   -e "s:OSGROUP=perforce:OSGROUP=$RunGroup:g" \
   -e "s:REPLICA_ID=replica:REPLICA_ID=p4d_ha_${Config['SiteTag']}:g" \
   -e "s:SVCUSER=service:SVCUSER=svc_p4d_ha_${Config['SiteTag']}:g" \
   mkdirs.cfg.orig > mkdirs.cfg

if [[ $UseSSL -eq 0 ]]; then
   msg "Not using SSL feature due to '-no_ssl'."
   sed "s/SSL_PREFIX=ssl:/SSL_PREFIX=/g" mkdirs.cfg > $TmpFile
   run "mv -f $TmpFile mkdirs.cfg"
fi

chmod +x mkdirs.sh

msg "\\nSDP Localizations in mkdirs.cfg:"
diff mkdirs.cfg.orig mkdirs.cfg

# Prior to SDP r20.1, 'p4d', 'p4', and other binaries were placed in
# /<DD>/sdp/p4/common/bin.  Modern SDP uses wrapper shell scripts in
# place of those binaries. If the wrapper script exists, skip the copy
# of the binaries.
if [[ -x "$SDPHome/Server/Unix${CBIN}/p4d" ]]; then
   run "cp -f -p $BinDir/p4* $SDPHome/helix_binaries/." \
      "Copying Perforce Helix binaries to $SDPHome/helix_binaries/." ||\
      errmsg "Failed to copy binaries to $SDPHome/helix_binaries/."
else
   run "cp -p $BinDir/p4* $SDPHome/Server/Unix${CBIN}/." \
      "Copying Perforce Helix binaries to $SDPHome/Server/Unix${CBIN}/." ||\
      errmsg "Failed to copy binaries to $SDPHome/Server/Unix${CBIN}/."
fi

msg "Initializing SDP instances and configuring $InitMechanism services."

for i in $SDPInstances; do
   cd "$SDPSetupDir" || bail "Could not cd to [$SDPSetupDir]."
   MkdirsCmd="$PWD/mkdirs.sh $i"

   if grep -q Version= mkdirs.sh > /dev/null 2>&1; then
      [[ -n "$ServerID" ]] && MkdirsCmd+=" -s $ServerID"
      [[ -n "$ServerType" ]] && MkdirsCmd+=" -t $ServerType"
      [[ -n "$TargetServerID" ]] && MkdirsCmd+=" -S $TargetServerID"
   else
      [[ -n "$ServerID" || "$ServerType" != "p4d_master" || -n "$TargetServerID" ]] && \
         warnmsg "Settings for ServerID, ServerType, and TargetServerID will be ignored due to too-old version of mkdirs.sh. Use SDP r20.1+ to take advantage of these configuration settings."
   fi

   log="$PWD/mkdirs.${i}.log"
   msg "Initializing SDP instance [$i], writing log [$log]."
   msg "Running: $MkdirsCmd"
   $MkdirsCmd > "$log" 2>&1
   cat "$log"

   if [[ "$InitMechanism" == "SysV" ]]; then
      msg "\\nConfiguring $InitMechanism services.\\n"
      cd /etc/init.d || bail "Could not cd to [/etc/init.d]."
      for svc in $BinList; do
         initScript=${svc}_${i}_init
         if [[ -x /p4/${i}/bin/$initScript ]]; then
            run "ln -s /p4/${i}/bin/$initScript"
            run "chkconfig --add $initScript"
            run "chkconfig $initScript on"
         fi
      done
   elif [[ "$InitMechanism" == "Systemd" && "$UseSystemd" -eq 1 ]]; then
      msg "\\nConfiguring $InitMechanism services.\\n"
      cd /etc/systemd/system || bail "Could not cd to /etc/systemd/system."
      for binary in $BinList; do
         svcName="${binary}_${i}"
         svcFile="${svcName}.service"

         # If the version of SDP deployed is 2020.1+, it will have templates
         # for systemd unit files. Use those if found, otherwise use the
         # baseline templates that come with the Helix Installer.
         svcTemplate="$SystemdTemplatesDir/${binary}_N.service.t"
         [[ ! -r "$svcTemplate" ]] && \
            svcTemplate="$ResetHome/${binary}_N.service.t"

         sed -e "s:__INSTANCE__:${i}:g" \
            -e "s:__OSUSER__:$RunUser:g" \
            "$svcTemplate" > "$svcFile" ||\
            bail "Failed to generate $PWD/$svcFile from template $svcTemplate."

         run "systemctl enable $svcName" "Enabling $svcName to start on boot." ||\
            warnmsg "Failed to enable $svcName with $InitMechanism."
         if [[ -n "$(command -v semanage)" ]]; then
            run "semanage fcontext -a -t bin_t /p4/${i}/bin/${binary}_${i}_init" ||\
               errmsg "Failed SELinux addition of init script for ${binary}_${i}."
         else
             warnmsg "SELinux is available but semanage not in PATH. Skipping semanage setup"
         fi

         if [[ -n "$(command -v restorecon)" ]]; then
            run "restorecon -vF /p4/${i}/bin/${binary}_${i}_init" ||\
               errmsg "Failed SELinux restorecon of init script for ${binary}_${i}."
         else
             warnmsg "SELinux is available but restorecon not in PATH. Skipping restorecon setup."
         fi
      done
      run "systemctl daemon-reload" "Reloading systemd after generating Systemd unit files." ||\
         warnmsg "Failed to reload systemd daemon."
   fi

   run "chown $RunUser:$RunGroup /$HxDepots" \
      "Adjusting ownership of /$HxDepots to $RunUser:$RunGroup." ||\
       bail "Failed to adjust ownership of /$HxDepots."

   for d in "/$HxDepots/p4" "$ResetHome" "$BinDir"; do
      if [[ -d "$d" ]]; then
         run "chown -R $RunUser:$RunGroup $d" \
            "Adjusting ownership of $d to $RunUser:$RunGroup." ||\
             bail "Failed to adjust ownership of $d."
      fi
   done

   msg "Apply custom proxy/broker-only host rules."
   iCfg="/p4/common/config/p4_${i}.vars"
   if [[ -r "$iCfg" ]]; then
      iCfgTmp="$(mktemp)"
      if [[ -n "$TargetPort" && "$ServerType" == "p4proxy" ]]; then
         sed -e "s|^export PROXY_TARGET=.*|export PROXY_TARGET=$TargetPort|g" "$iCfg" > "$iCfgTmp"
         mv -f "$iCfgTmp" "$iCfg"
      fi
      if [[ -n "$TargetPort" && "$ServerType" == "p4broker" ]]; then
         sed -e "s|^export P4PORT=.*|export P4PORT=$TargetPort|g" "$iCfg" > "$iCfgTmp"
         mv -f "$iCfgTmp" "$iCfg"
      fi
      if [[ -n "$ListenPort" && "$ServerType" == "p4proxy" ]]; then
         sed -e "s|^export PROXY_PORT=.*|export PROXY_PORT=$ListenPort|g" \
            -e "s|^export P4PORT=.*|export P4PORT=$ListenPort|g" \
            "$iCfg" > "$iCfgTmp"
         mv -f "$iCfgTmp" "$iCfg"
      fi
      if [[ -n "$ListenPort" && "$ServerType" == "p4broker" ]]; then
         sed -e "s|^export P4BROKERPORT=.*|export P4BROKERPORT=$ListenPort|g" \
            "$iCfg" > "$iCfgTmp"
         mv -f "$iCfgTmp" "$iCfg"
      fi
      chown "$RunUser:$RunGroup" "$iCfg"
   fi

   if [[ "$UseBroker" -eq 1 ]]; then
      msg "\\nGenerating broker config for instance $i.\\n"
      su -l "$RunUser" -c "$CBIN/gen_default_broker_cfg.sh ${i} > $CCFG/p4_${i}.broker.cfg"
   fi

done

if [[ "$UseSSL" -eq 1 ]]; then
   msg "Generating $SSLConfig SSL config file for autogen cert."
   sed -e "s/REPL_DNSNAME/helix/g" "$SSLConfig" > "$TmpFile" ||\
      bail "Failed to substitute content in $SSLConfig."
   run "mv -f $TmpFile $SSLConfig"
   msg "Contents of $SSLConfig:\\n$(cat "$SSLConfig")\\n"
   run "chown -R $RunUser:$RunGroup $SSLDir" \
      "Adjusting ownership of $SSLDir." ||\
      warnmsg "Failed to adjust ownership of SSL dir: $SSLDir"

   if [[ -x "$ServerBin" ]]; then
      msg "Generating SSL certificates."
      # If there are multipe SDP Instances, we only generate SSL certificates
      # for one instance.  Any one will do because SSL certs are not
      # instance-specific.
      su -l "$RunUser" -c "/p4/common/bin/p4master_run ${SDPInstances%% *} $ServerBin -Gc" ||\
         warnmsg "Failed to generate SSL Certificates."
   fi
fi

if [[ "$PreserveDirList" != Unset ]]; then
   for d in $(echo "$PreserveDirList" | tr ',' ' '); do
      preserveDir="/$HxDepots/p4/common/$d"
      tempCopyDir="$TmpDir/$d"
      run "rsync -av --exclude=.p4root --exclude=.p4ignore --exclude=.p4config $tempCopyDir/ $preserveDir" \
         "Restoring $preserveDir" ||\
         bail "Failed to restore $preserveDir."
   done

   run "/bin/rm -rf $TmpDir" "Cleanup: Removing temp dir [$TmpDir]." ||\
      bail "Failed to remove temp dir [$TmpDir]."
fi

#------------------------------------------------------------------------------
# To simulate email, generate a faux mail utility in the PATH.
if [[ "$SimulateEmail" -eq 1 ]]; then
   msg "Generating mail simulator."
   if [[ ! -d "$SiteBinDir" ]]; then
      run "mkdir -p $SiteBinDir" "Creating SiteBin dir: $SiteBinDir" ||\
         warnmsg "Failed to generate SiteBin dir: $SiteBinDir"
   fi

   echo -e "#!/bin/bash\\necho Simulated Email: \$*\\n" > "$MailSimulator"
   chmod +x "$MailSimulator"
   [[ -x "$MailSimulator" ]] || \
      warnmsg "Failed to generate mail simulator script: $MailSimulator"
   chown "$RunUser:$RunGroup" "$MailSimulator" || \
      warnmsg "Failed to do: chown \"$RunUser:$RunGroup\" \"$MailSimulator\""
fi

#------------------------------------------------------------------------------
# Install P4Perl and P4Python if the install scripts are available in the
# SDP Package. If the reset_sdp_*.sh scripts are not available, generate
# a warning message.
if [[ "$InstallDerivedAPIs" -eq 1 ]]; then
   if [[ -x "$SDPUnsupportedSetupDir/reset_sdp_python.sh" ]]; then
      msg "\\nInstalling P4Python for SDP using: $SDPUnsupportedSetupDir/reset_sdp_python.sh"
      su -l "$RunUser" -c "$SDPUnsupportedSetupDir/reset_sdp_python.sh" ||\
         errmsg "Failed to install P4Python."
   elif [[ -x "$SDPSetupDir/reset_sdp_python.sh" ]]; then
      msg "\\nInstalling P4Python for SDP using: $SDPSetupDir/reset_sdp_python.sh"
      su -l "$RunUser" -c "$SDPSetupDir/reset_sdp_python.sh" ||\
         errmsg "Failed to install P4Python."
   else
      warnmsg "SDP P4Python installer not available in SDP Package and '-dapi' was used."
   fi

   if [[ -x "$SDPUnsupportedSetupDir/reset_sdp_perl.sh" ]]; then
      msg "\\nInstalling P4Perl for SDP using: $SDPUnsupportedSetupDir/reset_sdp_perl.sh"
      su -l "$RunUser" -c "$SDPUnsupportedSetupDir/reset_sdp_perl.sh" ||\
         errmsg "Failed to install P4Perl."
   elif [[ -x "$SDPSetupDir/reset_sdp_perl.sh" ]]; then
      msg "\\nInstalling P4Perl for SDP using: $SDPSetupDir/reset_sdp_perl.sh"
      su -l "$RunUser" -c "$SDPSetupDir/reset_sdp_perl.sh" ||\
         errmsg "Failed to install P4Perl."
   else
      warnmsg "SDP P4Perl installer not available in SDP Package and '-dapi' was used."
   fi
fi

if [[ ! -d "$ResetHome" ]]; then
   run "/bin/mkdir -p $ResetHome" "Creating reset home dir [$ResetHome]." ||\
      bail "Could not create reset home dir [$ResetHome]. Aborting."
fi

cd "$ResetHome" || bail "Could not cd to $ResetHome. Aborting."

#------------------------------------------------------------------------------
# Add sudoers to /etc/sudoers.d if the directory exists and the user file doesn't.
if [[ "$DoSudo" -eq 1 ]]; then
   if [[ -d "$SudoersDir" ]]; then
      msg "Adding $RunUser to sudoers."

      if [[ -e "$SudoersFile" ]]; then
         run "rm -f $SudoersFile" "Removing existing sudoers [$SudoersFile] with these contents:\\n$(cat "$SudoersFile")" ||\
            errmsg "Failed to remove old sudoers file."
      fi

      if [[ "$LimitedSudoers" -eq 1 ]]; then
         if sed -e "s:__OSUSER__:$RunUser:g" -e "s:__HOSTNAME__:$(hostname -s):g" "$LimitedSudoersTemplate" > "$SudoersFile"; then
            run "chmod 0400 $SudoersFile" "Setting perms on sudoers file, $SudoersFile." ||\
               warnmsg "Failed to set perms on $SudoersFile."
         else
            warnmsg "Failed to create $SudoersFile."
         fi
      else
         if echo -e "$SudoersEntry" > "$SudoersFile"; then
            run "chmod 0400 $SudoersFile" "Setting perms on sudoers file, $SudoersFile." ||\
               warnmsg "Failed to set perms on $SudoersFile."
         else
            warnmsg "Failed to create $SudoersFile."
         fi
      fi
   else
      warnmsg "Skipping sudoers update; sudoers dir does not exist: $SudoersDir."
   fi
else
   msg "Skipping sudo setup due to '-no_sudo'."
fi

#------------------------------------------------------------------------------
# Add Perforce Package Repository to repo list (YUM and APT only).

if [[ "$AddPerforcePackageRepo" -eq 1 ]]; then
   if [[ -d "${P4YumRepo%/*}" ]]; then
      if [[ -n "$ThisOSMajorVersion" ]]; then
         run "rpm --import $PerforcePackagePubkeyURL" \
            "Adding Perforce's packaging key to RPM keyring." ||\
            warnmsg "Failed to add Perforce packaging key to RPM keyring."

         msg "Generating $P4YumRepo."
         if ! echo -e "[perforce]\\nname=Perforce\\nbaseurl=$PerforcePackageRepoURL/yum/rhel/$ThisOSMajorVersion/x86_64\\nenabled=1\\ngpgcheck=1\\n" > "$P4YumRepo"; then
            warnmsg "Unable to generate $P4YumRepo."
         fi
      else
         warnmsg "Skipping generation of $P4YumRepo due to lack of OS Major Version info."
      fi
   elif [[ -d "${P4AptGetRepo%/*}" ]]; then # /etc/apt/sources.list.d
      if [[ -n "$ThisOSName" && -n "$ThisOSDistro" ]]; then
         msg "Acquiring Perforce's package repository public key."
         if wget -qO - $PerforcePackagePubkeyURL > $TmpPubKey; then
            msg "Public key for Perforce package repo acquired as: $TmpPubKey"

            msg "Adding Perforce's packaging key to APT keyring."
            if apt-key add < /tmp/perforce.pubkey; then
               msg "APT keyring added successfully."
            else
               warnmsg "Failed to add Perforce packaging key to APT keyring."
            fi

            msg "Doing apt-get update after adding the new perforce.list repo."
            if apt-get update; then
               msg "Update completed."
            else
               warnmsg "An apt-get update did not return a zero exit code."
            fi
         else
            warnmsg "Failed to acquire Perforce package repo public key."
            UpdatePackages=0
         fi

         msg "Generating $P4AptGetRepo."
         if ! echo "deb $PerforcePackageRepoURL/apt/$ThisOSName $ThisOSDistro release" > "$P4AptGetRepo"; then
            warnmsg "Unable to generate $P4AptGetRepo."
            UpdatePackages=0
         fi
      else
         warnmsg "Skipping generation of $P4AptGetRepo due to lack of OS Name and Distro info."
         UpdatePackages=0
      fi
   else
      warnmsg "No Perforce supported package repository, RPM or APT, found to add. Skipping."
      UpdatePackages=0
   fi

   if [[ "$UpdatePackages" -eq 1 && "$PackageManager" != zypper ]]; then
      msg "Adding packages from the Perforce Package Repository."

      run "$PackageManager install -y ${ExtraP4PackageList[$PackageManager]}" \
         "Installing these packages with $PackageManager: ${PackageList[$PackageManager]}" ||\
         warnmsg "Not all Perforce packages installed successfully.  Proceeding."
   fi
else
   msg "Skipping addition of Perforce Package repository due to '-no_ppr'."
fi

#------------------------------------------------------------------------------
# Add Firewall rules.
if [[ "$DoFirewall" -eq 1 ]]; then

   # Add Firewall rules for Firewalld, popular on the RHEL/RockyLinux/CentOS family.
   if [[ "$FirewallType" == "Firewalld" ]]; then
      msg "\\nConfiguring $FirewallType services.\\n"
      cd "$FirewallDir" || bail "Could not cd to $FirewallDir."
      for i in $SDPInstances; do
         for binary in $BinList; do
            svcName="${binary}_${i}"
            svcFile="${svcName}.xml"
            sed -e "s:__INSTANCE__:${i}:g" \
               -e "s:__P4PORT__:${Config['P4_PORT']}:g" \
               -e "s:__P4BROKER_PORT__:${Config['P4BROKER_PORT']}:g" \
               "$ResetHome/${binary}_N.xml.t" > "$svcFile" ||\
               bail "Failed to generate $PWD/$svcFile."
            run "firewall-cmd --add-service=$svcName" \
               "Adding firewall entry for $svcName." ||\
               warnmsg "Adding firewall entry for $svcName failed."
         done

         run "firewall-cmd --runtime-to-permanent" \
            "Permanently adding firewall entries" ||\
            warnmsg "Adding permanent firewall entries failed."
      done
      run "firewall-cmd --reload" "Firewall reload." ||\
         warnmsg "Firewall reload failed."
      run "iptables-save" "Showing firewall rules." ||\
         warnmsg "Showing firewall failed."
   elif [[ "$FirewallType" == "IPTables" ]]; then
      warnmsg "IPtables firewall detected, but not handled."
   fi
else
   msg "Skipping firewall setup due to '-no_firewall'."
fi

#------------------------------------------------------------------------------
# Load crontab.
if [[ "$InstallCrontab" -eq 1 ]]; then
   CrontabFile="$SDPCrontabDir/crontab.$RunUser.${HOSTNAME%%.*}"

   # Search for SDP-generated crontab files in a particular order, looking for
   # *.new files first and accounting for an SDP change introducing the
   # SDP instance name info the file.
   for i in $SDPInstances; do
      for f in /p4/p4.crontab.${i}.new /p4/p4.crontab.${i} /p4/p4.crontab.new /p4/p4.crontab; do
         if [[ -r "$f" ]]; then
            CrontabFileInP4="$f"
            break
         fi
      [[ -n "$CrontabFileInP4" ]] && break
      done
   done

   if [[ -n "$CrontabFileInP4" ]]; then
      run "mv $CrontabFileInP4 $CrontabFile" ||\
         errmsg "Failed to move crontab file to $CrontabFile."

      run "crontab -u $RunUser $CrontabFile" "Setting crontab for $RunUser." ||\
         errmsg "Failed to load crontab."
   else
      warnmsg "No SDP-generated crontab file found. Skipping load of crontab."
   fi
else
   msg "Not loading crontab due to '-no_cron'."
fi

if [[ "$DoSDPVerify" -eq 1 && -x "$SDPVerify" ]]; then
   SDPVerifyOptions+=" -L off"
   SDPVerifySkipTests="offline_db,p4root,p4t_files"

   [[ "$InstallCrontab" -eq 0 ]] && SDPVerifySkipTests+=",cron"
   SDPVerifyOptions+=" -skip $SDPVerifySkipTests"

   for i in $SDPInstances; do
      SDPVerifyCmd="$SDPVerify $i $SDPVerifyOptions"
      msg "\\nDoing SDP verification for instance $i."
      if run "$SDPVerifyCmd"; then
         msg "SDP verification for instance $i was OK."
      else
         errmsg "SDP verification for instance $i reported errors."
      fi
   done
elif [[ "$DoSDPVerify" -eq 1 ]]; then
   errmsg "No $SDPVerify script found to execute. Skipping it."
fi

#------------------------------------------------------------------------------
# Apply Support-recommended OS Tweaks to Linux kernel parameters.
# (e.g. KHugePage, etc.)
if [[ "$RunOSTweaks" -eq 1 ]]; then
   if [[ "$ThisOS" == "Linux" ]]; then
      if [[ -x "$OSTweaksScript" ]]; then
         run "$OSTweaksScript" "Making recommended Linux OS tweaks." ||\
         warnmsg "Non-zero exit code ($CMDEXITCODE) returned from $SDPSetupDir/os_tweaks.sh"
      else
         msg "Not making OS tweaks, $OSTweaksScript is missing or not executable."
      fi
   else
      msg "Skipping OS tweaks on non-Linux OS."
   fi
else
   msg "Skipping OS tweaks due to '-no_tweaks'."
fi

if [[ "$ErrorCount" -eq 0 ]]; then
   if [[ "$WarningCount" -eq 0 ]]; then
      msg "\\nSUCCESS:  SDP Configuration complete."
   else
      msg "\\nSUCCESS:  SDP Configuration complete with $WarningCount warnings."
   fi

   if [[ "$MultiRun" -eq 0 ]]; then
      run "/bin/rm -rf $ResetHome/*" \
         "Purging $ResetHome to avoid multiple runs." || \
         warnmsg "Failed to remove $ResetHome"
   else
      msg "Self-disable safety feature ignored due to '-M'."
   fi
else
   msg "\\nSDP Configuration completed, but with $ErrorCount errors and $WarningCount warnings."
fi

exit "$ErrorCount"
