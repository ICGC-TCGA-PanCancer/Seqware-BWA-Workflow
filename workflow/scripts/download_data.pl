#!/usr/bin/perl

use strict;

my ($link_dir) = @ARGV;

download("$link_dir/reference/bwa-0.6.2", "https://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz");
download("$link_dir/reference/bwa-0.6.2", "https://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.fai");
download("$link_dir/reference/bwa-0.6.2", "https://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.amb");
download("$link_dir/reference/bwa-0.6.2", "https://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.ann");
download("$link_dir/reference/bwa-0.6.2", "https://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.bwt");
download("$link_dir/reference/bwa-0.6.2", "https://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.pac");
download("$link_dir/reference/bwa-0.6.2", "https://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.sa");
#download("$link_dir/reference/bwa-0.6.2", "https://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz.64.sa");

sub download {
  my ($dir, $url) = @_;
  system("mkdir -p $dir");
  $url =~ /\/([^\/]+)$/;
  my $file = $1;
  if (!-e "$dir/$file" || -l "$dir/$file") {
    my $cmd = "wget $url -O $dir/$file"; 
    print "DOWNLOADING: $cmd FILE $file\n";
    system($cmd);
  }
}

