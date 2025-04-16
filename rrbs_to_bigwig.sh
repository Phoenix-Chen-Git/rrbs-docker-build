#!/bin/bash
set -e

echo "🚀 RRBS parallel pipeline using 16 CPUs"

# Directory setup
FASTQ_DIR=/data/fastq
GENOME_DIR=/data/genome
TRIM_DIR=/data/trimmed
ALIGN_DIR=/data/aligned
RESULT_DIR=/data/results
THREADS=16
SAMPLE_THREADS=4
MAX_JOBS=$((THREADS / SAMPLE_THREADS))

mkdir -p $FASTQ_DIR $GENOME_DIR $TRIM_DIR $ALIGN_DIR $RESULT_DIR

# Step 1: Download FASTQ (already downloaded, skip if present)
cd $FASTQ_DIR
[[ ! -f ENCFF000MBP.fastq.gz ]] && wget -O ENCFF000MBP.fastq.gz https://www.encodeproject.org/files/ENCFF000MBP/@@download/ENCFF000MBP.fastq.gz
[[ ! -f ENCFF000MBR.fastq.gz ]] && wget -O ENCFF000MBR.fastq.gz https://www.encodeproject.org/files/ENCFF000MBR/@@download/ENCFF000MBR.fastq.gz

# Step 2: Download and index genome
cd $GENOME_DIR
[[ ! -f hg19.fa ]] && wget -c http://hgdownload.cse.ucsc.edu/goldenPath/hg19/bigZips/hg19.fa.gz && gunzip -c hg19.fa.gz > hg19.fa
bismark_genome_preparation $GENOME_DIR

# Step 3–7: Per-sample processing (trim, align, dedup, methyl extract, bigWig)
process_sample() {
    fq="$1"
    sample=$(basename $fq .fastq.gz)
    echo "🔧 Processing $sample"

    trim_galore --rrbs --quality 20 --cores $SAMPLE_THREADS -o $TRIM_DIR $fq
    fq_trimmed="$TRIM_DIR/${sample}_trimmed.fq.gz"

    cd $ALIGN_DIR
    bismark --genome $GENOME_DIR -p $SAMPLE_THREADS $fq_trimmed
    bam="${sample}_trimmed_bismark_bt2.bam"

    deduplicate_bismark --bam ${bam}
    bam_dedup="${sample}_trimmed_bismark_bt2.deduplicated.bam"

    bismark_methylation_extractor --bedGraph --CX_context --single-end $bam_dedup

    # Convert to bigWig
    bedgraph=$(find . -name "${sample}*.bedGraph.gz" | head -n 1)
    gunzip -c $bedgraph > "${sample}.bedGraph"
    sort -k1,1 -k2,2n "${sample}.bedGraph" > "${sample}.sorted.bedGraph"

    wget -q -O hg19.chrom.sizes http://hgdownload.cse.ucsc.edu/goldenPath/hg19/bigZips/hg19.chrom.sizes
    bedGraphToBigWig "${sample}.sorted.bedGraph" hg19.chrom.sizes "$RESULT_DIR/${sample}.bigWig"

    echo "✅ $sample done"
}

export -f process_sample
export GENOME_DIR TRIM_DIR ALIGN_DIR RESULT_DIR SAMPLE_THREADS

cd $FASTQ_DIR
ls *.fastq.gz | parallel -j $MAX_JOBS process_sample {}

# Step 8: Upload all bigWig to S3
S3_BUCKET="graduationcsy"
S3_PREFIX="rrbs-results"
DATESTAMP=$(date +%Y%m%d_%H%M%S)

cd $RESULT_DIR
for bw in *.bigWig; do
    aws s3 cp "$bw" s3://${S3_BUCKET}/${S3_PREFIX}/${bw%.bigWig}_${DATESTAMP}.bigWig
done

echo "🚀 All uploads complete."
