#!/bin/bash -l

#SBATCH --job-name=Nextflow-master-trinity
#SBATCH --account=director2172
#SBATCH --partition=longq
#SBATCH --time=4-00:00:00
#SBATCH --no-requeue
#SBATCH --export=none

module load singularity  # only needed if containers are yet to be downloaded
module load nextflow

nextflow run marcodelapierre/trinity-nf \
  --reads='reads_{1,2}.fq.gz' \
  -profile zeus --slurm_account='director2172' \
  -name nxf-${SLURM_JOB_ID} \
  -with-trace trace-${SLURM_JOB_ID}.txt \
  -with-report report-${SLURM_JOB_ID}.html
