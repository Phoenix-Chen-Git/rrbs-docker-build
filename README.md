# RRBS Docker Build

This repository provides a Docker image containing the tools required to run a
Reduced Representation Bisulfite Sequencing (RRBS) pipeline.  The container
installs Trim Galore, Bismark, FastQC and the UCSC utilities and includes an
example script `rrbs_to_bigwig.sh` that downloads demo data, processes it and
uploads BigWig files to Amazon S3.

## Building

Build the image locally with Docker:

```bash
docker build -t rrbs-fastq2bigwig .
```

## Running

Run the container with a mounted directory so the results persist on the host:

```bash
docker run --rm -v $(pwd)/data:/data rrbs-fastq2bigwig
```

The pipeline writes intermediate files under `/data/fastq`, `/data/genome`,
`/data/trimmed`, `/data/aligned` and final BigWig files to `/data/results`.
The script uploads the resulting BigWigs to the S3 bucket specified by the
`S3_BUCKET` and `S3_PREFIX` variables in `rrbs_to_bigwig.sh`.  Edit those values
if you wish to change the upload destination.

## Repository contents

- `Dockerfile` – installs all dependencies required for the pipeline.
- `rrbs_to_bigwig.sh` – example processing script executed as the image entry point.
- `buildspec.yml` – sample AWS CodeBuild configuration used to build and push
  the image to Amazon ECR.
