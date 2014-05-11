use strict;
use Getopt::Long;
use Data::Dumper;
use JSON;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads 'exit' => 'threads_only';
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
# retries for md5sum, 2 hours
my $md5_retries = 120;
# seconds to wait for a retry
my $cooldown = 60;
# file size
my $previous_size = 0;
# where to look for files matching pattern
my $search_path = ".";

GetOptions (
  "command=s" => \$command,
  "file-grep=s" => \@files,
  "search-path=s" => \$search_path,
  "retries=i" => \$orig_retries,
  "sleep=i" => \$cooldown,
  "md5-retries=i" => \$md5_retries,
);


my $retries = $orig_retries;

print "FILE GREPS: ".join(' ', @files)."\n";

my $thr = threads->create(\&launch_and_monitor, $command);
while(1) {
  if ($thr->is_running()) {
    print "RUNNING\n";
    sleep $cooldown;
    my $currSize = getCurrentSize(@files);
    if($currSize == $previous_size) {
      print "PREVIOUS SIZE UNCHANGED!!! $previous_size\n";
      $retries--;
      if ($retries == 0) {
        $retries = $orig_retries;
        print "KILLING THE THREAD!!\n";
        # kill and wait to exit
        $thr->kill('KILL')->join();
        $thr = threads->create(\&launch_and_monitor, $command);
        sleep ($cooldown * $md5_retries);
      }
    } else {
      $previous_size = $currSize;
      print "SIZE INCREASED!!! $previous_size\n";
    }
  } else {
    print "DONE\n";
    if ($thr->is_running()) { $thr->join(); }
    # then we're done so just exit
    exit(0);
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

sub getCurrentSize {
  my @files = @_;
  my $size = 0;
  foreach my $file(@files) {
    foreach my $actual_file (find_file($file)) {
      chomp $actual_file;
      print "  CONSIDER FILE: $actual_file\n";
      if (-e $actual_file && -f $actual_file) {
        my $stat_out = `stat $actual_file`;
        if ($stat_out =~ /Blocks: (\d+)/) {
          $size += $1;
        }
      }
    }
  }
  print "SIZE: $size\n";
  return($size);
}

sub find_file {
  my ($file) = @_;
  my $output = `find $search_path | grep $file`;
  my @a = split /\n/, $output;
  #print join "\n", @a;
  return(@a);
}
