#!/usr/bin/env runghc
{-# LANGUAGE NamedFieldPuns #-}

-- | This script runs accelerate-multi-benchmarks.


import Data.Monoid (mappend)

import HSBencher
import HSBencher.Backend.Fusion  (defaultFusionPlugin)
import HSBencher.Backend.Dribble (defaultDribblePlugin)

import Prelude
--------------------------------------------------------------------------------

main :: IO ()
main = defaultMainModifyConfig myconf


all_benchmarks :: [Benchmark DefaultParamMeaning]
all_benchmarks = []   
  

-- | Default configuration space over which to vary settings:
--   This is a combination of And/Or boolean operations, with the ability
--   to set various environment and compile options.
defaultCfgSpc = And []

-- | Here we have the option of changing the HSBencher config
myconf :: Config -> Config
myconf conf =
  conf
   { benchlist = all_benchmarks
   , plugIns   = [ SomePlugin defaultFusionPlugin,
                   SomePlugin defaultDribblePlugin ]
   , harvesters = harvesters conf
   }
