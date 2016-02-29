task Seqware_BWA_Workflow {
    Array[File] reads
    File reference_gz
    File reference_gz_fai
    File reference_gz_amb
    File reference_gz_ann
    File reference_gz_bwt
    File reference_gz_pac
    File reference_gz_sa

    command {
        sudo chmod -R a+wrx /root ; perl /home/seqware/Seqware-BWA-Workflow/run_seqware_workflow.pl \
        --file ${sep=' ' reads} \
        --reference-gz ${reference_gz} \
        --reference-gz-fai ${reference_gz_fai} \
        --reference-gz-amb ${reference_gz_amb} \
        --reference-gz-ann ${reference_gz_ann} \
        --reference-gz-bwt ${reference_gz_bwt} \
        --reference-gz-pac ${reference_gz_pac} \
        --reference-gz-sa ${reference_gz_sa}
    }

    output {
        File merged_output_bam = 'merged_output.bam'
        File merged_output_bai = 'merged_output.bam.bai'
        File merged_output_unmapped_bam = 'merged_output.unmapped.bam'
        File merged_output_unmapped_bai = 'merged_output.unmapped.bam.bai'
    }

    runtime {
        docker: 'quay.io/collaboratory/seqware-bwa-workflow:wdl_support'
    }
}

workflow Seqware_BWA_Workflow {
    call Seqware_BWA_Workflow
}
