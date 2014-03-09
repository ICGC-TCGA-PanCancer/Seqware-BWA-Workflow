# README

## workflow_decider_ebi.pl

This is a simple perl decider that will query GNOS for a given site and
determine which samples should be launched. Some things to note:

* one instance run per site on an hourly cron, if a previous instance is running the new one should exit
* this needs a cluster.json file that indicates what clusters are available for scheduling
* this program uses multiple threads for launching and monitoring workflows
* the program should operate in a continuous loop, with one workflow per cluster, monitoring the running of the workflows, and should exit when all the possible workflows have completed
* include a test, ignore-lane-count, and force options
* be able to specify just a particular 1) participant or 2) sample ID
* the tool goes through the following basic process:
    * pull all the XML from GNOS
    * parse them into a data structure 
    * classify samples that 1) have all lanes present and 2) do not have an aligned BAM
    * read the cluster JSON, check the cluster nodes for the samples currently running on them
    * loop over each of the cluster nodes, when an unoccupied one is discovered match with an unschedule sample
    * for samples that meet the criteria:
        * prepare ini file
        * schedule the workflow on the available host
    * continue to loop and monitor the cluster until an unoccupied cluster host is disovered
    * continue doing the above until all possible workflows have been scheduled and finished... then exit
    * cron will launch the next round an hour later.

JSON for cluster:

{
  "cluster-name-1": {
     "workflow_accession": "123212312",
     "username": "seqware",
     "password": "seqware",
     "webservice": "https://10.0.0.12:8080/seqware-webservice"
   }
}

## gnos_upload_data.pl

### Dependencies

* cpan install XML::DOM
* cpan install LWP::Protocol::https
* make sure you have curl and wget or lwp-download installed

### Example

    perl gnos_upload_data.pl --metadata-urls https://gtrepo-ebi.annailabs.com/cghub/metadata/analysisFull/4fb18a5a-9504-11e3-8d90-d1f1d69ccc24 --bam /tmp/hadoop-init.log


