FROM ubuntu:16.04

# File Author / Maintainer
MAINTAINER Brice Aminou <brice.aminou@gmail.com>

USER root

RUN apt-get -yqq update && \
    apt-get -yqq install apt-utils && \
    apt-get -yqq install curl && \
    apt-get -yqq install wget && \
    apt-get -yqq install samtools

COPY pcawg-bwa-mem-result-checker.sh /usr/local/bin/pcawg-bwa-mem-result-checker.sh

RUN chmod a+x /usr/local/bin/pcawg-bwa-mem-result-checker.sh

CMD ["/bin/bash"]
