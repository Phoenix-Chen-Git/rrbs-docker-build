#!/bin/bash
set -e

echo "🚀 Starting RRBS single-end pipeline..."

# Step 1: Create working directories
mkdir -p /data/fastq /data/genome /data/trimmed /data/aligned
cd /data/fastq

echo "⏬ Downloading ENCODE RRBS FASTQ files..."
wget -O ENCFF000MBP.fastq.gz https://www.encodeproject.org/files/ENCFF000MBP/@@download/ENCFF000MBP.fastq.gz
wget -O ENCFF000MBR.fastq.gz https://www.encodeproject.org/files/ENCFF000MBR/@@download/ENCFF000MBR.fastq.gz

# Step 2: Prepare hg19 reference
cd /data/genome
echo "🧬 Downloading and indexing hg19 reference..."
wget -c http://hgdownload.cse.ucsc.edu/goldenPath/hg19/bigZips/hg19.fa.gz
gunzip -c hg19.fa.gz > hg19.fa
bismark_genome_preparation /data/genome

# Step 3: Trim Galore with quality filtering (Q20)
cd /data/trimmed
echo "✂️ Trimming reads with quality cutoff = 20..."
for fq in /data/fastq/*.fastq.gz; do
    echo "Trimming $fq..."
    trim_galore --rrbs --quality 20 $fq
done

# Step 4: Align with Bismark (single-end)
cd /data/aligned
echo "🧲 Aligning with Bismark..."
for fq in /data/trimmed/*_trimmed.fq.gz; do
    echo "Aligning $fq..."
    bismark --genome /data/genome $fq
done

# Step 5: Merge BAM files
echo "🔁 Merging BAM files..."
bam_files=$(ls *_bismark_bt2.bam)
samtools merge merged.bam $bam_files

# Step 6: Deduplicate
echo "🧼 Deduplicating merged BAM..."
deduplicate_bismark --bam merged.bam

# Step 7: Methylation extraction
echo "🧪 Extracting methylation calls..."
bismark_methylation_extractor --bedGraph --single-end merged.deduplicated.bam

# Step 8: Convert bedGraph to bigWig (with sorting)
echo "📏 Getting chromosome sizes..."
wget -c http://hgdownload.cse.ucsc.edu/goldenPath/hg19/bigZips/hg19.chrom.sizes

echo "📈 Sorting bedGraph and generating bigWig..."
bedGraph=$(ls *.bismark.cov*.bedGraph | head -n 1)
sort -k1,1 -k2,2n $bedGraph > sorted.bedGraph
bedGraphToBigWig sorted.bedGraph hg19.chrom.sizes merged.bigWig

echo "✅ Pipeline completed. Final output: /data/aligned/merged.bigWig"
