#!/bin/bash

#PBS -N nxf-small
#PBS -P wz54
#PBS -q express
#PBS -l ncpus=1
#PBS -l mem=8GB
#PBS -l walltime=10:00

### this is for when nextflow is on gdata
#PBS -l storage=gdata/wz54

### this is needed only when using test_gadi,localdisk
###PBS -l jobfs=1GB

### not needed as this is the default behaviour in Gadi
###PBS -l storage=scratch/wz54

#PBS -l wd
#PBS -W umask=022


# setup environment for nextflow
module load java/jdk-8.40
NEXTFLOW_BIN_PATH=""  #path to nextflow executable here
export PATH=$PATH:$NEXTFLOW_BIN_PATH

nextflow run main.nf \
  --reads='reads_{1,2}.fq.gz' \
  -profile test_gadi \
  -name nxf-${PBS_JOBID%.*}
