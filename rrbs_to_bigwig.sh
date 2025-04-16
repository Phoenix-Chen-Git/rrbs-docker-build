#!/bin/bash
set -e

echo "🚀 Starting RRBS single-end pipeline..."

# ========== Step 0: Environment ==========
WORKDIR=/data
FASTQ_DIR=$WORKDIR/fastq
GENOME_DIR=$WORKDIR/genome
TRIM_DIR=$WORKDIR/trimmed
ALIGN_DIR=$WORKDIR/aligned
RESULT_DIR=$WORKDIR/results
mkdir -p $FASTQ_DIR $GENOME_DIR $TRIM_DIR $ALIGN_DIR $RESULT_DIR
cd $FASTQ_DIR

# ========== Step 1: Download FASTQ ==========
echo "⏬ Downloading ENCODE RRBS FASTQ files..."
wget -O ENCFF000MBP.fastq.gz https://www.encodeproject.org/files/ENCFF000MBP/@@download/ENCFF000MBP.fastq.gz
wget -O ENCFF000MBR.fastq.gz https://www.encodeproject.org/files/ENCFF000MBR/@@download/ENCFF000MBR.fastq.gz

# ========== Step 2: Prepare Reference Genome ==========
cd $GENOME_DIR
echo "🧬 Downloading and indexing hg19 reference..."
wget -c http://hgdownload.cse.ucsc.edu/goldenPath/hg19/bigZips/hg19.fa.gz
gunzip -c hg19.fa.gz > hg19.fa
bismark_genome_preparation $GENOME_DIR

# ========== Step 3: Trim Galore ==========
cd $TRIM_DIR
echo "✂️ Trimming reads..."
for fq in $FASTQ_DIR/*.fastq.gz; do
    echo "Trimming $fq..."
    trim_galore --rrbs --quality 20 $fq
done

# ========== Step 4: Bismark Alignment ==========
cd $ALIGN_DIR
echo "🧲 Aligning trimmed reads..."
for fq in $TRIM_DIR/*_trimmed.fq.gz; do
    echo "Aligning $fq..."
    bismark --genome $GENOME_DIR $fq
done

# ========== Step 5: Merge BAM ==========
echo "🔁 Merging BAM files..."
bam_files=$(ls *_bismark_bt2.bam)
samtools merge merged.bam $bam_files

# ========== Step 6: Deduplicate ==========
echo "🧼 Deduplicating..."
deduplicate_bismark --bam merged.bam

# ========== Step 7: Methylation Extraction ==========
echo "🧪 Extracting methylation calls..."
bismark_methylation_extractor --bedGraph --CX_context --single-end merged.deduplicated.bam

# ========== Step 8: Convert BedGraph to BigWig ==========
echo "📏 Getting chromosome sizes..."
wget -c http://hgdownload.cse.ucsc.edu/goldenPath/hg19/bigZips/hg19.chrom.sizes -O hg19.chrom.sizes

echo "📦 Downloading static bedGraphToBigWig binary..."
wget http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/bedGraphToBigWig -O bedGraphToBigWig
chmod +x bedGraphToBigWig

echo "📈 Sorting bedGraph and generating bigWig..."
bedGraph=$(find . -name "*.bedGraph.gz" | head -n 1)
gunzip -c "$bedGraph" > temp.bedGraph
sort -k1,1 -k2,2n temp.bedGraph > sorted.bedGraph
./bedGraphToBigWig sorted.bedGraph hg19.chrom.sizes $RESULT_DIR/merged.bigWig

# ========== Step 9: Upload to S3 ==========
echo "☁️ Uploading result to S3..."
S3_BUCKET="graduationcsy"   # ✅ 改成你自己的 bucket 名
S3_PREFIX="rrbs-results"    # ✅ 可选路径前缀
DATESTAMP=$(date +%Y%m%d_%H%M%S)
aws s3 cp $RESULT_DIR/merged.bigWig s3://${S3_BUCKET}/${S3_PREFIX}/merged_${DATESTAMP}.bigWig

echo "✅ Upload completed: s3://${S3_BUCKET}/${S3_PREFIX}/merged_${DATESTAMP}.bigWig"
