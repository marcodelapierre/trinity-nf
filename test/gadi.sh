#!/bin/bash

#PBS -N nxf-small
#PBS -P wz54
#PBS -q express
#PBS -l ncpus=1
#PBS -l mem=8GB
#PBS -l walltime=10:00

### probably not needed as this is the default behaviour in Gadi, let us see
###PBS -l storage=scratch/wz54

#PBS -l wd
#PBS -W umask=022


# Ensure nextflow is in the PATH
module load java/jdk-8.40
export PATH=$PATH:<path/to/nextflow>

nextflow run main.nf \
  --reads='reads_{1,2}.fq.gz' \
  -profile test_gadi \
  -name nxf-${PBS_JOBID}
