use strict;
use Getopt::Long;
use Data::Dumper;
use JSON;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';

# PURPOSE:
# the program takes a command (use single quotes to encapsulate it in bash) and
# a comma-delimited list of files to check.  It also takes a retries count and
# cooldown time in seconds.  It then executes the command in a thread and
# watches the files every cooldown time.  For every period where there is no
# change in the output file sizes (one or more) then the retries count is
# decremented.  If there is a change then the retries count is reset the and
# process starts over.  If the retries are exhausted the thread is killed, the
# thread is recreated and started, and the process starts over.

my $command;
my @files;
# 30 retries at 60 seconds each is 0.5 hours
my $orig_retries = 30;
my $retries = $orig_retries;
# seconds
my $cooldown = 60;
# file size
my $previous_size = 0;

GetOptions (
  "command=s" => \$command,
  "files=s" => \@files,
);

my $thr = threads->create(\&launch_and_monitor, $command);
while(1) {
  if ($thr->is_running()) {   
    sleep $cooldown;
    if(getCurrentSize(@files) == $previous_size) {
      $retries--;
      if ($retries == 0) {
        $retries = $orig_retries;
        $thr->kill('KILL')->detach();
        $thr = threads->create(\&launch_and_monitor, $command);
        sleep $cooldown;
      }
    } else {
      $previous_size = getCurrentSize(@files);
    }
  } else {
    # then we're done so just exit
    exit(0);
  }
}

sub launch_and_monitor {
  my ($cmd) = @_;
  system($cmd);
}

sub getCurrentSize {
  my @files = @_;
  my $size = 0;
  foreach my $file(@files) {
    $size += -s $file;
  }
  return($size);
}
