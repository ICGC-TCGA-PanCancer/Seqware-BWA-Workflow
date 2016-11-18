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
VOLUME /data
VOLUME /data/reference
VOLUME /data/reference/bwa-0.6.2/

RUN chmod -R a+wrx /data
RUN chown -R seqware /data

# install gosu as an alternative to sudo

ENV GOSU_VERSION 1.9
RUN set -x \
    && apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
    && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

# warning: this gives all future users, unknown and known the ability to gosu
RUN chown root:users /usr/local/bin/gosu && chmod +s /usr/local/bin/gosu

CMD /bin/bash
