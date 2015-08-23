#!/usr/bin/perl
# author: Alain Dejoux<adejoux@djouxtech.net>
# description: manage vopt creation and deletion
# license : MIT
# version : 0.6
# date : August 22th 2015

use strict;
use warnings;
use Getopt::Long ();
use lib '/usr/local/vopt_manager/lib';
use Net::OpenSSH;
use Data::Dumper::Simple;
use Term::ReadKey;

# variables
my $debug  = 0;
my $hmc_user = "hscroot";

my ($list, $unloadopt, $remove, $create, $exec, $managed_system, $hmc, $hmc_session, $lpars, $vio_servers, $pass, $password);
my (%lpar_list, %voptmap,  %vopt, %lpar_names, %vio_names);

Getopt::Long::GetOptions(
    'hmc|h=s' => \$hmc,
    'user|u=s' => \$hmc_user,
    'm=s' => \$managed_system,
    'lpar=s' => \$lpars,
    'vio=s' => \$vio_servers,
    'pass' => \$pass,
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
    "usage: $command -m managed_system -h hmc [-u user] [-p] [-vio vio1,vio2] [-lpar lpar1,lpar2] [-list|-unload|-remove|-create] [-exec] \n" .
    "       -h hmc: remote hmc. Hostname or IP address\n" .
    "       -m managed_system: system to manage\n" .
    "       -u user: hmc user\n" .
    "       -p : prompt for hmc user password\n" .
    "       -lpar lpar1,lpar2: list of the partitions where to perform the action\n" .
    "       -vio vio1,vio2: list of the vio servers where to perform the action\n" .
    "       -list: list existing VOPT \n" .
    "       -unload: unload media from existing VOPT \n" .
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

  my $err_out;

  warn whoami() . ":" . Dumper($cmd) if $debug;
  my ($stdout, $stderr) = $session->capture2({timeout => 120}, $cmd);
  warn whoami() . ":" . Dumper($stdout) if $debug;

  unless ($session->error) {
    return $stdout;
  }

  if ($error_msg) {
    $err_out = "$error_msg\n";
  } else {
    $err_out = "$stdout\n$stderr\n";
  }

  return $stdout,$err_out;
}

sub managed_system_validate {
  my ($session, $managed_system) = @_;
  my ($stdout, $errmsg) = hmc_command($session,
              "lssyscfg -r sys -m $managed_system -F name",
              "Managed System $managed_system does not exist. Please enter a valid Managed System name.\n");
  if ($errmsg) {
    die $errmsg;
  }

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

      $$refvopt{$vios}{$vtd}{'media'} = $media;
      $$refvopt{$vios}{$vtd}{'size'} = $size;
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
    foreach my $vopt (keys %{$$refvopt{$vios}}) {
      if ( $line =~ /(vhost\d+):(0x[^:]+):([^:]+):.*$vopt/ ) {
        warn whoami() . " parse vopt mapping:" .  $line if $debug;
        $$refvopt{$vios}{$vopt}{'vhost'}= $1;
        my $lparid = sprintf("%d", hex($2));
        if ($lparid > 0) {
          $$refvopt{$vios}{$vopt}{'lparid'}= $lparid;
          $$refvoptmap{$lparid}{$vios}{'status'} = "YES";
        }
        $$refvopt{$vios}{$vopt}{'physloc'}= $3;
        $status = 1;
      }
    }
    next if ($status);

    if ( $line =~ /(vhost\d+):(0x[^:]+):([^:]+):/ ) {
      warn whoami() . " parse NO vopt mapping:" .  $line if $debug;
      my $lparid = sprintf("%d", hex($2));
      next if $lparid == 0;
      $$refvoptmap{$lparid}{$vios}{'vhost'} = $1;
    }
  }
}

sub whoami  { ( caller(1) )[3] }

sub check_exec {
  my ($lpar, $cmd) = @_;
  if ($exec) {
    if (defined $lpar) {
      print "#hmc command executed for lpar $lpar : " . $cmd . "\n";
    } else {
      print "#hmc command executed : " . $cmd . "\n";
    }

    my ($stdout, $errmsg) = hmc_command $hmc_session, $cmd;
    if ($errmsg) {
      die $errmsg;
    }
    return
  }
  if (defined $lpar) {
    print "#generated command(not run) for lpar $lpar : $cmd \n";
    return
  }
  print "#generated command(not run) : $cmd \n";
}

sub safe_print {
  my $msg = shift;
  my $sep = shift;

  if (not defined $msg) {
    print "N/F";
  } else {
    print $msg;
  }

  print $sep if defined($sep);
}

sub check_vopt_lpar {
  my ($vios, $vopt) = @_;

  my $lparid=$vopt{$vios}{$vopt}{'lparid'};

  if (not defined $lparid) {
    return 1;
  }
  my $lpar=$lpar_list{'aixlinux'}{$lparid};

  return check_lpar($lpar);
}

sub check_lpar {
  my $lpar = shift;

  return 0 unless (%lpar_names);
  return 0 if ($lpar_names{$lpar});

  warn whoami() . ":  lpar $lpar skipped !\n" if $debug;
  return 1;
}

sub check_vio {
  my $vio = shift;

  return 0 unless (%vio_names);
  return 0 if ($vio_names{$vio});

  warn whoami() . ":  vio $vio skipped !\n" if $debug;
  return 1;

}

sub get_lpar {
  my ($vios, $lparid) = @_;

  my $lpar = $lpar_list{'aixlinux'}{$lparid};

  if (defined $lpar) {
    return $lpar
  }
}

#
# Main
#

validate_args();

if ($pass) {
  printf "Password:\n";
  ReadMode('noecho');
  $password =  <STDIN>;
  ReadMode(0);
}

if ($lpars) {
  my @entries=split /,/, $lpars;
  foreach my $entry (@entries) {
    chomp($entry);
    $lpar_names{$entry}=1;
  }
}

if ($vio_servers) {
  my @entries=split /,/, $vio_servers;
  foreach my $entry (@entries) {
    chomp($entry);
    $vio_names{$entry}=1;
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
   next if check_vio($vios);

   print "#Getting the virtual optical devices list for vios $vios\n" if $debug;
   my ($result_vopt, $errmsg) = hmc_command $hmc_session, qq#viosvrcmd -m $managed_system -p $vios -c "lsvopt"#;
   if ($errmsg) {
     print "#ERROR running lsvopt on VIOS $vios : $errmsg";
     next;
   }
   parse_lsvopt($vios, $result_vopt, \%vopt);

   my $result_map;
   print "#Getting the vscsi mapping on vios $vios\n" if $debug;
   ($result_map, $errmsg) = hmc_command $hmc_session, qq#viosvrcmd -m $managed_system -p $vios -c 'lsmap -all -field svsa vtd "Client Partition ID" Physloc -fmt :'#;
   if ($errmsg) {
      print "#ERROR running lsmap on VIOS $vios : $errmsg";
      next;
   }
   parse_lsmap($vios, $result_map, \%vopt, \%voptmap);
}

warn "main:" . Dumper(%vopt) if $debug;

print "#HMC: \t\t\t$hmc\n";
print "#Managed System:\t$managed_system\n\n";

print "#\n#LIST VIRTUAL OPTICAL DEVICES\n#\n";
if (%vopt) {
  print "#vopt:vios:vhost:physloc:lparid:lpar:media\n";
} else {
  print "# no virtual optical devices\n";
}


foreach my $vios (sort keys %vopt) {
  foreach my $vopt (sort keys %{$vopt{$vios}}) {
    my $lparid=$vopt{$vios}{$vopt}{'lparid'};
    next if check_vopt_lpar($vios, $vopt);
    print "$vopt:";
    safe_print $vios, ":";
    safe_print $vopt{$vios}{$vopt}{'vhost'}, ":";
    safe_print $vopt{$vios}{$vopt}{'physloc'}, ":";
    safe_print $lparid, ":";
    safe_print $lpar_list{'aixlinux'}{$lparid}, ":";
    safe_print $vopt{$vios}{$vopt}{'media'};
    print "\n";
  }
}

if ($unloadopt || $remove) {
  print "#\n#UNLOAD VIRTUAL OPTICAL DEVICES\n#\n";
  unless (%vopt) {
    print "# no media loaded \n";
  }
  foreach my $vios (sort keys %vopt) {
    foreach my $vopt (sort keys %{$vopt{$vios}}) {
      next if ($vopt{$vios}{$vopt}{'media'} eq "No");
      next if check_vopt_lpar($vios, $vopt);
      my $lpar = get_lpar($vios, $vopt{$vios}{$vopt}{'lparid'});
      check_exec $lpar, qq#viosvrcmd -m $managed_system -p $vios -c "unloadopt -vtd $vopt"#;
    }
  }
}

if ($remove) {
  print "#\n#REMOVE VIRTUAL OPTICAL DEVICES\n#\n";
  unless (%vopt) {
    print "# no virtual optical devices\n";
  }
  foreach my $vios (sort keys %vopt) {
      foreach my $vopt (sort keys %{$vopt{$vios}}) {
      next if check_vopt_lpar($vios, $vopt);
      next if $vopt{$vios}{$vopt}{'media'} ne "No";
      my $lpar = get_lpar($vios, $vopt{$vios}{$vopt}{'lparid'});
      check_exec $lpar, qq#viosvrcmd -m $managed_system -p $vios -c "rmvdev -vtd $vopt"#;
    }
  }
}

if ($create) {
  warn "main:" . Dumper(%voptmap) if $debug;
  print "#\n#CREATE VIRTUAL OPTICAL DEVICES\n#\n";
  foreach my $lparid (keys %voptmap) {
    foreach my $vios ( @vio_list ) {
      warn  "vio: $vios\n" if $debug;
      next if check_vio($vios);
      next if (defined $voptmap{$lparid}{$vios}{'status'} );

      my $lpar = $lpar_list{'aixlinux'}{$lparid};

      next if not defined($lpar);
      next if check_lpar($lpar);
      my $longdevname = lc($lpar) . "_cd";
      my $devname = substr($longdevname, 0, 14);

      check_exec $lpar, qq#viosvrcmd -m $managed_system -p $vios -c "mkvdev -fbo -dev $devname -vadapter $voptmap{$lparid}{$vios}{'vhost'}"#;
    }
  }
}

exit 0;
