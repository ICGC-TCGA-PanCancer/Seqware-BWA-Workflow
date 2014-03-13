# README

## Overview

This is the workflow for read/write to GNOS and alignment with BWA.
It also has a perl decider to help launch workflows.

## Dependencies

### Decider

The decider is:

    workflow/scripts/workflow_decider_ebi.pl

It needs the following Perl modules, install them via CPAN if you don't already have them.

* XML::DOM;
* Data::Dumper;
* JSON;

### TODO:

* PCAP-core_20140312 needs to be made into an artifcat
* I feel the read groups should come in from the ini (and therefore come from the XML as parsed by the decider). If not defined then I think it's OK to use read groups from the BAM inputs themselves
* the current ini file includes both tumor and normal, will just want one for a single 'sample'
* need to be updated to BWA-mem and handle the @RG properly
    * https://wiki.oicr.on.ca/display/PANCANCER/BWA+mem+implementation
* update the reference genome to be the correct one
* integrate with https://github.com/ICGC-TCGA-PanCancer/PCAP-core
    * need to calculate md5sum for BAMs
* need to bundle gtdownload 
* need to install https://github.com/ICGC-TCGA-PanCancer/PCAP-core which has dependencies... need to see if theyse can all be taken care of via apt-get
    * apt-get install libbio-samtools-perl

