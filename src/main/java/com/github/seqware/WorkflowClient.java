package com.github.seqware;

import ca.on.oicr.pde.utilities.workflows.OicrWorkflow;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import net.sourceforge.seqware.pipeline.workflowV2.model.Job;
import net.sourceforge.seqware.pipeline.workflowV2.model.SqwFile;

public class WorkflowClient extends OicrWorkflow {

    String input1_path = null;
    String input2_path = null;
    String reference_path = null;
    String outputPrefix = null;
    String outputDir = null;
    String dataDir = "data/";
    String outputFileName = null;
    boolean manualOutput;
    String adapter_Trimming_activated = null;
    String read1_adapterTrim = null;
    String read2_adapterTrim = null;
    String trimmedFile_1;
    String trimmedFile_2;
    //BWA parameters
    String manual_bwa_path;
    String RGID;
    String RGLB;
    String RGPL;
    String RGPU;
    String RGSM;
    String additionalPicardParams;
    int readTrimming; //aln
    int numOfThreads; //aln 
    int pairingAccuracy; //aln
    int maxInsertSize; //sampe
    String readGroup;//sampe
    String bwa_aln_params;
    String bwa_sampe_params;
    SqwFile file0;
    SqwFile file1;
    SqwFile file2;

    String queue; 
    
    @Override
    public Map<String, SqwFile> setupFiles() {

        try {

            input1_path = getProperty("input_file_1");
            input2_path = getProperty("input_file_2");
            reference_path = getProperty("input_reference");
            outputDir = this.getMetadata_output_dir();
            outputPrefix = this.getMetadata_output_file_prefix();
            adapter_Trimming_activated = getProperty("adapter_Trimming_activated");

            manual_bwa_path = getProperty("manual_bwa_path");

            manualOutput = Boolean.valueOf(getProperty("manual_output"));

            RGID = getProperty("RGID");
            RGLB = getProperty("RGLB");
            RGPL = getProperty("RGPL");
            RGPU = getProperty("RGPU");
            RGSM = getProperty("RGSM");
            additionalPicardParams = getProperty("additionalPicardParams");

            queue = getOptionalProperty("queue", "");

            if (adapter_Trimming_activated.equalsIgnoreCase("yes")) {
                read1_adapterTrim = getProperty("read1_adapterTrim");
                read2_adapterTrim = getProperty("read2_adapterTrim");
            }

//            if (!getProperty("manualOutputPath").isEmpty()) {
//                finalOutputDir = outputPrefix
//                        + outputDir
//                        + ("/")
//                        + getProperty("manualOutputPath");
//            } else {
//                finalOutputDir = outputPrefix
//                        + outputDir
//                        + ("/")
//                        + this.getName()
//                        + ("_")
//                        + this.getVersion()
//                        + ("/")
//                        + this.getRandom()
//                        + ("/");
//            }
            if ((getProperty("outputFileName") != null) && (!getProperty("outputFileName").isEmpty())) {
                outputFileName = getProperty("outputFileName");
            } else {
                outputFileName = (input1_path.substring(input1_path.lastIndexOf("/") + 1))
                        + (input2_path.substring(input2_path.lastIndexOf("/") + 1))
                        + (".bam");
            }

        } catch (Exception e) {
            Logger.getLogger(WorkflowClient.class.getName()).log(Level.SEVERE, null, e);
            System.exit(1);
        }

        // registers the first input file
        file0 = this.createFile("file_in_1");
        file0.setSourcePath(input1_path);
        //String[] filepath = input1_path.split(".");
        int dotposition = input1_path.lastIndexOf(".") + 1;
        String fileType = input1_path.substring(dotposition);
        if ("gz".equals(fileType)) {
            file0.setType("chemical/seq-na-fastq-gzip");
        } else if ("fastq".equals(fileType)) {
            file0.setType("chemical/seq-na-fastq");
        } else {
            System.out.println(fileType);
            System.exit(1);

        }

//        
//        if (filepath.length >= 2) {
//            //for (int i = filepath.length; i > filepath.length -1; i--){
//            if (filepath[filepath.length - 1].equals("gz") && filepath[filepath.length - 2].equals("fastq")) {
//                file0.setType("chemical/seq-na-fastq-gzip");
//            } else if (filepath[filepath.length - 1].equals("fastq")) {
//                file0.setType("chemical/seq-na-fastq");
//            }
//        }

        file0.setIsInput(true);

        // registers the second input file 
        file1 = this.createFile("file_in_2");
        file1.setSourcePath(input2_path);
        //String[] filepath = input1_path.split(".");
        int dotposition2 = input2_path.lastIndexOf(".") + 1;
        String fileType2 = input2_path.substring(dotposition2);
        if ("gz".equals(fileType2)) {
            file1.setType("chemical/seq-na-fastq-gzip");
        } else if ("fastq".equals(fileType2)) {
            file1.setType("chemical/seq-na-fastq");
        }
        file1.setIsInput(true);

        file2 = createOutputFile(this.dataDir + outputFileName, "application/bam", manualOutput);

        // registers an output file
//        file2 = this.createFile("file_out");
//        file2.setSourcePath(outputFileName);
//        file2.setType("application/bam");
//        file2.setIsOutput(true);
//        file2.setForceCopy(true);
//        file2.setOutputPath(finalOutputDir + outputFileName);

        return this.getFiles();
    }

    @Override
    public void setupDirectory() {
        // creates the final output 
        this.addDirectory(dataDir);
    }

    @Override
    public void buildWorkflow() {

        Job jobCutAdapt1 = null;
        Job jobCutAdapt2 = null;

        if (adapter_Trimming_activated.equalsIgnoreCase("yes")) {

            jobCutAdapt1 = this.getWorkflow().createBashJob("cutadapt_1");
            jobCutAdapt1.getCommand().addArgument(
                    this.getWorkflowBaseDir()
                    + "/bin/Python-2.7.5/python "
                    + this.getWorkflowBaseDir()
                    + "/bin/cutadapt-1.2.1/bin/cutadapt ");
            jobCutAdapt1.getCommand().addArgument(
                    ("-a ") + read1_adapterTrim + (" "));
            if (file0.getType().equals("chemical/seq-na-fastq-gzip")) {
                jobCutAdapt1.getCommand().addArgument(
                        (" -o ")
                        + input1_path.substring(input1_path.lastIndexOf("/") + 1)
                        + (" ")
                        + this.getFiles().get("file_in_1").getProvisionedPath());
            } else {
                jobCutAdapt1.getCommand().addArgument(
                        this.getFiles().get("file_in_1").getProvisionedPath()
                        + " > "
                        + this.dataDir + input1_path.substring(input1_path.lastIndexOf("/") + 1));
            }

            jobCutAdapt1.setMaxMemory("16000");
            jobCutAdapt1.setQueue(queue);

            jobCutAdapt2 = this.getWorkflow().createBashJob("cutadapt_2");
            jobCutAdapt2.setMaxMemory("16000");
            jobCutAdapt2.setQueue(queue);

            //jobCutAdapt1 = this.getWorkflow().createBashJob("cutadapt_1");


            //jobCutAdapt2 = this.getWorkflow().createBashJob("cutadapt_2");
            jobCutAdapt2.getCommand().addArgument(
                    this.getWorkflowBaseDir()
                    + "/bin/Python-2.7.5/python "
                    + this.getWorkflowBaseDir()
                    + "/bin/cutadapt-1.2.1/bin/cutadapt ");
            jobCutAdapt2.getCommand().addArgument(
                    ("-a ") + read1_adapterTrim + (" "));
            if (file1.getType().equals("chemical/seq-na-fastq-gzip")) {
                jobCutAdapt2.getCommand().addArgument(
                        (" -o ")
                        + this.dataDir + input2_path.substring(input2_path.lastIndexOf("/") + 1)
                        + (" ")
                        + this.getFiles().get("file_in_2").getProvisionedPath());
            } else {
                jobCutAdapt2.getCommand().addArgument(
                        this.getFiles().get("file_in_2").getProvisionedPath()
                        + " > "
                        + this.dataDir + input2_path.substring(input2_path.lastIndexOf("/") + 1));
            }


        }

        Job job01 = this.getWorkflow().createBashJob("bwa_align1");
        Job job02 = this.getWorkflow().createBashJob("bwa_align2");


        // Job job01 = this.getWorkflow().createBashJob("bwa_align1");
        if (!getProperty("manual_bwa_path").isEmpty()) {
            job01.getCommand().addArgument(manual_bwa_path + " aln ");
        } else {
            job01.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa aln ");
        }
        job01.getCommand().addArgument((this.parameters("aln") == null ? " " : this.parameters("aln"))
                + reference_path + (" ")
                + ((adapter_Trimming_activated.equalsIgnoreCase("yes"))
                ? input1_path.substring(input1_path.lastIndexOf("/") + 1)
                : this.getFiles().get("file_in_1").getProvisionedPath())
                + " > " + this.dataDir + "aligned_1.sai 2> aligned_1.err");
        job01.setMaxMemory("16000");
        job01.setQueue(queue);

        if (jobCutAdapt1 != null) {
            job01.addParent(jobCutAdapt1);
        }

        if (!getProperty("manual_bwa_path").isEmpty()) {
            job02.getCommand().addArgument(manual_bwa_path + " aln ");
        } else {
            job02.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa aln ");
        }
        job02.getCommand().addArgument((this.parameters("aln") == null ? " " : this.parameters("aln"))
                + reference_path + (" ")
                + ((adapter_Trimming_activated.equalsIgnoreCase("yes"))
                ? input2_path.substring(input2_path.lastIndexOf("/") + 1)
                : this.getFiles().get("file_in_2").getProvisionedPath())
                + (" > " + this.dataDir + "aligned_2.sai  2> aligned_2.err"));
        job02.setMaxMemory("16000");
        job02.setQueue(queue);
        if (jobCutAdapt2 != null) {
            job02.addParent(jobCutAdapt2);
        }



        Job job03 = this.getWorkflow().createBashJob("bwa_sam_bam");
        if (!getProperty("manual_bwa_path").isEmpty()) {
            job03.getCommand().addArgument(manual_bwa_path + " sampe ");
        } else {
            job03.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa sampe ");
        }
        
        job03.getCommand().addArgument(this.parameters("sampe").isEmpty() ? " " : this.parameters("sampe"));
	job03.getCommand().addArgument(reference_path);
	job03.getCommand().addArgument(this.dataDir + "aligned_1.sai");
	job03.getCommand().addArgument(this.dataDir + "aligned_2.sai");
	job03.getCommand().addArgument((adapter_Trimming_activated.equalsIgnoreCase("yes") ? 
		input1_path.substring(input1_path.lastIndexOf("/") + 1) + (" ") + input2_path.substring(input2_path.lastIndexOf("/") + 1)
                : input1_path + (" ") + input2_path));
	job03.getCommand().addArgument(" > " + this.dataDir + outputFileName + ".norg 2> " +this.dataDir + outputFileName + ".norg.log");

       job03.addParent(job01);
        job03.addParent(job02);
        job03.setQueue(queue);
        job03.setMaxMemory("16000");
       
	Job job04 = this.getWorkflow().createBashJob("addReadGroups");
	job04.getCommand().addArgument("java -Xmx2g -jar "
                + this.getWorkflowBaseDir() + "/bin/picard-tools-1.89/AddOrReplaceReadGroups.jar "
                + " RGID=" + RGID
                + " RGLB=" + RGLB
                + " RGPL=" + RGPL
                + " RGPU=" + RGPU
                + " RGSM=" + RGSM
                + " " + (additionalPicardParams.isEmpty() ? "" : additionalPicardParams)
                + " I=" + this.dataDir + outputFileName + ".norg"
                + " O=" + this.dataDir + outputFileName + " >> "+this.dataDir+outputFileName + ".out 2>> "+this.dataDir+outputFileName +".err");
	job04.addParent(job03);
	job04.setQueue(queue);
	job04.setMaxMemory("8000");
	job04.addFile(file2);
 


//        Job job04 = this.getWorkflow().createBashJob("samToBam_job");
//
//        job04.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/samtools-0.1.19/samtools view -bS "
//                + (this.parameters("view") == null ? " " : this.parameters("view"))
//                + "file_out.sam > "
//                + outputFileName);
//        job04.addParent(job03);
//        job04.addFile(file2);
//        job04.setMaxMemory("16000");

    }

    public String parameters(final String setup) {

        String paramCommand = null;
        StringBuilder a = new StringBuilder();

        try {
            if (setup.equals("aln")) {

                if (!getProperty("readTrimming").isEmpty()) {
                    readTrimming = Integer.parseInt(getProperty("readTrimming"));
                    a.append(" -q ");
                    a.append(readTrimming);
                    a.append(" ");
                }

                if (!getProperty("numOfThreads").isEmpty()) {
                    numOfThreads = Integer.parseInt(getProperty("numOfThreads"));
                    a.append(" -t ");
                    a.append(numOfThreads);
                    a.append(" ");
                }

                if (!getProperty("pairingAccuracy").isEmpty()) {
                    pairingAccuracy = Integer.parseInt(getProperty("pairingAccuracy"));
                    a.append(" -R ");
                    a.append(pairingAccuracy);
                    a.append(" ");
                }
                if (!getProperty("bwa_aln_params").isEmpty()) {
                    bwa_aln_params = getProperty("bwa_aln_params");
                    a.append(" ");
                    a.append(bwa_aln_params);
                    a.append(" ");
                }
                paramCommand = a.toString();
                return paramCommand;
            }

            if (setup.equals("sampe")) {

                if (!getProperty("maxInsertSize").isEmpty()) {
                    maxInsertSize = Integer.parseInt(getProperty("maxInsertSize"));
                    a.append(" -a ");
                    a.append(maxInsertSize);
                    a.append(" ");
                }

                if (!getProperty("readGroup").isEmpty()) {
                    a.append(" -r ");
                    a.append(readGroup);
                    a.append(" ");
                }

                if (!getProperty("bwa_sampe_params").isEmpty()) {
                    bwa_sampe_params = getProperty("bwa_sampe_params");
                    a.append(" ");
                    a.append(bwa_sampe_params);
                    a.append(" ");
                }
                paramCommand = a.toString();
                return paramCommand;
            }

//            if (setup.equals("view")) {
//
//                if (!getProperty("samtools_view_params").isEmpty()) {
//                    samtools_view_params = getProperty("samtools_view_params");
//                    a.append(" ");
//                    a.append(samtools_view_params);
//                    a.append(" ");
//                }
//                paramCommand = a.toString();
//                return paramCommand;
//            }
        } catch (Exception e) {
        }
        return paramCommand;
    }
}
