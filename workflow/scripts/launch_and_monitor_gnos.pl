#!/usr/bin/env perl

use warnings;
use strict;

use feature qw(say);
use autodie;

use Getopt::Long;

use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads 'exit' => 'threads_only';
use Storable 'dclone';

use Data::Dumper;

my $milliseconds_in_an_hour = 3600000;
# Example Command:
# cd /mnt/seqware-oozie/23f5253a-f33b-11e3-8add-8589c49f5d8e
# perl /mnt/home/seqware/git/genomic_tools/gnos_tools/launch_and_monitor_gnos.pl --command 'gtdownload  --max-children 4 --rate-limit 200 -c /home/seqware/provisioned-bundles/Workflow_Bundle_BWA_2.6.3_SeqWare_1.1.0-alpha.5/Workflow_Bundle_BWA/2.6.3/scripts/gnostest.pem -v -d https://gtrepo-dkfz.annailabs.com/cghub/data/analysis/download/23f5253a-f33b-11e3-8add-8589c49f5d8e' --file-grep 23f5253a-f33b-11e3-8add-8589c49f5d8e --search-path . --md5-retries 120 --retries 30

### setup / INSTALL

# mkdir /mnt/seqware-oozie/23f5253a-f33b-11e3-8add-8589c49f5d8e
# sudo apt-get install libcommon-sense-perl

# PURPOSE:
# the program takes a command (use single quotes to encapsulate it in bash) and
# a comma-delimited list of files to check.  It also takes a retries count and
# cooldown time in seconds.  It then executes the command in a thread and
# watches the files every cooldown time.  For every period where there is no
# change in the output file sizes (one or more) then the retries count is
# decremented.  If there is a change then the retries count is reset the and
# process starts over.  If the retries are exhausted the thread is killed, the
# thread is recreated and started, and the process starts over.

my ($command, @files);
# 30 retries at 60 seconds each is 30 hours
my $orig_retries = 30;
# retries for md5sum, 4 hours
my $md5_retries = 240;
# seconds to wait for a retry
my $cooldown = 60;
# file size
my $previous_size = 0;
# where to look for files matching pattern
my $search_path = ".";

GetOptions (
  "command=s" => \$command,
  "file-grep=s" => \$file,
  "search-path=s" => \$search_path,
  "retries=i" => \$orig_retries,
  "sleep=i" => \$cooldown,
  "md5-retries=i" => \$md5_retries,
);

my $retries = $orig_retries;

say "FILE GREPS: $files";

my $thr = threads->create(\&launch_and_monitor, $command);


my $count = 1;
while(1) {
    sleep $cooldown;
    if ((-e "$file.vcf") or (-e "$file.bam")) {
        say "Total number of tries: $count";
        say 'DONE';
        $thr->join() if ($thr->is_running());
        exit;
    }
    elseif( not $thr->is_running()) { 
        say "PREVIOUS SIZE UNCHANGED!!! $previous_size";
        $count++;
        if ($count <= $retries ) {
            say 'KILLING THE THREAD!!';
            # kill and wait to exit
            $thr->kill('KILL')->join();
            $thr = threads->create(\&launch_and_monitor, $command);
            $retries = $orig_retries;
            sleep $md5_retries;
        }
    }
}

sub launch_and_monitor {
    my ($cmd) = @_;

    my $my_object = threads->self;
    my $my_tid = $my_object->tid;

    local $SIG{KILL} = sub { say "GOT KILL FOR THREAD: $my_tid";
                             threads->exit;
                           };
    # system doesn't work, can't kill it but the open below does allow the sub-process to be killed
    #system($cmd);
    my $pid = open my $in, '-|', "$cmd 2>&1" or die "Can't open command\n";
    my $time_last_downloading = 0;
    my $last_reported_size = 0;
    while(<$in>) { 
        my ($size, $percent, $rate) = $_ =~ m/^Status:\s*(\d+.\d+|\d+|\s*)\s*[M|G]B\s*downloaded\s*\((\d+.\d+|\d+|\s)%\s*complete\)\s*current rate:\s+(\d+.\d+|\d+| )\s+MB\/s/g;

        if ($size > $last_reported_size) {
            $time_last_downloading = time;
        }
        elsif (($time_last_downloading != 0) and ( (time - $time_last_downloading) > $milliseconds_in_an_hour) ) {
            say 'Killing Thread - Timed out';
            exit;
        }
        $last_reported_size = $size;
    }
}

sub get_current_size {
    my ($files) = @_;

    my $size = 0;
    foreach my $actual_file (find_file($file)) {
        chomp $actual_file;
        say "  CONSIDER FILE: $actual_file";
        if (-e $actual_file && -f $actual_file) {
            my $stat_out = `stat $actual_file`;
            if ($stat_out =~ /Blocks: (\d+)/) {
                $size += $1;
            }   
        }
    }
    say "SIZE: $size";

    return $size;
}

sub find_file {
  my ($file) = @_;

  my $find_output = `find $search_path | grep $file`;
  my @a = split /\n/, $find_output;

  return \@a;
}
