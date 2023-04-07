# https://swarm.workshop.perforce.com/projects/perforce_software-helix-installer/
# Ensure this file is saved as LF, NOT CRLF!
#------------------------------------------------------------------------------
# Config file for reset_sdp.sh v4.11.5.
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
# Changing all these is typical and expected, even for PoC installations.

# Specify email server for the p4review script. Ignore if Helix Swarm is used.
SMTPServer=smtp.p4demo.com

# Specify an email address to receive updates from admin scripts. This may be
# a distribution list or comma-separated list of addresses (with no spaces).
P4AdminList=P4AdminList@p4demo.com

# Specify an email address from which emails from admin scripts are sent.
# This must be a single email address.
MailFrom=P4Admin@p4demo.com

# Specify the DNS alias to refer to he master server, e.g. by end
# users. This might be 'perforce' but probably not an actual host name
# like 'perforce01', which would be known only to admins.
DNS_name_of_master_server=helix

# Specify a geographic site tag for the master server location,
# e.g. 'bos' for Boston, MA, USA.
SiteTag=bos

# Specify the hostname.  This can be left blank. If set on a system that supports
# the 'hostnamectl' utility, that utility will be used to set the hostname.  If the
# command line parameter '-H <hostname>' is used, that will override this setting.
Hostname=

# Specify the timezone.  This can be left blank. If set on a system that supports
# the 'timedatectl' utility, that utility will be used to set the timezone.  If the
# command line parameter '-T <timezone>' is used, that will override this setting.
Timezone=

#------------------------------------------------------------------------------
# Section 2: Data Specific
#------------------------------------------------------------------------------
# These settings can be changed to desired values, though default values are
# preferred for demo installations.

# Specify the TCP port for p4d to listen on. Typically this is 1999 if 
# p4broker is used, or 1666 if only p4d is used.
P4_PORT=1999

# Specify the TCP port for p4broker to listen on. Must be different
# from the P4_PORT.
P4BROKER_PORT=1666

# Specify SDP instance name, e.g. '1' for /p4/1.
Instance=${INSTANCE}

# Helix Core case sensitivity, '1' (sensitive) or '0' (insensitive). If
# data from a checkpoint is to be migrated into this instance, set this
# CaseSensitive value to match the case handling of the incoming data set
# (as shown with 'p4 info').
CaseSensitive=1

# Set the P4USER value for the Perforce super user.
P4USER=perforce

# Set the password for the super user (see P4USER). If using this Helix Installer to
# bootstrap a production installation, replace this default password with your own.
Password=

# Specify '1' to avoid sending email from admin scripts, or 0 to send
# email from admin scripts.
SimulateEmail=1

# Specify a ServerID value. Leave this value blank for master/commit servers.
# The value for master/commit servers is set automatically.
ServerID=${SERVER_ID}

# Specify the type of server. Valid values are:
# * p4d_master - A master/commit server.
# * p4d_replica - A replica with all metadata from the master (not filtered in
# any way).
# * p4d_filtered_replica - A filtered replica or filtered forwarding replica.
# * p4d_edge - An edge server.
# * p4d_edge_replica - Replica of an edge server. Also set TargetServerID.
# * p4broker - An SDP host running only a broker, with no p4d.
# * p4proxy - An SDP host running a proxy (maybe with a broker in front), with
# no p4d.
#
# The ServerID must also be set if the ServerType is any p4d_*
# type other than 'p4d_master'.
ServerType=${SERVER_TYPE}

# Set only if ServerType is p4d_edge_replica. The value is the ServerID of
# edge server that this server is a replica of, and must match the
# 'ReplicatingFrom:' field of the server spec.
TargetServerID=

# Specify the target port for a p4proxy or p4broker.
TargetPort=

# Specify the listening port for a p4proxy or p4broker.
ListenPort=

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
# However, there are no functional limitations to changing these settings.

# Specify the Linux Operating System account under which p4d and other Helix
# services will run as. This user will be created if it does not exist. If
# created, the password will match that of the P4USER.
OSUSER=perforce

# Specify the primary group for the Linux Operating System account specified
# as OSUSER.
OSGROUP=perforce

#Specify a comma-delimited list of any additional groups the OSUSER to be
# created should be in.  This is passed to the 'useradd' command the '-G'
# flag. These groups must already exist.
OSUSER_ADDITIONAL_GROUPS=

# Specify home directory of the Linux account under which p4d and other Helix
# services will run as, and the group, in the form <user>:<group>.  This user
# and group will be created if they do not exist.
OSUSER_HOME=/home/perforce

# The version of Perforce Helix binaries to be downloaded: p4, p4d, p4broker, and p4p.
P4BinRel=r22.2

# The version of the C++ API to be downloaded, for building dervied APIs such
# as P4Perl and P4Python.  This is typically the same as P4BinRel, but
# sometimes behind as P4Perl and P4Python can lag behind Helix Core releases.
P4APIRel=r22.2

# The following Hx* settings reference directories that store Perforce
# Helix data.  If configuring for optimal performance and scalability,
# these folders can be mount points for storage volumes.  If so, they must
# be mounted prior to running the reset_sdp.sh script (other than to generate
# this configuration file).
#
# See the Server Deployment Package (SDP) for information and guidance on
# provisioning these volumes.

# Define the directory that stores critical digital assets that must be
# backed up, including contents of versioned files, metadata checkpoints,
# and numbered journal files.
HxDepots=/hxdepots

# Define the directory used to store the active journal (P4JOURNAL) and
# various logs.
HxLogs=/hxlogs

# The /HxMetadata1 and /HxMetadata1 settings define two interchangeable
# directories that store either active/live metadata databases (P4ROOT) or
# offline copies of the same (offline_db). These typically point to the same
# directory. Pointing them to the same directory simplifies infrastructure
# and enables the fastest recovery options. Using multiple metadata volumes
# is typically done when forced to due to capacity limitations for metadata
# on a single volume, or to provide operational survivability of the host in
# event of loss of a single metadata volume.
HxMetadata1=/hxmetadata
HxMetadata2=/hxmetadata