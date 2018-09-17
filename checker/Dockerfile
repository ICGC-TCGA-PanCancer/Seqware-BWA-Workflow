FROM ubuntu:16.04

# Metadata
LABEL base.image="ubuntu:16.04"
LABEL version="2"
LABEL software="PCAWG BWA mem Aligner Result Checker"
LABEL website="https://github.com/ICGC-TCGA-PanCancer/GA4GH-DREAM_Workflow_Execution_Challenge/tree/bwa-mem-v2/pcawg-bwa-mem-aligner/checker"

# File Author / Maintainer
MAINTAINER Brice Aminou <brice.aminou@gmail.com>

USER root

RUN apt-get -yqq update && \
    apt-get -yqq install apt-utils && \
    apt-get -yqq install curl && \
    apt-get -yqq install wget && \
    apt-get -yqq install samtools

RUN wget https://raw.githubusercontent.com/ICGC-TCGA-PanCancer/GA4GH-DREAM_Workflow_Execution_Challenge/bwa-mem-v2/pcawg-bwa-mem-aligner/checker/pcawg-bwa-mem-result-checker.sh && \
    mv pcawg-bwa-mem-result-checker.sh /usr/local/bin/

#COPY pcawg-bwa-mem-result-checker.sh /usr/local/bin/pcawg-bwa-mem-result-checker.sh

RUN chmod a+x /usr/local/bin/pcawg-bwa-mem-result-checker.sh

CMD ["/bin/bash"]
