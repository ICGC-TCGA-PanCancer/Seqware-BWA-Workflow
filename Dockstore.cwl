#!/usr/bin/env cwl-runner

class: CommandLineTool
id: Seqware-BWA-Workflow
label: Seqware-BWA-Workflow
cwlVersion: v1.0

dct:creator:
  '@id': http://orcid.org/0000-0002-7681-6415
  foaf:name: Brian O'Connor
  foaf:mbox: mailto:briandoconnor@gmail.com
  
dct:contributor:
  foaf:name: Denis Yuen
  foaf:mbox: mailto:denis.yuen@oicr.on.ca

requirements:
- class: DockerRequirement
  dockerPull: quay.io/pancancer/pcawg-bwa-mem-workflow:2.6.8_1.2
- class: InlineJavascriptRequirement

inputs:
  output_file_basename:
    type: string
    inputBinding:
      position: 10
      prefix: --output-file-basename
    doc: the basename to use for output files
  download_reference_files:
    type: string
    inputBinding:
      position: 11
      prefix: --download-reference-files
    doc: should we attempt to download the reference files ["true", "false"]
  reference_gz_fai:
    type: File
    inputBinding:
      position: 3
      prefix: --reference-gz-fai
    doc: the reference *.fa.gz.fai file
  reference_gz:
    type: File
    inputBinding:
      position: 2
      prefix: --reference-gz
    doc: the reference *.fa.gz file
  reference_gz_pac:
    type: File
    inputBinding:
      position: 7
      prefix: --reference-gz-pac
    doc: the reference *.fa.gz.pac file
  reference_gz_amb:
    type: File
    inputBinding:
      position: 4
      prefix: --reference-gz-amb
    doc: the reference *.fa.gz.amb file
  reads:
    type:
      type: array
      items: File
    inputBinding:
      position: 1
      prefix: --files
  reference_gz_bwt:
    type: File
    inputBinding:
      position: 6
      prefix: --reference-gz-bwt
    doc: the reference *.fa.gz.bwt file
  output_dir:
    type: string
    inputBinding:
      position: 9
      prefix: --output-dir
    doc: the output directory
  reference_gz_sa:
    type: File
    inputBinding:
      position: 8
      prefix: --reference-gz-sa
    doc: the reference *.fa.gz.sa file
  reference_gz_ann:
    type: File
    inputBinding:
      position: 5
      prefix: --reference-gz-ann
    doc: the reference *.fa.gz.ann file
outputs:
  merged_output_bai:
    type: File
    outputBinding:
      glob: $(inputs.output_dir + '/' + inputs.output_file_basename + '.bam.bai')
  merged_output_unmapped_metrics:
    type: File
    outputBinding:
      glob: $(inputs.output_dir + '/' + inputs.output_file_basename + '.unmapped.bam.metrics')

  merged_output_bam:
    type: File
    outputBinding:
      glob: $(inputs.output_dir + '/' + inputs.output_file_basename + '.bam')
  merged_output_metrics:
    type: File
    outputBinding:
      glob: $(inputs.output_dir + '/' + inputs.output_file_basename + '.bam.metrics')
  merged_output_unmapped_bai:
    type: File
    outputBinding:
      glob: $(inputs.output_dir + '/' + inputs.output_file_basename + '.unmapped.bam.bai')
  merged_output_unmapped_bam:
    type: File
    outputBinding:
      glob: $(inputs.output_dir + '/' + inputs.output_file_basename + '.unmapped.bam')
baseCommand: [/start.sh , python, /home/seqware/Seqware-BWA-Workflow/run_seqware_workflow.py]
doc: |
  The BWA-Mem workflow from the ICGC PanCancer Analysis of Whole Genomes (PCAWG) project.
  For more information see the PCAWG project [page](https://dcc.icgc.org/pcawg) and our GitHub
  [page](https://github.com/ICGC-TCGA-PanCancer) for our code including the source for
  [this workflow](https://github.com/ICGC-TCGA-PanCancer/Seqware-BWA-Workflow).
