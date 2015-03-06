# vopt_manager
manage creation and deletion of virtual optical devices on power systems

# usage

~~~
usage: vopt_manager.pl -m managed system -h hmc [-u user] [-p password] [-lpar lpar1,lpar2] [-list|-unloadopt|-remove|-create] [-exec] 
       -h hmc: remote hmc. Hostname or IP address
       -m managed system: system to manage
       -u user: hmc user
       -p password: hmc user password if no ssh key setup
       -name lpar1,lpar2: list of the partitions where to perform the action
       -list: list existing VOPT 
       -unloadopt: unload media from existing VOPT 
       -remove: remove existing VOPT 
       -create: create existing VOPT 
       -exec: execute the unloadopt, create and remove commands 
~~~

The script is connecting to the HMC only and use viosvrcmd command to pass commands to the vio servers.
RMC communication need to be enabled between the HMC and the vio servers.

Note: without ***-exec*** flag, no modifcation is applied on the systems.

# examples

List existing virtual optical devices on a managed system on all partitions :

~~~
[lgenim11:root:/home/root/alain:] perl vopt_manager.pl -h lgehmc01 -m Server-8203-E4A-SN658EE55 -list  
#HMC:                   lgehmc01
#Managed System:        Server-8203-E4A-SN658EE55

#
#LIST VIRTUAL OPTICAL DEVICES
#
#vopt:vios:vhost:physloc:lparid:media
lgeaix03-b90fc:lgevio12:vhost2:U8203.E4A.658EE55-V2-C18:lgeaix03-b90fcd08-00000006:No
lgenim11_cdrom:lgevio12:vhost0:U8203.E4A.658EE55-V2-C20:lgenim11:No
lgeaix18-fa10b:lgevio12:vhost4:U8203.E4A.658EE55-V2-C14:lgeaix18-fa10b187-00000017:No
lgepvc01_cdrom:lgevio12:vhost3:U8203.E4A.658EE55-V2-C16:lgepvc01:No
lgeaix02-b0d00:lgevio12:vhost1:U8203.E4A.658EE55-V2-C17:lgeaix02-b0d00aea-00000005:No
~~~

List existing virtual optical devices on a managed system on lgenim11 partition :

~~~
[lgenim11:root:/home/root/alain:] perl vopt_manager.pl -h lgehmc01 -m Server-8203-E4A-SN658EE55 -list -lpar lgenim11
#HMC:                   lgehmc01
#Managed System:        Server-8203-E4A-SN658EE55

#
#LIST VIRTUAL OPTICAL DEVICES
#
#vopt:vios:vhost:physloc:lparid:media
lgenim11_cdrom:lgevio12:vhost0:U8203.E4A.658EE55-V2-C20:lgenim11:No
~~~

Generate commands to remove all optical devices on all partitions :

~~~
[lgenim11:root:/home/root/alain:] perl vopt_manager.pl -h lgehmc01 -m Server-8203-E4A-SN658EE55 -remove
#HMC:                   lgehmc01
#Managed System:        Server-8203-E4A-SN658EE55

#
#LIST VIRTUAL OPTICAL DEVICES
#
#vopt:vios:vhost:physloc:lparid:media
lgeaix03-b90fc:lgevio12:vhost2:U8203.E4A.658EE55-V2-C18:lgeaix03-b90fcd08-00000006:No
lgenim11_cdrom:lgevio12:vhost0:U8203.E4A.658EE55-V2-C20:lgenim11:No
lgeaix18-fa10b:lgevio12:vhost4:U8203.E4A.658EE55-V2-C14:lgeaix18-fa10b187-00000017:No
lgepvc01_cdrom:lgevio12:vhost3:U8203.E4A.658EE55-V2-C16:lgepvc01:No
lgeaix02-b0d00:lgevio12:vhost1:U8203.E4A.658EE55-V2-C17:lgeaix02-b0d00aea-00000005:No
#
#UNLOAD VIRTUAL OPTICAL DEVICES
#
#
#REMOVE VIRTUAL OPTICAL DEVICES
#
# no virtual optical devices
#command to run on hmc : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "rmvdev -vtd lgeaix03-b90fc" 
#command to run on hmc : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "rmvdev -vtd lgenim11_cdrom" 
#command to run on hmc : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "rmvdev -vtd lgeaix18-fa10b" 
#command to run on hmc : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "rmvdev -vtd lgepvc01_cdrom" 
#command to run on hmc : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "rmvdev -vtd lgeaix02-b0d00" 
~~~

Remove all optical devices on all partitions :

~~~
[lgenim11:root:/home/root/alain:] perl vopt_manager.pl -h lgehmc01 -m Server-8203-E4A-SN658EE55 -remove -exec                         
#HMC:                   lgehmc01
#Managed System:        Server-8203-E4A-SN658EE55

#
#LIST VIRTUAL OPTICAL DEVICES
#
#vopt:vios:vhost:physloc:lparid:media
lgeaix03-b90fc:lgevio12:vhost2:U8203.E4A.658EE55-V2-C18:lgeaix03-b90fcd08-00000006:No
lgenim11_cdrom:lgevio12:vhost0:U8203.E4A.658EE55-V2-C20:lgenim11:No
lgeaix18-fa10b:lgevio12:vhost4:U8203.E4A.658EE55-V2-C14:lgeaix18-fa10b187-00000017:No
lgepvc01_cdrom:lgevio12:vhost3:U8203.E4A.658EE55-V2-C16:lgepvc01:No
#
#UNLOAD VIRTUAL OPTICAL DEVICES
#
#
#REMOVE VIRTUAL OPTICAL DEVICES
#
# no virtual optical devices
#exec : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "rmvdev -vtd lgeaix03-b90fc"
#exec : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "rmvdev -vtd lgenim11_cdrom"
#exec : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "rmvdev -vtd lgeaix18-fa10b"
#exec : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "rmvdev -vtd lgepvc01_cdrom"
~~~

Generate commands to create virtual optical devices for all partitions :

~~~
[lgenim11:root:/home/root/alain:] perl vopt_manager.pl -h lgehmc01 -m Server-8203-E4A-SN658EE55 -create      
#HMC:                   lgehmc01
#Managed System:        Server-8203-E4A-SN658EE55

#
#LIST VIRTUAL OPTICAL DEVICES
#
# no virtual optical devices
#
#CREATE VIRTUAL OPTICAL DEVICES
#
#command to run on hmc : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "mkvdev -fbo -dev lgeaix02-b0d00 -vadapter vhost1" 
#command to run on hmc : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "mkvdev -fbo -dev lgeaix18-fa10b -vadapter vhost4" 
#command to run on hmc : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "mkvdev -fbo -dev lgenim11_cdrom -vadapter vhost0" 
#command to run on hmc : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "mkvdev -fbo -dev lgeaix03-b90fc -vadapter vhost2" 
#command to run on hmc : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "mkvdev -fbo -dev lgepvc01_cdrom -vadapter vhost3" 
~~~

Create a virtual optical device on one partition :

~~~
[lgenim11:root:/home/root/alain:] perl vopt_manager.pl -h lgehmc01 -m Server-8203-E4A-SN658EE55 -create -lpar lgenim11 -exec
#HMC:                   lgehmc01
#Managed System:        Server-8203-E4A-SN658EE55

#
#LIST VIRTUAL OPTICAL DEVICES
#
# no virtual optical devices
#
#CREATE VIRTUAL OPTICAL DEVICES
#
#exec : viosvrcmd -m Server-8203-E4A-SN658EE55 -p lgevio12 -c "mkvdev -fbo -dev lgenim11_cdrom -vadapter vhost0"
~~~

