FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget curl unzip git build-essential \
    zlib1g-dev libbz2-dev liblzma-dev libncurses5-dev libncursesw5-dev \
    python3 python3-pip openjdk-11-jre \
    bowtie2 samtools bedtools awscli \
    perl gzip \
    && apt-get clean

# Install cutadapt (for Trim Galore)
RUN pip3 install cutadapt

# Install Trim Galore (specific stable release)
RUN wget https://github.com/FelixKrueger/TrimGalore/archive/refs/tags/0.6.10.zip \
    && unzip 0.6.10.zip && mv TrimGalore-0.6.10 /opt/trim_galore

# Install Bismark (specific stable release)
RUN wget https://github.com/FelixKrueger/Bismark/archive/refs/tags/0.24.0.zip -O bismark.zip \
    && unzip bismark.zip && mv Bismark-0.24.0 /opt/bismark

# Install FastQC (required by Trim Galore)
RUN wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.9.zip \
    && unzip fastqc_v0.11.9.zip && chmod +x FastQC/fastqc && mv FastQC /opt/fastqc

# Add to PATH
ENV PATH="/opt/trim_galore:/opt/bismark:/opt/fastqc:${PATH}"

# Install UCSC bedGraphToBigWig (static build)
RUN mkdir -p /opt/ucsc && \
    wget http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/bedGraphToBigWig -P /opt/ucsc && \
    chmod +x /opt/ucsc/bedGraphToBigWig && \
    ln -s /opt/ucsc/bedGraphToBigWig /usr/local/bin/bedGraphToBigWig

# Add your pipeline script
COPY rrbs_to_bigwig.sh /usr/local/bin/rrbs_to_bigwig.sh
RUN chmod +x /usr/local/bin/rrbs_to_bigwig.sh

# Confirm shell availability
RUN which sh && which bash

ENTRYPOINT ["bash", "/usr/local/bin/rrbs_to_bigwig.sh"]
