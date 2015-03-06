#!/usr/bin/perl
# author: Alain Dejoux<adejoux@djouxtech.net>
# description: manage vopt creation and deletion
# license : MIT 
# version : 0.2
# date : 6 March 2015

use strict;
use warnings;
use lib './perl5/lib/site_perl/5.8.8/aix-thread-multi';
use lib './perl5/lib/perl5';
use lib './perl5/lib/perl5/ppc-aix';
use lib './perl5/lib/perl5/lib/site_perl/5.8.8';
use Getopt::Long ();
use Net::OpenSSH;
use Data::Dumper::Simple;

# variables
my $debug  = 0;
my $hmc_user = "hscroot";

my ($list, $unloadopt, $remove, $create, $exec, $managed_system, $hmc, $hmc_session, $lpars, $password);
my (%lpar_list, %voptmap,  %vopt, %lpar_names);

Getopt::Long::GetOptions(
    'hmc|h=s' => \$hmc,
    'user|u=s' => \$hmc_user,
    'm=s' => \$managed_system,
    'lpar=s' => \$lpars,
    'pass|p=s' => \$password,
    'unloadopt' => \$unloadopt,
    'list' => \$list,
    'remove' => \$remove,
    'create' => \$create,
    'exec' => \$exec,
    'debug' => \$debug
)

or usage("Invalid commmand line options.");

sub validate_args {
  usage("The source managed system must be specified.") unless defined $managed_system;
  usage("The hmc name must be specified.") unless defined $hmc;
  usage("A action need to be specified.") unless ($list || $unloadopt || $remove || $create);
}

sub usage {
  my $message = $_[0];
  if (defined $message && length $message) {
      $message .= "\n"
      unless $message =~ /\n$/;
  }

  my $command = $0;
  $command =~ s#^.*/##;

  print STDERR (
    "ERROR: " . $message,
    "usage: $command -m managed system -h hmc [-u user] [-p password] [-lpar lpar1,lpar2] [-list|-unloadopt|-remove|-create] [-exec] \n" .
    "       -h hmc: remote hmc. Hostname or IP address\n" .
    "       -m managed system: system to manage\n" .
    "       -u user: hmc user\n" .
    "       -p password: hmc user password if no ssh key setup\n" .
    "       -name lpar1,lpar2: list of the partitions where to perform the action\n" .
    "       -list: list existing VOPT \n" .
    "       -unloadopt: unload media from existing VOPT \n" .
    "       -remove: remove existing VOPT \n" .
    "       -create: create existing VOPT \n" .
    "       -exec: execute the unloadopt, create and remove commands \n\n"
  );
  die("\n")
}

sub hmc_connect {
  my $ssh = Net::OpenSSH->new($hmc,
                              user => $hmc_user,
                              password => $password,
                              kill_ssh_on_timeout => 120,
                              master_opts => [-o => "StrictHostKeyChecking=no"]);

  if ($ssh->error) {
    die "Could not connect to host $hmc.\nError:" . $ssh->error . "\n";
  }
  return $ssh;
}

sub hmc_command {
  my ($session) = shift;
  my $cmd = shift;
  my $error_msg = shift;

  warn whoami() . ":" . Dumper($cmd) if $debug;
  my ($stdout, $stderr) = $session->capture2({timeout => 120}, $cmd);
  warn whoami() . ":" . Dumper($stdout) if $debug;

  unless ($session->error) {
    return $stdout;
  }

  if ($error_msg) {
    die "$error_msg\n";
  } else {
    die "$stdout\n$stderr\n";
  }
}

sub managed_system_validate {
  my ($session, $managed_system) = @_;
  hmc_command($session,
              "lssyscfg -r sys -m $managed_system -F name",
              "Managed System $managed_system does not exist. Please enter a valid Managed System name.\n");
}

sub build_lpar_list {
  my $session = shift;
  my $reflpar_list = shift;
  my ($lpar_name, $lpar_id, $lpar_env, $line);
  my $result = hmc_command $session, qq#lssyscfg -r lpar -F name,lpar_id,lpar_env -m $managed_system#;

  warn whoami() . ":" . Dumper($result) if $debug;
  my @line = split(/\n/, $result);
  foreach my $value (@line) {
    ($lpar_name, $lpar_id, $lpar_env) = split(/,/,$value);
    warn whoami() . ":" . Dumper($lpar_id, $lpar_name, $lpar_env) if $debug;
    $$reflpar_list{$lpar_env}{$lpar_id} = $lpar_name;
  }
}

sub parse_lsvopt {
  warn uc(whoami()) . "\n" if $debug;
  my $vios = shift;
  my $output = shift;
  my $refvopt = shift;
  my $valid = 0;

  my @lines = split /\n/, $output;

  foreach (@lines) {
    if ( /^VTD / ) {
      $valid = 1;
      next;
    }
    next unless $valid;

    if ( /(\S+)\s+(\S+)\s+(\S+)/ ) {
      warn whoami() . " process vopt line:" .  $_ if $debug;
      my $vtd = $1;
      my $media = $2;
      my $size = $3;

      $$refvopt{$vtd}{'media'} = $media;
      $$refvopt{$vtd}{'size'} = $size;
      $$refvopt{$vtd}{'vios'} = $vios;
    }

  }
}

sub parse_lsmap {
  warn uc(whoami())  . "\n" if $debug;
  my $vios = shift;
  my $output = shift;
  my $refvopt = shift;
  my $refvoptmap = shift;
  my @lines = split /\n/, $output;

  foreach my $line (@lines) {
    my $status = 0;

    foreach my $vopt (keys %{$refvopt} ) {
      if ( $line =~ /(vhost\d+):(0x[^:]+):([^:]+):.*$vopt/ ) {
        warn whoami() . " parse vopt mapping:" .  $line if $debug;
        $$refvopt{$vopt}{'vhost'}= $1;
        my $lparid = sprintf("%d", hex($2));
        $$refvopt{$vopt}{'lparid'}= $lparid;
        $$refvopt{$vopt}{'physloc'}= $3;
        $$refvoptmap{$lparid}{'status'} = "YES";
        $status = 1;
      }
    }

    next if ($status);

    if ( $line =~ /(vhost\d+):(0x[^:]+):([^:]+):/ ) {
      warn whoami() . " parse NO vopt mapping:" .  $line if $debug;
      my $lparid = sprintf("%d", hex($2));
      $$refvoptmap{$lparid}{'vhost'} = $1;
      $$refvoptmap{$lparid}{'vios'} = $vios;
    }
  }
}

sub whoami  { ( caller(1) )[3] }

sub check_exec {
  my $cmd = shift;
  if ($exec) {
    print "#exec : " . $cmd . "\n";
    hmc_command $hmc_session, $cmd;
  } else {
    print "#command to run on hmc : $cmd \n";
  }
}

sub safe_print {
  my $msg = shift;

  if (not defined $msg) {
    print "N/F:";
  } else {
    print $msg;
  }
}

sub check_vopt_lpar {
  my $vopt = shift;
 
  return 0 unless (%lpar_names);
 
  my $lparid=$vopt{$vopt}{'lparid'};
  my $lpar=$lpar_list{'aixlinux'}{$lparid};
 
  return check_lpar($lpar); 
}

sub check_lpar {
  my $lpar = shift;

  return 0 unless (%lpar_names);

  if ($lpar_names{$lpar}) {
    return 0;
  } else {
    warn whoami() . ":  lpar $lpar skipped !\n" if $debug;
    return 1;
  }
}

#
# Main
#

validate_args();

if ($lpars) {
  my @entries=split /\n/, $lpars;
  foreach my $entry (@entries) {
    chomp($entry);
    $lpar_names{$entry}=1;
  }
}

$hmc_session = hmc_connect();

managed_system_validate($hmc_session,$managed_system);

build_lpar_list($hmc_session, \%lpar_list);
warn "main:" . Dumper(%lpar_list) if $debug;

my @vio_list;
@vio_list = values %{$lpar_list{'vioserver'}};
warn "main:" . Dumper(@vio_list) if $debug;

foreach my $vios ( @vio_list ) {
   warn  "vio: $vios\n" if $debug;

   my $result_vopt = hmc_command $hmc_session, qq#viosvrcmd -m $managed_system -p $vios -c "lsvopt"#;
   parse_lsvopt($vios, $result_vopt, \%vopt);

   my $result_map = hmc_command $hmc_session, qq#viosvrcmd -m $managed_system -p $vios -c 'lsmap -all -field svsa vtd "Client Partition ID" Physloc -fmt :'#;
   parse_lsmap($vios, $result_map, \%vopt, \%voptmap);
}

warn "main:" . Dumper(%vopt) if $debug;

print "#HMC: \t\t\t$hmc\n";
print "#Managed System:\t$managed_system\n\n";

print "#\n#LIST VIRTUAL OPTICAL DEVICES\n#\n";
if (%vopt) {
  print "#vopt:vios:vhost:physloc:lparid:media\n";
} else {
  print "# no virtual optical devices\n";
}

foreach my $vopt (keys %vopt) {
  my $lparid=$vopt{$vopt}{'lparid'};
  next if check_vopt_lpar($vopt);
  print "$vopt:";
  safe_print "$vopt{$vopt}{'vios'}:";
  safe_print "$vopt{$vopt}{'vhost'}:";
  safe_print "$vopt{$vopt}{'physloc'}:";
  safe_print "$lpar_list{'aixlinux'}{$lparid}:";
  safe_print "$vopt{$vopt}{'media'}";
  print "\n";
}

if ($unloadopt || $remove) {
  print "#\n#UNLOAD VIRTUAL OPTICAL DEVICES\n#\n";
  unless (%vopt) {
    print "# no media loaded \n";
  }
  
  foreach my $vopt (keys %vopt) {
    next if ($vopt{$vopt}{'media'} eq "No");
    next if check_vopt_lpar($vopt);
    check_exec qq#viosvrcmd -m $managed_system -p $vopt{$vopt}{'vios'} -c "unloadopt -vtd $vopt"#;
  }
}

if ($remove) {
  print "#\n#REMOVE VIRTUAL OPTICAL DEVICES\n#\n";
  if (%vopt) { 
    print "# no virtual optical devices\n";
  }

  foreach my $vopt (keys %vopt) {
    next if check_vopt_lpar($vopt);
    next if $vopt{$vopt}{'media'} ne "No";
    check_exec qq#viosvrcmd -m $managed_system -p $vopt{$vopt}{'vios'} -c "rmvdev -vtd $vopt"#;
  }
}

if ($create) {
  warn "main:" . Dumper(%voptmap) if $debug;
  print "#\n#CREATE VIRTUAL OPTICAL DEVICES\n#\n";
  foreach my $lparid (keys %voptmap) {
    next if (defined $voptmap{$lparid}{'status'} );

    my $lpar = $lpar_list{'aixlinux'}{$lparid};

    next if check_lpar($lpar);
    my $longdevname = lc($lpar) . "_cdrom"; 
    my $devname = substr($longdevname, 0, 14);
    check_exec qq#viosvrcmd -m $managed_system -p $voptmap{$lparid}{'vios'} -c "mkvdev -fbo -dev $devname -vadapter $voptmap{$lparid}{'vhost'}"#;
  }
}

  

exit 0;
