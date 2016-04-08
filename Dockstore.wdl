task Seqware_BWA_Workflow {
    Array[File] reads
    File reference_gz
    File reference_gz_fai
    File reference_gz_amb
    File reference_gz_ann
    File reference_gz_bwt
    File reference_gz_pac
    File reference_gz_sa
		String output_dir
    String output_file_basename
    String download_reference_files

    command {
        python /home/seqware/Seqware-BWA-Workflow/run_seqware_workflow.py \
        --files ${sep=' ' reads} \
				--output-dir ${output_dir} \
        --output-file-basename ${output_file_basename} \
        --download-reference-files ${download_reference_files} \
        --reference-gz ${reference_gz} \
        --reference-gz-fai ${reference_gz_fai} \
        --reference-gz-amb ${reference_gz_amb} \
        --reference-gz-ann ${reference_gz_ann} \
        --reference-gz-bwt ${reference_gz_bwt} \
        --reference-gz-pac ${reference_gz_pac} \
        --reference-gz-sa ${reference_gz_sa}
    }

    output {
        File merged_output_bam = '${output_dir}/${output_file_basename}.bam'
        File merged_output_bai = '${output_dir}/${output_file_basename}.bam.bai'
        File merged_output_metrics = '${output_dir}/${output_file_basename}.bam.metrics'
        File merged_output_unmapped_bam = '${output_dir}/${output_file_basename}.unmapped.bam'
        File merged_output_unmapped_bai = '${output_dir}/${output_file_basename}.unmapped.bam.bai'
        File merged_output_unmapped_metrics = '${output_dir}/${output_file_basename}.unmapped.bam.metrics'
    }

    runtime {
        docker: 'seqware-bwa-workflow'
    }
}

workflow Seqware_BWA_Workflow {
    call Seqware_BWA_Workflow
}
