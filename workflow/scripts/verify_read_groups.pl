use strict;
use Getopt::Long;

# PURPOSE:
# This script checks consistency of read groups information at the BAM header
# step (before bamtofastq) and the step after bam_stats.pl is run to produce .bas file.
# Error will be thrown if inconsistency is detected.
# These fields will be checked (more, such as insert size, maybe added later): 
#   sample, platform, platform_unit, library, readgroup
# JIRA: https://jira.oicr.on.ca/browse/PANCANCER-47

my $header_file;
my $bas_file;
my $input_read_count_file;

GetOptions (
  "header-file=s" => \$header_file,
  "bas-file=s" => \$bas_file,
  "input-read-count-file=s" => \$input_read_count_file,
);

my $rg_header = &parse_header_file($header_file);
my $rg_bas = &parse_bas_file($bas_file);
my $input_read_count = `cat $input_read_count_file`;
chomp $input_read_count;

# now let's compare read group information from these two files

unless (scalar keys $rg_header == scalar keys $rg_bas) { # first ensure read group counts match
  die "Read group counts unmatch between files: $rg_header and $rg_bas\n";
}

my $read_count_after_bwa = 0;
for (keys $rg_header) {
  my $rg_id = $_;

  die "Read group $rg_id exists in header file: $header_file, but is missing in bas file: $bas_file\n"
    unless defined $rg_bas->{$rg_id};

  # now let's compare values for the following fields
  #  header file: SM PL PU LB
  #  bas file:    sample platform platform_unit library

  die "Sample IDs for read group $rg_id do not match between $header_file and $bas_file"
    unless ($rg_header->{$rg_id}->{SM} eq $rg_bas->{$rg_id}->{sample});

  die "Platform for read group $rg_id do not match between $header_file and $bas_file"
    unless ($rg_header->{$rg_id}->{PL} eq $rg_bas->{$rg_id}->{platform});

  die "Platform unit for read group $rg_id do not match between $header_file and $bas_file"
    unless ($rg_header->{$rg_id}->{PU} eq $rg_bas->{$rg_id}->{platform_unit});

  die "Library name for read group $rg_id do not match between $header_file and $bas_file"
    unless ($rg_header->{$rg_id}->{LB} eq $rg_bas->{$rg_id}->{library});

  $read_count_after_bwa += $rg_bas->{$rg_id}->{'#_total_reads'};
}

die "Read count reported by QC step in $bas_file file does not match read count recorded in $input_read_count_file.\n"
  unless $input_read_count == $read_count_after_bwa;


sub parse_header_file {
  my $header_file = shift;

  open (H, "< $header_file") || die "Could not open specified header file: $header_file\n";
  
  my $rg = {};
  my $current_rg_id;

  while(<H>){
    next unless /^\@RG/;
    s/[\r\n]//g;

    if (/\\tID:(.+?)\\t/ || /\\tID:(.+?)\z/) {
      $current_rg_id = $1;

      die "None unique Read Group ID (or RG ID field appeared more than once in one BAM header line) found in header file: $header_file\n"
          if (defined $rg->{$current_rg_id}) ;

    }else{
      die "No ID field defined (or ID is empty) in the \@RG header line in header file: $header_file\n";
    }
  
    my @F = split /\\t/, $_, -1;
  
    for (@F) {
      next if /^\@RG/;

      if (/^([A-Z]+?):(.*)\z/) {
        my $field = $1;
        my $value = $2;

        $rg->{$current_rg_id}->{$field} = $value;
      }
    }
  }
  
  close (H);

  return $rg;
}

sub parse_bas_file {
  my $bas_file = shift;

  open (S, "< $bas_file") || die "Could not open specified bas file: $bas_file\n";
  
  my @header = split /\t/, <S>;
  chomp @header;

  my $rg = {};

  while(<S>) {
    s/[\r\n]//g;

    my @data = split /\t/, $_, -1;
  
    my $qc_metrics = {};
    $qc_metrics->{$_} = shift @data for (@header);

    if (defined $rg->{$qc_metrics->{readgroup}}) {
      die "Read group ID duplicated in specified bas file: $bas_file\n";
    }else{

      $rg->{ $qc_metrics->{readgroup} } = $qc_metrics;
    }

  }

  close (S);

  return $rg;
}
