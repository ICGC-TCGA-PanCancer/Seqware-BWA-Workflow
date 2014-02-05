#!/usr/bin/perl

use strict;

my ($link_dir) = @ARGV;

download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.fai");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.amb");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.ann");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.bwt");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.pac");
download("$link_dir/reference/bwa-0.6.2", "http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.sa");
download("$link_dir/testData", "http://s3.amazonaws.com/oicr.bundle.data/pancancer_bwa_workflow/test.genome.read1.fastq.gz");
download("$link_dir/testData", "http://s3.amazonaws.com/oicr.bundle.data/pancancer_bwa_workflow/test.genome.read2.fastq.gz");
download("$link_dir/testData", "https://s3.amazonaws.com/pan-cancer-data/pan-cancer-unaligned-bam-samples/8015_5.bam");
download("$link_dir/testData", "https://s3.amazonaws.com/pan-cancer-data/pan-cancer-unaligned-bam-samples/8031_6.bam");

sub download {
  my ($dir, $url) = @_;
  system("mkdir -p $dir");
  $url =~ /\/([^\/]+)$/;
  my $file = $1;
  if (!-e "$dir/$file" || -l "$dir/$file" || -s "$dir/$file" == 0) {
    my $cmd = "wget $url -O $dir/$file"; 
    print "\nDOWNLOADING: $cmd\nFILE: $file\n\n";
    my $r = system($cmd);
    if ($r != 0) {
      print "+DOWNLOAD FAILED!\n";
      $cmd = "lwp-download $url $dir/$file";
      print "\nDOWNLOADING AGAIN: $cmd\nFILE: $file\n\n";
      my $r = system($cmd);
    }
  }
}

