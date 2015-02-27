#!/bin/bash

CRITUPLOAD=hsbencher-fusion-upload-criterion-0.3.15
CSVUPLOAD=hsbencher-fusion-upload-csv-0.3.15
CATCSV=cat-csv

# The new new accelerate-multi-benchmarks table 

TABLENAME=accelerate-multi-benchmarks
TABID=1DJJM9SI_N8En4-M6mSB67tSerL_laFJ3Dw1evNMW

# Parfunc account, registered app in api console:
export HSBENCHER_GOOGLE_CLIENTID=905767673358.apps.googleusercontent.com
export HSBENCHER_GOOGLE_CLIENTSECRET=2a2H57dBggubW1_rqglC7jtK

# try a few time (5, means 6) 
RETRIES=5

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


nvidia-smi
# set some nvidia paths 

export PATH=/usr/local/cuda-6.5/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-6.5/lib64:$LD_LIBRARY_PATH



unset GHC
unset GHC_PKG

# If we don't have the Criterion uploader, don't bother trying
if ! [ -x `which $CRITUPLOAD` ]; then
    echo "Error: no $CRITUPLOAD found"
    exit 1
fi

set -e

cd "$CHECKOUT"

#is this the directory where everything is ? 
git submodule update --init --recursive 

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

./Setup.sh -j
# -j --ghc-option=-j3

# Step 2: Run benchmarks, archive results
# ========================================

# We don't have a full HSBencher harness here:
# ./run_benchmarks.exe --keepgoing --trials=$TRIALS --fusion-upload --name=$TABLENAME --clientid=$CID --clientsecret=$SEC $EXTRAARGS


BINDIR=`pwd`/.cabal-sandbox/bin

# Accumulator for output names:
OUTCSVS=

# function go {
#   VARIANT=$variant
#   $BINDIR/accelerate-nbody  --$VARIANT -n $arg --benchmark \
#       --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit  +RTS -T -s
#   #$REGRESSES
#   $CRITUPLOAD --noupload --csv=${CSVREPORT}_${VARIANT}_${arg}.csv --variant=$VARIANT --threads=1 --args="$arg" ${CRITREPORT}_${VARIANT}_${arg}.crit
#   OUTCSVS+=" ${CSVREPORT}_${VARIANT}_${arg}.csv"
# }



function go {
    export FISSION=$1
    export MULTI_USE_DEVICES=$2
    echo "FISSION: ${FISSION}"
    echo "MULTI_USE_DEVICES: ${MULTI_USE_DEVICES}"
    for i in 0 .. $RETRIES; do
	if $BINDIR/$executable $ARGUMENTS ; 
	then 
	  $CRITUPLOAD --noupload  --csv=${CSVREPORT}_${VARIANT}_${arg}.csv --variant=$VARIANT --threads=1 --args="$arg" ${CRITREPORT}_${VARIANT}_${arg}.crit
	  OUTCSVS+=" ${CSVREPORT}_${VARIANT}_${arg}.csv"  
	  break 
	else echo "RETRYING" 
	fi
	#sleep 5
    done	
}


# megapar accelerate-crystal
for executable in $EXTRAARGS; do 
  echo "Running benchmark $executable"
  REPORT=report_${executable}
  CRITREPORT=${TAG}_${REPORT}
  CSVREPORT=${TAG}_${REPORT}

## #########################################
## RUN UNFISSED BENCHMARKS ON CUDA AND MULTI  
 for variant in cuda multi; do
   VARIANT=$variant 
   case $executable in 
     accelerate-nbody)  	   
       for arg in 50000 60000 70000 80000 90000 100000 110000; do
	  ARGUMENTS="--$variant -n $arg --benchmark --output=${CRITREPORT}_${variant}_${arg}.html --raw=${CRITREPORT}_${variant}_${arg}.crit +RTS -T -s"
	  go 0; 
       done  
       ;; 
     accelerate-mandelbrot) 
       for arg in 256 512 1024 2048 4096 8192 16384 32768; do
	   ARGUMENTS="--$variant --width=$arg --height=$arg --limit=512 --benchmark --output=${CRITREPORT}_${variant}_${arg}.html --raw=${CRITREPORT}_${variant}_${arg}.crit +RTS -T -s"
	   go 0;
       done
       ;;
     accelerate-mmult) 
       for arg in 100 200 300 400 500; do	       
	   ARGUMENTS="--$variant  -n $arg --benchmark --output=${CRITREPORT}_${variant}_${arg}.html --raw=${CRITREPORT}_${variant}_${arg}.crit +RTS -T -s"
	   go 0;
       done
       ;;
     megapar) 
       for arg in 1 2 3 4; do 
     	   ARGUMENTS="--$variant  -n $arg --benchmark --output=${CRITREPORT}_${variant}_${arg}.html --raw=${CRITREPORT}_${variant}_${arg}.crit +RTS -T -s"
     	   go 0;
       done
       ;;
     fatmegapar) 
       for arg in 1 2 3 4; do 
     	   ARGUMENTS="--$variant  -n $arg -m 2000000 --benchmark --output=${CRITREPORT}_${variant}_${arg}.html --raw=${CRITREPORT}_${variant}_${arg}.crit +RTS -T -s"
     	   go 0;
       done
       ;;
     memboundmegapar) 
       for arg in 10000000 20000000 30000000 40000000 50000000 ; do 
     	   ARGUMENTS="--$variant  -n $arg --benchmark --output=${CRITREPORT}_${variant}_${arg}.html --raw=${CRITREPORT}_${variant}_${arg}.crit +RTS -T -s"
     	   go 0;
       done
       ;;
     accelerate-crystal) 
       for arg in 100 200 300 400 500; do
	   ARGUMENTS="--$variant  --size=$arg --benchmark --output=${CRITREPORT}_${variant}_${arg}.html --raw=${CRITREPORT}_${variant}_${arg}.crit +RTS -T -s"
	   go 0;
       done
       ;;
     accelerate-blackscholes) 
       for arg in 50000000 60000000 70000000 80000000 90000000 100000000; do
	   ARGUMENTS="--$variant -n $arg --benchmark --output=${CRITREPORT}_${variant}_${arg}.html --raw=${CRITREPORT}_${variant}_${arg}.crit +RTS -T -s"
	   go 0;
       done
       ;;
     accelerate-dotp) 
       for arg in 50000000 60000000 70000000 80000000 90000000 100000000; do
	   ARGUMENTS="--$variant -n $arg --benchmark --output=${CRITREPORT}_${variant}_${arg}.html --raw=${CRITREPORT}_${variant}_${arg}.crit +RTS -T -s"
	   go 0;
       done
       ;;
    esac
  done
done

## ################################
## SPECIAL HANDLING FOR DUPED BENCH

## the duped nbody is different from nbody above, 
## even if run on cuda backed or in "unduped" mode 
for executable in $EXTRAARGS; do
  echo "Running DUPED benchmark $executable"
  REPORT=report_${executable}
  CRITREPORT=${TAG}_${REPORT}
  CSVREPORT=${TAG}_${REPORT}

  for duped in "" --duped; do 
    for variant in cuda multi; do 
      VARIANT=$variant$duped 
      case $executable in 
        accelerate-nbody-duped)  	   
          for arg in 50000 60000 70000 80000 90000 100000 110000; do
	    ARGUMENTS="--$variant -n $arg $duped --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	    go 0; 
          done  
       ;;
      esac
    done
  done
done   

## #####################
## RUN FISSED BENCHMARKS 
for executable in $EXTRAARGS; do 
  echo "Running fissioned benchmarks"  
  REPORT=report_${executable}
  CRITREPORT=${TAG}_${REPORT}
  CSVREPORT=${TAG}_${REPORT}
  
  ## FISSED 
  ## backend multi:  one device! 
  VARIANT=multi_one_device_fissed
  case $executable in 
    accelerate-nbody) 
      for arg in 50000 60000 70000 80000 90000 100000 110000; do 
	ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	go 1 0;
      done  
     ;;
    accelerate-mandelbrot) 
      for arg in 256 512 1024 2048 4096 8192 16384 32768; do
	  ARGUMENTS="--multi --width=$arg --height=$arg --limit=512 --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 0;
      done
      ;;
    accelerate-mmult) 
      for arg in 100 200 300 400 500; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 0;
      done
      ;;
    accelerate-crystal) 
      for arg in 100 200 300 400 500; do
	  ARGUMENTS="--multi --size=$arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 0;
      done
      ;;
    accelerate-blackscholes) 
      for arg in 50000000 60000000 70000000 80000000 90000000 100000000; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 0;
      done
      ;;
    accelerate-dotp) 
      for arg in 50000000 60000000 70000000 80000000 90000000 100000000; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 0;
      done
      ;;
    fatmegapar) 
       for arg in 1 2 3 4; do 
     	   ARGUMENTS="--multi -n $arg -m 2000000 --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
     	   go 0;
       done
       ;;
    memboundmegapar) 
       for arg in 10000000 20000000 30000000 40000000 50000000 ; do 
     	   ARGUMENTS="--multi  -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
     	   go 0;
       done

  esac
  ## FISSED 
  ## backend multi: two devices!
  VARIANT=multi_two_device_fissed
  case $executable in 
    accelerate-nbody) 
      for arg in 50000 60000 70000 80000 90000 100000 110000; do 
        ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
        go 1 '0 1'; 
      done  
     ;;
    accelerate-mandelbrot) 
      for arg in 256 512 1024 2048 4096 8192 16384 32768; do
	  ARGUMENTS="--multi --width=$arg --height=$arg --limit=512 --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 '0 1';
      done
      ;;
    accelerate-mmult) 
      for arg in 100 200 300 400 500; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 0;
      done
      ;;
    accelerate-crystal) 
      for arg in 100 200 300 400 500; do
	  ARGUMENTS="--multi --size=$arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 '0 1';
      done
      ;;
    accelerate-blackscholes) 
      for arg in 50000000 60000000 70000000 80000000 90000000 100000000; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 '0 1';
      done
      ;;
    accelerate-dotp) 
      for arg in 50000000 60000000 70000000 80000000 90000000 100000000; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 '0 1';
      done
      ;;
    fatmegapar) 
       for arg in 1 2 3 4; do 
     	   ARGUMENTS="--multi -n $arg -m 2000000 --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
     	   go 0;
       done
       ;;

  esac    

  ## UNFISSED 
  ## backend multi:  one device! 
  VARIANT=multi_one_device_unfissed
  case $executable in 
    accelerate-nbody) 
      for arg in 50000 60000 70000 80000 90000 100000 110000; do 
	ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
        go 0 0;
      done  
     ;;
    accelerate-mandelbrot) 
      for arg in 256 512 1024 2048 4096 8192 16384 32768; do
	  ARGUMENTS="--multi --width=$arg --height=$arg --limit=512 --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 0 0;
      done
      ;;
    accelerate-mmult) 
      for arg in 100 200 300 400 500; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 0;
      done
      ;;
    accelerate-crystal) 
      for arg in 100 200 300 400 500; do
	  ARGUMENTS="--multi --size=$arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 0 0;
      done
      ;;
    accelerate-blackscholes) 
      for arg in 50000000 60000000 70000000 80000000 90000000 100000000; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 0 0;
      done
      ;;
    accelerate-dotp) 
      for arg in 50000000 60000000 70000000 80000000 90000000 100000000; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 0 0;
      done
      ;;
  esac
  ## UNFISSED 
  ## backend multi: two devices!
  VARIANT=multi_two_device_unfissed
  case $executable in 
    accelerate-nbody) 
      for arg in 50000 60000 70000 80000 90000 100000 110000; do 
        ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	go 0 '0 1';
      done  
     ;;
    accelerate-mandelbrot) 
      for arg in 256 512 1024 2048 4096 8192 16384 32768; do
	  ARGUMENTS="--multi --width=$arg --height=$arg --limit=512 --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 0 '0 1';
      done
      ;;
    accelerate-mmult) 
      for arg in 100 200 300 400 500; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 1 0;
      done
      ;;
    accelerate-crystal) 
      for arg in 100 200 300 400 500; do
	  ARGUMENTS="--multi  --size=$arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 0 '0 1';
      done
      ;;
    accelerate-blackscholes) 
      for arg in 50000000 60000000 70000000 80000000 90000000 100000000; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 0 '0 1';
      done
      ;;
    accelerate-dotp) 
      for arg in 50000000 60000000 70000000 80000000 90000000 100000000; do
	  ARGUMENTS="--multi -n $arg --benchmark --output=${CRITREPORT}_${VARIANT}_${arg}.html --raw=${CRITREPORT}_${VARIANT}_${arg}.crit +RTS -T -s"
	  go 0 '0 1';
      done
      ;;
  esac    
done

  
      

   
echo "Finally: attempt an upload"
ALLREPS=${HOSTNAME}_${TAG}_ALLDATA.csv
$CATCSV $OUTCSVS > $BAKDIR/$ALLREPS

# NOTE: could aggressively retry this, since we're alreday done with the benchmarks:
$CSVUPLOAD $BAKDIR/$ALLREPS --fusion-upload=$TABID --name=$TABLENAME || FAILED=1

if [ "$FAILED" == 1 ]; then
   mv $BAKDIR/$ALLREPS $FAILDIR/
else
   mv $BAKDIR/$ALLREPS $WINDIR/
fi
