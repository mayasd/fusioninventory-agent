package FusionInventory::Agent::Task::Inventory::OS::AIX::Hardware;

use strict;
use warnings;

use FusionInventory::Agent::Tools;

sub isInventoryEnabled {
    return 1;
}

# NOTE:
# Q: SSN can also use `uname -n`? What is the best?
# A: uname -n since it doesn't need root priv

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};
    my $logger    = $params{logger};

    # Using "type 0" section
    my ($SystemSerial, $SystemModel, $BiosVersion, $BiosDate, $fw, $flag);

    # lsvpd
    my @lsvpd = getAllLines(command => 'lsvpd', logger => $logger);
    s/^\*// foreach (@lsvpd);

    #Search Firmware Hard 
    $flag = 0;
    foreach (@lsvpd) {
        if (/^DS Platform Firmware/) {
            $flag = 1;
            next;
        }
        next unless $flag;
        if (/^RM (.+)/) {
            $fw = $1;
            $fw =~ s/(\s+)$//g;
            last;
        }
    }

    $flag = 0;
    foreach (@lsvpd) {
        if (/^DS System Firmware/) {
            $flag = 1;
            next;
        }
        next unless $flag;
        if (/^RM (.+)/) {
            $BiosVersion = $1;
            $BiosVersion =~ s/(\s+)$//g;
            last;
        }
    }

    $flag = 0;
    foreach (@lsvpd) {
        if (/^DS System VPD/) {
            $flag = 1;
            next;
        }
        next unless $flag;
        if (/^TM (.+)/) {
            $SystemModel = $1;
            $SystemModel =~ s/(\s+)$//g;
        }
        if (/^SE (.+)/) {
            $SystemSerial = $1;
            $SystemSerial =~ s/(\s+)$//g;
        }
        if (/^FC .+/) {
            last;
        }
    }

    # fetch the serial number like prtconf do
    if (! $SystemSerial) {
        $flag = 0;
        foreach (`lscfg -vpl sysplanar0`) {
            if (/\s+System\ VPD/) {
                $flag = 1;
                next;
            }
            next unless $flag;
            if ($flag && /\.+(\S*?)$/) {
                $SystemSerial = $1;
                last;
            }
        }
    }

    $BiosVersion .= "(Firmware :".$fw.")";

    # Writing data
    $inventory->setBios({
        SMANUFACTURER => 'IBM',
        SMODEL        => $SystemModel,
        SSN           => $SystemSerial,
        BMANUFACTURER => 'IBM',
        BVERSION      => $BiosVersion,
        BDATE         => $BiosDate,
    });
}

1;
