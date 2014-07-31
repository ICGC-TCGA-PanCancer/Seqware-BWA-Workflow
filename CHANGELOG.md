# ChangeLog

## Overview

This is the changelog for the release of the BWA workflow used for the
ICGC/TCGA PanCancer project.

## Release 2.6.0

You can find these tickets at the OICR JIRA: https://jira.oicr.on.ca. Here are the items addressed in the 2.6.0 release:

* [PANCANCER-6](https://jira.oicr.on.ca/browse/PANCANCER-6) - Metadata: include workflow version string in XML attr
* [PANCANCER-8](https://jira.oicr.on.ca/browse/PANCANCER-8) - Workflow: BAI upload added
* [PANCANCER-9](https://jira.oicr.on.ca/browse/PANCANCER-9) - Workflow: unaligned BAM reads file, separate analysis.xml!
* [PANCANCER-17](https://jira.oicr.on.ca/browse/PANCANCER-17) - per base coverage file
* [PANCANCER-18](https://jira.oicr.on.ca/browse/PANCANCER-18) - Take a pass at cleanup of analysis.xml, there are a few outstanding issues by Keiran
* [PANCANCER-23](https://jira.oicr.on.ca/browse/PANCANCER-23) - Add configurable parameter in ini file for number of children for gtdownload
* [PANCANCER-24](https://jira.oicr.on.ca/browse/PANCANCER-24) - Add more qc metrics using samtools flagstat
* [PANCANCER-25](https://jira.oicr.on.ca/browse/PANCANCER-25) - Failure on pipe fail
* [PANCANCER-32](https://jira.oicr.on.ca/browse/PANCANCER-32) - Add check for valid PI field in BAM headers
* [PANCANCER-33](https://jira.oicr.on.ca/browse/PANCANCER-33) - Add to description
* [PANCANCER-34](https://jira.oicr.on.ca/browse/PANCANCER-34) - Flag to use original quality scores
* [PANCANCER-35](https://jira.oicr.on.ca/browse/PANCANCER-35) - Are we correctly capturing duplicate removal metrics?
* [PANCANCER-39](https://jira.oicr.on.ca/browse/PANCANCER-39) - Analysis Pipeline Section Expansion
* [PANCANCER-42](https://jira.oicr.on.ca/browse/PANCANCER-42) - Broken XML for run.xml
* [PANCANCER-43](https://jira.oicr.on.ca/browse/PANCANCER-43) - Metadata: include workflow runtime into XML key-values
* [PANCANCER-44](https://jira.oicr.on.ca/browse/PANCANCER-44) - Add gtdownload wrapper support for using the timeout parameter
* [PANCANCER-45](https://jira.oicr.on.ca/browse/PANCANCER-45) - Fastq Read Name Checking
* [PANCANCER-47](https://jira.oicr.on.ca/browse/PANCANCER-47) - BAM QC metrics are calculated but never validated
* [PANCANCER-49](https://jira.oicr.on.ca/browse/PANCANCER-49) - BWA workflow, add code to generate md5sum for bai file
* [PANCANCER-51](https://jira.oicr.on.ca/browse/PANCANCER-51) - BWA workflow, upgrade PCAP-core dependent to v1.1.1
* [PANCANCER-52](https://jira.oicr.on.ca/browse/PANCANCER-52) - BWA workflow - track read counts from input BAMs and major workflow steps, error out if reads missed
* [PANCANCER-53](https://jira.oicr.on.ca/browse/PANCANCER-53) - BWA workflow, add step to parse bammarkduplicates metrics report file into JSON and add to Analysis XML
* [PANCANCER-56](https://jira.oicr.on.ca/browse/PANCANCER-56) - Evaluate other reference files to add to Workflow
