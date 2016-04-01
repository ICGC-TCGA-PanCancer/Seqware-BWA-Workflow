############################################################
# Dockerfile to build BWA-Mem workflow container
# Based on Ubuntu
############################################################

# Set the base image to the SeqWare PanCancer image
FROM pancancer/seqware_whitestar_pancancer:1.1.2

# File Author / Maintainer
MAINTAINER "Brian O'Connor <briandoconnor@gmail.com>"

USER root
RUN apt-get -m update

RUN apt-get install -y apt-utils tar git curl nano wget dialog net-tools build-essential time tabix

COPY src /home/seqware/Seqware-BWA-Workflow/src
COPY workflow /home/seqware/Seqware-BWA-Workflow/workflow
COPY pom.xml /home/seqware/Seqware-BWA-Workflow/
COPY workflow.properties /home/seqware/Seqware-BWA-Workflow/
COPY scripts/run_seqware_workflow.pl /home/seqware/Seqware-BWA-Workflow/
COPY scripts/run_seqware_workflow.py /home/seqware/Seqware-BWA-Workflow/

RUN chmod a+x /home/seqware/Seqware-BWA-Workflow/run_seqware_workflow.pl
RUN chmod a+x /home/seqware/Seqware-BWA-Workflow/run_seqware_workflow.py

ENV SEQWARE_ROOT="root"
WORKDIR /home/seqware/Seqware-BWA-Workflow/

RUN mvn -B clean install

VOLUME /output/
VOLUME /datastore/
VOLUME /home/seqware

CMD /bin/bash
