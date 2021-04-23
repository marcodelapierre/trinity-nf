#!/bin/bash
 
# assuming this script is run on Gadi at NCI
 
 
# CUSTOMISE these variables
pbs_account="wz54"
nxf_version="v20.07.1"
java_module_version="jdk-8.40"
 
 
# DO NOT need to change below this point
 
# this is good habit on HPC systems
export NXF_HOME="/scratch/$pbs_account/$USER/.nextflow"
 
# working directories
here=$(pwd)
tmp_dir="/tmp/tmp_nextflow_build_$((RANDOM))"
 
mkdir -p $tmp_dir
cd $tmp_dir
 
# get nextflow repo to the right version
git clone https://github.com/nextflow-io/nextflow
cd nextflow
git checkout $nxf_version
 
# patch the code
patch modules/nextflow/src/main/groovy/nextflow/executor/PbsProExecutor.groovy < $here/patch.PbsProExecutor.groovy

# compile
module load java/$java_module_version
 
make compile
make pack
make install
 
# retrieve nextflow executable
cd $here
cp -p $tmp_dir/nextflow/build/releases/nextflow-*-all nextflow
chmod +x nextflow
 
# test nextflow executable
./nextflow info
 
# clean build dir
 rm -rf $tmp_dir
 
# print final information
echo ""
echo "Patched nextflow made available at $here/nextflow."
echo ""
echo "To use it, add these commands to your workflow setup, or to your .bashrc or .bash_profile:"
echo ""
echo "module load java/$java_module_version"
echo "export NXF_HOME=\"/scratch/$pbs_account/$USER/.nextflow\""
echo "export PATH=\"$here:\$PATH\""
echo ""
