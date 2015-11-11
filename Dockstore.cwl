#!/usr/bin/env cwl-runner

class: CommandLineTool

description: "The BWA-Mem workflow from the ICGC PanCancer Analysis of Whole Genomes (PCAWG) project.
For more information see the PCAWG project [page](https://dcc.icgc.org/pcawg) and our GitHub 
[page](https://github.com/ICGC-TCGA-PanCancer) for our code including the source for 
[this workflow](https://github.com/ICGC-TCGA-PanCancer/Seqware-BWA-Workflow).

    Usage: workflow-pcawg-bwa-alignment --file <unaligned bam> [--file <unaligned bam>]

"

dct:creator:
  "@id": "http://orcid.org/0000-0002-7681-6415"
  foaf:name: Brian O'Connor
  foaf:mbox: "mailto:briandoconnor@gmail.com"

requirements:
  - class: ExpressionEngineRequirement
    id: "#node-engine"
    requirements:
    - class: DockerRequirement
      dockerPull: commonworkflowlanguage/nodejs-engine
    engineCommand: cwlNodeEngine.js
  - class: DockerRequirement
    dockerPull: quay.io/briandoconnor/dockstore-workflow-pcawg-bwa-alignment:brian_for_dockstore

inputs:
  - id: "#reads"
    type:
      type: array
      items: File
    inputBinding:
      position: 1
      prefix: "--file"

outputs:
  - id: "#bam"
    type: array
    items: File
    outputBinding:
      glob: ["*.bam", "*.bai"]

baseCommand: ["perl", "/home/seqware/Seqware-BWA-Workflow/run_seqware_workflow.pl"]
