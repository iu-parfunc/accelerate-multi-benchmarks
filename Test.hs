{-# LANGUAGE BangPatterns #-} 

module Main where

import Data.Array.Accelerate       as A 
import Data.Array.Accelerate.CUDA 


run1_ :: (Arrays a, Arrays b) => (Acc a -> Acc b) -> a -> b 
run1_ f = runMulti . f . use



array :: Vector Int 
array = fromList (Z:.10) [0..9]

test ::  Vector Int  
test = run1_ (A.zipWith (+) ys') zs 
  where
    ys' = compute $ use ys
    ys = run1_ (A.map (*2)) xs
    zs = run1_ (A.map (+1)) ys
    
xs = run1_ (A.map (+1)) array 


main ::IO () 
main = print test

