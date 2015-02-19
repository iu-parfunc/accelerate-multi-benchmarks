#!/bin/bash

CRITUPLOAD=hsbencher-fusion-upload-criterion-0.3.10
CSVUPLOAD=hsbencher-fusion-upload-csv-0.3.10
CATCSV=cat-csv

# The new accelerate-multi-benchmarks table 
# TABID=1giYspfeb2FPqprb7bEkQo-QnqdvXgXCrcH7jF0Ag
TABLENAME=accelerate-multi-benchmarks

# Parfunc account, registered app in api console:
export HSBENCHER_GOOGLE_CLIENTID=905767673358.apps.googleusercontent.com
export HSBENCHER_GOOGLE_CLIENTSECRET=2a2H57dBggubW1_rqglC7jtK



echo "Begin running jenkins benchmark script for Accelerate-multidev..."
set -x

# CONVENTION: The working directory is passed as the first argument.
CHECKOUT=$1
shift
EXTRAARGS=$*

if [ "$CHECKOUT" == "" ]; then
 echo "Replacing CHECKOUT with pwd" 
 CHECKOUT=`pwd`
fi

if [ "$JENKINS_GHC" == "" ]; then
  export JENKINS_GHC=7.8.3
fi
if [ -f "$HOME/continuous_testing_setup/rn_jenkins_scripts/acquire_ghc.sh" ]; then
  source $HOME/continuous_testing_setup/rn_jenkins_scripts/acquire_ghc.sh
fi
if [ -f "$HOME/continuous_testing_setup/rn_jenkins_scripts/acquire_cuda.sh" ]; then
  source $HOME/continuous_testing_setup/rn_jenkins_scripts/acquire_cuda.sh
fi

echo "Running benchmarks remotely on server `hostname`"

export CABAL=cabal-1.20

which $CABAL
$CABAL --version

which c2hs     || echo ok
c2hs --version || echo ok

which -a nvcc
#do this properly ?? 
module add cuda 

nvidia-smi

unset GHC
unset GHC_PKG

# If we don't have the Criterion uploader, don't bother trying
if ! [ -x `which $CRITUPLOAD` ]; then
    echo "Error: no $CRITUPLOAD found"
    exit 1
fi

set -e

cd "$CHECKOUT"

export GIT_DEPTH=`git log --pretty=oneline | wc -l`
echo "Running at GIT_DEPTH:" $GIT_DEPTH

TAG=`date +'%s'`
BAKDIR=$HOME/benchdata_bak/$TABLENAME/depth_${GIT_DEPTH}/
WINDIR=$BAKDIR/uploaded
FAILDIR=$BAKDIR/failed_upload

mkdir -p $WINDIR
mkdir -p $FAILDIR

# Criterion regressions
REGRESSES="--regress=allocated:iters --regress=bytesCopied:iters --regress=cycles:iters \
--regress=numGcs:iters --regress=mutatorWallSeconds:iters --regress=gcWallSeconds:iters \
--regress=cpuTime:iters "


#sandboxes are created by the Makefile for run_benchmarks.hs
#this makefile also install Obsidian+hsbencher as a single cabal install line
# DIR=`pwd`  
# echo $DIR 
# if [ ! -d "HSBencher" ]; then 
#     git clone git@github.com:rrnewton/HSBencher
# fi 
# BJS: Commented the above, this repo has a HSBencher submod

# BJS: Don't know if do this here 
#(cd HSBencher; git submodule init; git submodule update) 
# cabal install ./HSBencher/hsbencher/ 

# NOTES: 
# On tesla we need to do a module add cuda 

# export TRIALS=1


# Step 1: Build everything
# ========================================

./Setup.sh

# Step 2: Run benchmarks, archive results
# ========================================

# We don't have a full HSBencher harness here:
# ./run_benchmarks.exe --keepgoing --trials=$TRIALS --fusion-upload --name=$TABLENAME --clientid=$CID --clientsecret=$SEC $EXTRAARGS


BINDIR=`pwd`/.cabal-sandbox/bin

# Accumulator for output names:
OUTCSVS=

for executable in accelerate-nbody ; do 
  echo "Running benchmark $executable"
  REPORT=report_${executable}
  CRITREPORT=${TAG}_${REPORT}.crit
  CSVREPORT=${TAG}_${REPORT}.csv

# case $executable

  for arg in 50000 ; do
      VARIANT=cuda
      $BINDIR/accelerate-nbody $REGRESSES --$VARIANT -n $arg --benchmark \
          --output=$CRITREPORT.html --raw=$CRITREPORT  +RTS -T -s

      $CRITUPLOAD --noupload --csv=$CSVREPORT --variant=$VARIANT --threads=1 --args="$arg" $CRITREPORT
      OUTCSVS+=" $CSVREPORT"
    done  
done

echo "Finally: attempt an upload"
ALLREPS=${TAG}_ALLDATA.csv
$CATCSV $OUTCSVS > $BAKDIR/$ALLREPS

# NOTE: could aggressively retry this, since we're alreday done with the benchmarks:
$CSVUPLOAD $BAKDIR/$ALLREPS --fusion-upload --name=$TABLENAME || FAILED=1

if [ "$FAILED" == 1 ]; then
   mv $BAKDIR/$ALLREPS $FAILDIR/
else
   mv $BAKDIR/$ALLREPS $WINDIR/
fi
