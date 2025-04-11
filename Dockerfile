FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    wget curl unzip git build-essential zlib1g-dev \
    python3 python3-pip openjdk-11-jre \
    bowtie2 samtools bedtools \
    && apt-get clean

# Install Trim Galore
RUN wget https://github.com/FelixKrueger/TrimGalore/archive/refs/tags/0.6.10.zip && \
    unzip 0.6.10.zip && mv TrimGalore-0.6.10 /opt/trim_galore

# Install Bismark
RUN wget https://github.com/FelixKrueger/Bismark/archive/refs/tags/0.24.0.zip && \
    unzip 0.24.0.zip && mv Bismark-0.24.0 /opt/bismark

# Install deeptools (for bamCoverage)
RUN pip3 install deeptools

ENV PATH="/opt/trim_galore:/opt/bismark:$PATH"

WORKDIR /data

CMD ["/bin/bash"]
