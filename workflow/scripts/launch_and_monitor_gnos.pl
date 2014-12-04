#!/usr/bin/env perl

use warnings;
use strict;

use feature qw(say);
use autodie;

use Getopt::Long;

use GNOS::Download;

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

my ($command, $file);
my $cooldown = 60;
my $md5_sleep = 240;
my $retries = 30;

GetOptions (
  "command=s" => \$command,
  "file-grep=s" => \$file,
  "retries=i" => \$retries,
  "sleep=i" => \$cooldown,
  "md5-retries=i" => \$md5_sleep
);

say "FILE: $file";

GNOS::Download->run_download($command, "$file.bam", $retries, $cooldown, $md5_sleep);
