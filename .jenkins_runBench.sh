#!/bin/bash

echo "Begin running jenkins benchmark script for Accelerate-multidev..."
set -x

# CONVENTION: The working directory is passed as the first argument.
CHECKOUT=$1
shift

if [ "$CHECKOUT" == "" ]; then
 echo "Replacing CHECKOUT with pwd" 
 CHECKOUT=`pwd`
fi

if [ "$JENKINS_GHC" == "" ]; then
  export JENKINS_GHC=7.6.3
fi
if [ -f "$HOME/continuous_testing_setup/rn_jenkins_scripts/acquire_ghc.sh" ]; then
  source $HOME/continuous_testing_setup/rn_jenkins_scripts/acquire_ghc.sh
fi
if [ -f "$HOME/continuous_testing_setup/rn_jenkins_scripts/acquire_cuda.sh" ]; then
  source $HOME/continuous_testing_setup/rn_jenkins_scripts/acquire_cuda.sh
fi

echo "Running benchmarks remotely on server `hostname`"

which cabal
cabal --version

which c2hs     || echo ok
c2hs --version || echo ok

unset GHC
unset GHC_PKG
unset CABAL

set -e

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



export TRIALS=1

# Parfunc account, registered app in api console:
CID=905767673358.apps.googleusercontent.com
SEC=2a2H57dBggubW1_rqglC7jtK

# The new accelerate-multi-benchmarks table 
# 1giYspfeb2FPqprb7bEkQo-QnqdvXgXCrcH7jF0Ag
TABID=1giYspfeb2FPqprb7bEkQo-QnqdvXgXCrcH7jF0Ag
#NOTE: TABID is not used below!

echo "Running Benchmarks"
./run_benchmarks.exe --keepgoing --trials=$TRIALS --fusion-upload --name=accelerate-multi-benchmarks --clientid=$CID --clientsecret=$SEC $*
