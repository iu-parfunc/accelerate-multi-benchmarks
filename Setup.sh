#!/bin/bash

# Compile all the packages

set -xe

if [ "$CABAL" == "" ]; then 
  CABAL=cabal-1.20
fi

$CABAL sandbox init 

if ! [ -e ./cuda/configure ]; then
  cp ./aux/configure ./cuda/
fi

PKGS="./Accelerate/ ./Accelerate-cuda/ ./Accelerate-examples/ ./Accelerate-io/ ./accelerate-fft/ ./cuda/ ./gloss/gloss/ ./gloss/gloss-raster/ ./gloss/gloss-rendering/ ./gloss-raster-accelerate/ ./gloss-accelerate/"

$CABAL install -fMULTI -fcuda $PKGS $*

