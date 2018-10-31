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

    PCAWG uniform alignment workflow uses the popular short read aligner tool BWA MEM (https://github.com/lh3/bwa)
    with BioBAMBAM (https://github.com/gt1/biobambam) for BAM sorting, merging and marking duplicate.
    The alignment workflow has been dockerized and packaged using CWL workflow language, the source code
    is available on GitHub at: https://github.com/ICGC-TCGA-PanCancer/Seqware-BWA-Workflow.

    ## Run the workflow with your own data
    ### Prepare compute environment and install software packages
    The workflow has been tested in Ubuntu 16.04 Linux environment with the following hardware
    and software settings.

    #### Hardware requirement (assuming 30X coverage whole genome sequence)
    - CPU core: 16
    - Memory: 64GB
    - Disk space: 1TB

    #### Software installation
    - Docker (1.12.6): follow instructions to install Docker https://docs.docker.com/engine/installation
    - CWL tool
    ```
    pip install cwltool==1.0.20170217172322
    ```

    ### Prepare input data
    #### Input unaligned BAM files

    The workflow uses lane-level unaligned BAM files as input, one BAM per lane (aka read group).
    Please ensure *@RG* field is populated properly in the BAM header, the following is a
    valid *@RG* entry. *ID* field has to be unique among your dataset.
    ```
    @RG	ID:WTSI:9399_7	CN:WTSI	PL:ILLUMINA	PM:Illumina HiSeq 2000	LB:WGS:WTSI:28085	PI:453	SM:f393ba16-9361-5df4-e040-11ac0d4844e8	PU:WTSI:9399_7	DT:2013-03-18T00:00:00+00:00
    ```
    Multiple unaligned BAMs from the same sample (with same *SM* value) should be run together. *SM* is
    globally unique UUID for the sample. Put the input BAM files in a subfolder. In this example,
    we have two BAMs in a folder named *bams*.


    #### Reference genome sequence files

    The reference genome files can be downloaded from the ICGC Data Portal at
    under https://dcc.icgc.org/releases/PCAWG/reference_data/pcawg-bwa-mem. Please download all
    reference files and put them under a subfolder called *reference*.

    #### Job JSON file for CWL

    Finally, we need to prepare a JSON file with input, reference and output files specified. Please
    replace the *reads* parameter with your real BAM file name.

    Name the JSON file: *pcawg-bwa-mem-aligner.job.json*
    ```
    {
      "reads": [
        {
          "path":"bams/seq_from_normal_sample_A.lane_1.bam",
          "class":"File"
        },
        {
          "path":"bams/seq_from_normal_sample_A.lane_2.bam",
          "class":"File"
        }
      ],
      "output_dir": "datastore",
      "output_file_basename": "seq_from_normal_sample_A",
      "reference_gz_amb": {
        "path": "reference/genome.fa.gz.64.amb",
        "class": "File"
      },
      "reference_gz_sa": {
        "path": "reference/genome.fa.gz.64.sa",
        "class": "File"
      },
      "reference_gz_pac": {
        "path": "reference/genome.fa.gz.64.pac",
        "class": "File"
      },
      "reference_gz_ann": {
        "path": "reference/genome.fa.gz.64.ann",
        "class": "File"
      },
      "reference_gz_bwt": {
        "path": "reference/genome.fa.gz.64.bwt",
        "class": "File"
      },
      "reference_gz_fai": {
        "path": "reference/genome.fa.gz.fai",
        "class": "File"
      },
      "reference_gz": {
        "path": "reference/genome.fa.gz",
        "class": "File"
      }
    }
    ```

    ### Run the workflow
    #### Option 1: Run with CWL tool
    - Download CWL workflow definition file
    ```
    wget -O pcawg-bwa-mem-aligner.cwl "https://raw.githubusercontent.com/ICGC-TCGA-PanCancer/Seqware-BWA-Workflow/2.6.8_1.3/Dockstore.cwl"
    ```

    - Run *cwltool* to execute the workflow
    ```
    nohup cwltool --debug --non-strict pcawg-bwa-mem-aligner.cwl pcawg-bwa-mem-aligner.job.json > pcawg-bwa-mem-aligner.log 2>&1 &
    ```

    #### Option 2: Run with the Dockstore CLI
    See the *Launch with* on the next tab for details
