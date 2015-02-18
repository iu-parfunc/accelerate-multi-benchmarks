{-# LANGUAGE BangPatterns #-} 

module Main where

import Data.Array.Accelerate       as A 
import Data.Array.Accelerate.CUDA 


run1_ :: (Arrays a, Arrays b) => (Acc a -> Acc b) -> a -> b 
run1_ f = runMulti . f . use



array :: Vector Int 
array = fromList (Z:.10) [0..9]

test ::  Vector Int  
test = runMulti $ A.zipWith (+) ys zs 
  where
    xs = compute $ (A.map (+1)) (use array)
    ys = compute $ (A.map (*2)) xs
    zs = compute $ (A.map (+1)) ys
    



main ::IO () 
main = print test

