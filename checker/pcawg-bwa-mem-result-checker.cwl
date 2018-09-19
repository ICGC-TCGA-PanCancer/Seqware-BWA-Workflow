cwlVersion: v1.0

class: CommandLineTool

hints:
- class: DockerRequirement
  dockerPull: quay.io/baminou/pcawg-bwa-mem-aligner-ga4gh-result-checker:2.0

inputs:
  result_files:
    type:
      type: array
      items: File
    inputBinding:
      position: 1

outputs:
  stdout_log:
    type: File
    outputBinding:
      glob: log.stdout
    doc: File containing result
  stderr_log:
    type: File
    outputBinding:
      glob: log.stderr
    doc: File containing error result

baseCommand: ["bash", "/usr/local/bin/pcawg-bwa-mem-result-checker.sh"]
