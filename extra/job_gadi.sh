#!/bin/bash

#PBS -N Nextflow-master-trinity
#PBS -P wz54
#PBS -q normal
#PBS -l ncpus=1
#PBS -l walltime=48:00:00

### this is for when nextflow is on gdata
#PBS -l storage=gdata/wz54

#PBS -l wd
#PBS -W umask=022

# setup environment for nextflow
module load java/jdk-8.40
NEXTFLOW_BIN_PATH="/g/data/wz54/nextflow-gadi"  #path to nextflow executable here
export PATH=$NEXTFLOW_BIN_PATH:$PATH

nextflow run marcodelapierre/trinity-nf \
  --reads='reads_{1,2}.fq.gz' \
  -profile gadi,localdisk --whoami=$USER --pbs_account='wz54' \
  -name nxf-${PBS_JOBID%.*} \
  -with-trace trace-${PBS_JOBID%.*}.txt \
  -with-report report-${PBS_JOBID%.*}.html
