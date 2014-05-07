# README

## Overview

This is the SeqWare workflow for the TCGA/ICGC PanCancer project that aligns
whole genome sequences with BWA-Mem.  It also reads/writes to GNOS, the metadata/data
repository system used in the project.
For more information about the workflow see the properties file 
[workflow.properties](workflow.properties) which includes background information
 and a change log from the previous version.

For more information about the project overall see the 
[PanCancer wiki space](https://wiki.oicr.on.ca/display/PANCANCER/PANCANCER+Home).

## Building the Workflow

This workflow (like other SeqWare workflows) is built using Maven.  In the
workflow directory (workflow-bwa-pancancer), execute the following:

    mvn clean install

This will take a long time on first build since it download dependencies from Maven 
and the reference genome which is 5GB+ in size.

## Installation & Running

This is beyond the scope of this README.  Instead, you can see the SeqWare project pages for information on installing and running the workflow.  Briefly, you need a VM (local on VirtualBox, on a cloud like AWS, or a private cloud like OpenStack) to run this workflow.  We have pre-made VMs for Amazon and VirtualBox.  For other environments you can use [Bindle](https://github.com/CloudBindle/Bindle) to create a VM or cluster of VMs that are capable of running this workflow. See:

* [Setting up a SeqWare VM or Running in a Cloud](http://seqware.github.io/docs/2-installation/)
* [Testing, Installing, and Running a SeqWare Workflow](http://seqware.github.io/docs/3-getting-started/)

Feel free to email our [mailing list](http://seqware.github.io/community/) if you have questions.

## Authors

* Brian O'Connor <boconnor@oicr.on.ca>
* Junjun Zhang <Junjun.Zhang@oicr.on.ca>

## Contributors

* Keiran Raine: PCAP-Core and BWA-Mem workflow design
* Roshaan Tahir: Original BWA-Align workflow design 

