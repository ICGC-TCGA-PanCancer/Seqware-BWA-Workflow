#!/usr/bin/env cwl-runner

class: CommandLineTool

description: |
The BWA-Mem workflow from the PCAWG project
  Usage: workflow-pcawg-bwa-alignment --file <unaligned bam> [--file <unaligned bam>]

# LEFT OFF WITH: just use zip bundle for this, or docker which has reference already in it since that built

requirements:
  - class: ExpressionEngineRequirement
    id: "#node-engine"
    requirements:
    - class: DockerRequirement
      dockerPull: commonworkflowlanguage/nodejs-engine
    engineCommand: cwlNodeEngine.js
  - class: DockerRequirement
    dockerPull: quay.io/collaboratory/dockstore-tool-bwa-mem

inputs:
  - id: "#reference"
    type: File
    inputBinding:
      position: 2

  - id: "#reads"
    type:
      type: array
      items: File
    inputBinding:
      position: 3

  - id: "#minimum_seed_length"
    type: int
    description: "-k INT        minimum seed length [19]"
    inputBinding:
      position: 1
      prefix: "-k"

  - id: "#min_std_max_min"
    type:
      type: array
      items: int
    inputBinding:
      position: 1
      prefix: "-I"
      itemSeparator: ","

  - id: "#output_name"
    type: string

  - id: "#threads"
    type: ["null",int]
    description: "-t INT        number of threads [1]"
    inputBinding:
      position: 1
      prefix: "-t"

outputs:
  - id: "#sam"
    type: File
    outputBinding:
      glob:
        engine: cwl:JsonPointer
        script: /job/output_name

stdout:
  engine: cwl:JsonPointer
  script: /job/output_name

baseCommand: ["bwa", "mem"]
