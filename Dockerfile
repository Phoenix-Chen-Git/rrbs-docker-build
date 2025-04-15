FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget curl unzip git build-essential zlib1g-dev libbz2-dev liblzma-dev \
    python3 python3-pip openjdk-11-jre bowtie2 samtools bedtools \
    && apt-get clean
RUN pip3 install cutadapt

# Install Trim Galore
RUN wget https://github.com/FelixKrueger/TrimGalore/archive/refs/heads/master.zip \
    && unzip master.zip && mv TrimGalore-master /opt/trim_galore
RUN apt-get update && apt-get install -y awscli

# Install Bismark
RUN wget https://github.com/FelixKrueger/Bismark/archive/refs/heads/master.zip -O bismark.zip \
    && unzip bismark.zip && mv Bismark-master /opt/bismark

# Install FastQC (required by Trim Galore)
RUN wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.9.zip \
    && unzip fastqc_v0.11.9.zip && chmod +x FastQC/fastqc && mv FastQC /opt/fastqc

# Add to PATH
ENV PATH="/opt/trim_galore:/opt/bismark:/opt/fastqc:${PATH}"

# Install bedGraphToBigWig (UCSC tool)
RUN mkdir -p /opt/ucsc && \
    wget http://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64/bedGraphToBigWig -P /opt/ucsc && \
    chmod +x /opt/ucsc/bedGraphToBigWig && \
    ln -s /opt/ucsc/bedGraphToBigWig /usr/local/bin/bedGraphToBigWig

# Add your pipeline script
COPY rrbs_to_bigwig.sh /usr/local/bin/rrbs_to_bigwig.sh
RUN chmod +x /usr/local/bin/rrbs_to_bigwig.sh
RUN which sh && which bash

ENTRYPOINT ["bash", "/usr/local/bin/rrbs_to_bigwig.sh"]
