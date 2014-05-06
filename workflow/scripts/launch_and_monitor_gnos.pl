use strict;
use Getopt::Long;
use Data::Dumper;
use JSON;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';

my $command;
my $file;



my $thr = threads->create(\&launch_and_monitor, $command, $file);
while(1) {
  
  sleep 120;
}
$thr->join();
