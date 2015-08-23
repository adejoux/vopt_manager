# vopt_manager
manage creation and deletion of virtual optical devices on power systems

# usage

~~~
usage: vopt_manager -m managed_system -h hmc [-u user] [-p] [-vio vio1,vio2] [-lpar lpar1,lpar2] [-list|-unload|-remove|-create] [-exec]
       -h hmc: remote hmc. Hostname or IP address
       -m managed_system: system to manage
       -u user: hmc user
       -p : prompt for hmc user password
       -lpar lpar1,lpar2: list of the partitions where to perform the action
       -vio vio1,vio2: list of the vio servers where to perform the action
       -list: list existing VOPT
       -unload: unload media from existing VOPT
       -remove: remove existing VOPT
       -create: create existing VOPT
       -exec: execute the unloadopt, create and remove commands

~~~

The script connect only on the HMC and use viosvrcmd command to pass commands to the vio servers.
RMC communication need to be enabled between the HMC and the vio servers.

Note: without ***-exec*** flag, no modification is applied on the systems.

# AIX package

This perl script use 3 perl modules : **Net::OpenSSH**, **Data::Dumper::Simple**, **Term::ReadKey** and **IO::Tty**.

**Term::ReadKey** and **IO::Tty** are used to provide a password prompt which is not displaying your password when typing it.

I didn't want to mess up a system perl installation by adding this perl modules in standard paths.
So I created a package available in the releases section. It will install all perl libraries used by the script in **/usr/local/vopt_manager**. So it's transparent for your system.

Installing the AIX package :
~~~
inutoc .
installp -acd . vopt_manager.rte
~~~

Listing the package :
~~~
root@adxlpar1(/vopt_manager)# lslpp -L vopt_manager.rte
  Fileset                      Level  State  Type  Description (Uninstaller)
  ----------------------------------------------------------------------------
  vopt_manager.rte           1.0.0.0    C     F    virtual optical devices
                                                   manager
~~~

Removing the AIX package :
~~~
installp -u vopt_manager.rte
~~~

# building the AIX package

You will need the template file in packaging folder. You will also need to build each Perl module.
You can see in the tempalte file what are the files expected to build the package.

**IO:Tty** require a C compiler for installation.

I wrote an article on building a AIX package here :[building AIX packages](https://www.djouxtech.net/posts/building-aix-packages/)


# examples

List existing virtual optical devices on a managed system on all partitions :

~~~
root@adxlpar1(/root)# vopt_manager -m p750B -h hmclab -list
#HMC:                   hmclab
#Managed System:        p750B

#
#LIST VIRTUAL OPTICAL DEVICES
#
#vopt:vios:vhost:physloc:lparid:lpar:media
root@adxlpar1(/root)# vopt_manager -m p750A -h hmclab -list
#HMC:                   hmclab
#Managed System:        p750A

#
#LIST VIRTUAL OPTICAL DEVICES
#
#vopt:vios:vhost:physloc:lparid:lpar:media
vtopt0:P750A-vios1:vhost0:U8233.E8B.06269FP-V1-C10:3:powerVC:RHEL71
vtopt1:P750A-vios1:vhost3:U8233.E8B.06269FP-V1-C20:4:AIX71latest:AIX71TL3
vtopt0:P750A-vios2:vhost0:U8233.E8B.06269FP-V2-C11:3:powerVC:rhel71-BE
~~~

List existing virtual optical devices on  lgenim11 partition :

~~~
root@adxlpar1(/root)# vopt_manager -m p750B -h hmclab -lpar powerVC -list
#HMC:                   hmclab
#Managed System:        p750B

#
#LIST VIRTUAL OPTICAL DEVICES
#
#vopt:vios:vhost:physloc:lparid:lpar:media
root@adxlpar1(/root)# vopt_manager -m p750A -h hmclab -lpar powerVC -list
#HMC:                   hmclab
#Managed System:        p750A

#
#LIST VIRTUAL OPTICAL DEVICES
#
#vopt:vios:vhost:physloc:lparid:lpar:media
vtopt0:P750A-vios1:vhost0:U8233.E8B.06269FP-V1-C10:3:powerVC:RHEL71
vtopt0:P750A-vios2:vhost0:U8233.E8B.06269FP-V2-C11:3:powerVC:rhel71-BE
~~~

Remove all optical devices on all partitions :

~~~
[lgenim11:root:/home/root/alain:] root@adxlpar1(/root)# vopt_manager  -m p750B -h hmclab -p -remove -exec
Password:
#HMC:                   hmclab
#Managed System:        p750B

#
#LIST VIRTUAL OPTICAL DEVICES
#
#vopt:vios:vhost:physloc:lparid:lpar:media
adxlpar1_cd:P750B-vios1:vhost5:U8233.E8B.100EB9P-V1-C6:8:adxlpar1:No
adxlpar2_cd:P750B-vios1:vhost1:U8233.E8B.100EB9P-V1-C12:4:adxlpar2:No
adxlpar1_cd:P750B-vios2:vhost5:U8233.E8B.100EB9P-V2-C6:8:adxlpar1:No
adxlpar2_cd:P750B-vios2:vhost1:U8233.E8B.100EB9P-V2-C12:4:adxlpar2:No
#
#UNLOAD VIRTUAL OPTICAL DEVICES
#
#
#REMOVE VIRTUAL OPTICAL DEVICES
#
#hmc command executed for lpar adxlpar1 : viosvrcmd -m p750B -p P750B-vios1 -c "rmvdev -vtd adxlpar1_cd"
#hmc command executed for lpar adxlpar2 : viosvrcmd -m p750B -p P750B-vios1 -c "rmvdev -vtd adxlpar2_cd"
#hmc command executed for lpar adxlpar1 : viosvrcmd -m p750B -p P750B-vios2 -c "rmvdev -vtd adxlpar1_cd"
#hmc command executed for lpar adxlpar2 : viosvrcmd -m p750B -p P750B-vios2 -c "rmvdev -vtd adxlpar2_cd"
~~~

Generate commands to create virtual optical devices for all partitions :

~~~
root@adxlpar1(/root)# vopt_manager  -m p750B -h hmclab -create
#HMC:                   hmclab
#Managed System:        p750B

#
#LIST VIRTUAL OPTICAL DEVICES
#
#vopt:vios:vhost:physloc:lparid:lpar:media
#
#CREATE VIRTUAL OPTICAL DEVICES
#
#generated command(not run) for lpar adxlpar1 : viosvrcmd -m p750B -p P750B-vios1 -c "mkvdev -fbo -dev adxlpar1_cd -vadapter vhost5"
#generated command(not run) for lpar adxlpar1 : viosvrcmd -m p750B -p P750B-vios2 -c "mkvdev -fbo -dev adxlpar1_cd -vadapter vhost5"
#generated command(not run) for lpar adxlpar2 : viosvrcmd -m p750B -p P750B-vios1 -c "mkvdev -fbo -dev adxlpar2_cd -vadapter vhost1"
#generated command(not run) for lpar adxlpar2 : viosvrcmd -m p750B -p P750B-vios2 -c "mkvdev -fbo -dev adxlpar2_cd -vadapter vhost1"
~~~

Create a virtual optical device on one partition :

~~~
root@adxlpar1(/root)# vopt_manager  -m p750B -vio P750B-vios1 -lpar adxlpar1 -h hmclab -create -exec
Password:
#HMC:                   hmclab
#Managed System:        p750B

#
#LIST VIRTUAL OPTICAL DEVICES
#
#vopt:vios:vhost:physloc:lparid:lpar:media
#
#CREATE VIRTUAL OPTICAL DEVICES
#
#hmc command executed for lpar adxlpar1 : viosvrcmd -m p750B -p P750B-vios1 -c "mkvdev -fbo -dev adxlpar1_cd -vadapter vhost5"
~~~

# Copyright

The code is licensed as MIT. See the LICENSE file for the full license.

Copyright (c) 2015 Alain Dejoux adejoux@djouxtech.net

