task Seqware_BWA_Workflow {
    Array[File] reads
    File reference_gz
    File reference_gz_fai
    File reference_gz_amb
    File reference_gz_ann
    File reference_gz_bwt
    File reference_gz_pac
    File reference_gz_sa
		String output-dir

    command {
        python /home/seqware/Seqware-BWA-Workflow/run_seqware_workflow.py \
        --files ${sep=' ' reads} \
				--output-dir ${output_dir} \
        --reference-gz ${reference_gz} \
        --reference-gz-fai ${reference_gz_fai} \
        --reference-gz-amb ${reference_gz_amb} \
        --reference-gz-ann ${reference_gz_ann} \
        --reference-gz-bwt ${reference_gz_bwt} \
        --reference-gz-pac ${reference_gz_pac} \
        --reference-gz-sa ${reference_gz_sa}
    }

    output {
        File merged_output_bam = '${output_dir}/merged_output.bam'
        File merged_output_bai = '${output_dir}/merged_output.bam.bai'
        File merged_output_unmapped_bam = '${output_dir}/merged_output.unmapped.bam'
        File merged_output_unmapped_bai = '${output_dir}/merged_output.unmapped.bam.bai'
    }

    runtime {
        docker: 'seqware-bwa-workflow'
    }
}

workflow Seqware_BWA_Workflow {
    call Seqware_BWA_Workflow
}
