#!/bin/bash -l

#SBATCH --job-name=nxf-small
#SBATCH --account=pawsey0001
#SBATCH --partition=workq
#SBATCH --mem=8G
#SBATCH --time=10:00
#SBATCH --no-requeue
#SBATCH --export=none

### NOTE: may need longer runtime above, if container images have yet to be pulled

unset SBATCH_EXPORT

module load singularity
module load nextflow

nextflow run main.nf \
  --reads='reads_{1,2}.fq.gz' \
  -profile test_zeus \
  -name nxf-${SLURM_JOB_ID}
