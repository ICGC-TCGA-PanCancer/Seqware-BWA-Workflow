use strict;
use Getopt::Long;
use Data::Dumper;
use JSON;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads 'exit' => 'threads_only';
use Storable 'dclone';

# PURPOSE:
# This tool launches a given command line program, monitors the exit code, and
# retries a fixed number of times if the program fails.  It's designed
# to use the -k parameter of gtdownload/gtupload which will cause the code to
# timeout after a specified number of minutes (by default it doesn't).
# This wrapper script will detect the timeout and retry for a fixed number of
# tries.  It's written more generically so you can use it with any long-running,
# error prone process but if you use it with gtdownload/upload make sure you
# include the -k parameter!

my $command;
my $orig_retries = 30;
my $cooldown = 60;

GetOptions (
  "command=s" => \$command,
  "retries=i" => \$orig_retries,
  "sleep=i" => \$cooldown,
);

my $retries = $orig_retries;

my $thr = threads->create(\&launch_and_monitor, $command);

while(1) {
  if ($thr->is_running()) {
    print "RUNNING\n";
    sleep $cooldown;
  } else {
    print "DONE\n";
    if (my $err = $thr->error()) {
      $retries--;
      if ($retries <= 0) {
        die("THREAD ERROR: $err\n");
      } else {
        $thr->kill('KILL')->join();
        $thr = threads->create(\&launch_and_monitor, $command);
      }
    } else {
      $thr->join();
      # then we're done so just exit
      exit(0);
    }
  }
}

sub launch_and_monitor {
  my ($cmd) = @_;
  my $myobject = threads->self;
  my $mytid= $myobject->tid;

  local $SIG{KILL} = sub { print "GOT KILL FOR THREAD: $mytid\n"; threads->exit };
  # system doesn't work, can't kill it but the open below does allow the sub-process to be killed
  #system($cmd);
  my $pid = open my $in, '-|', "$cmd 2>&1" or die "Can't open command\n";
  while(<$in>) { print $_; }
}

0;
