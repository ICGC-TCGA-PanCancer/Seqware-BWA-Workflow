#!/usr/bin/perl

use strict;

my ($link_dir) = @ARGV;

check_tools();

download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.fai");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.amb");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.ann");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.bwt");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.pac");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.sa");
download("$link_dir/testData", "http://s3.amazonaws.com/oicr.bundle.data/pancancer_bwa_workflow/test.genome.read1.fastq.gz");
download("$link_dir/testData", "http://s3.amazonaws.com/oicr.bundle.data/pancancer_bwa_workflow/test.genome.read2.fastq.gz");
download("$link_dir/testData", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-unaligned-bam-samples/8015_5.bam");
download("$link_dir/testData", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-unaligned-bam-samples/8031_6.bam");

sub download {
  my ($dir, $url) = @_;
  system("mkdir -p $dir");
  $url =~ /\/([^\/]+)$/;
  my $file = $1;

  print "\nDOWNLOADING HEADER:\n\n";
  my $r = `curl -I $url | grep Content-Length`;
  $r =~ /Content-Length: (\d+)/;
  my $size = $1;
  print "\n+REMOTE FILE SIZE: $size\n";
  my $fsize = -s "$dir/$file";
  print "+LOCAL FILE SIZE: $size\n";

  if (!-e "$dir/$file" || -l "$dir/$file" || -s "$dir/$file" == 0 || -s "$dir/$file" != $size) {
    my $cmd = "wget -c -O $dir/$file $url"; 
    print "\nDOWNLOADING: $cmd\nFILE: $file\n\n";
    my $r = system($cmd);
    if ($r) {
      print "+DOWNLOAD FAILED!\n";
      $cmd = "lwp-download $url $dir/$file";
      print "\nDOWNLOADING AGAIN: $cmd\nFILE: $file\n\n";
      my $r = system($cmd);
      if ($r) {
        die ("+SECOND DOWNLOAD FAILED! GIVING UP!\n");
      }
    }
  }
}

sub check_tools {
  if (system("which curl") || (system("which lwp-download") && system("which wget"))) {
    die "+TOOLS NOT FOUND: Can't find curl and/or one of lwp-download and wget, please make sure these are installed and in your path!\n";
  }
}
