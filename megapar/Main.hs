{-# LANGUAGE CPP #-} 
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators       #-}
{-# OPTIONS_GHC -fno-cse #-}

-- This is a test for concurrent kernel execution. However, there isn't a good
-- way to test whether it works other than loading the program into nvvp \=
--
--module Test4 where
module Main where 
import Prelude                                  as P
import Data.List                                as L

import Data.Array.Accelerate                    as A
import Data.Array.Accelerate.Interpreter        as I
import Data.Array.Accelerate.CUDA               as C

import System.Mem
import System.Environment
import System.Console.GetOpt 

import Criterion.Main

main :: IO ()
main =
  do
    x <- getArgs
    case P.length x of
      0 -> error "at least specify --cuda or --multi" 
      n -> return ()

    let (a,rest) = parseArgs x

    let runIt :: Arrays a => Acc a -> a 
        runIt =
          case a of
            "cuda"  -> C.run
            "multi" -> C.runMulti
            "BAD"   -> error "no backend specified" 
    
    putStrLn "benchmark time" 
    withArgs rest $ 
       defaultMain [
         bgroup "megapar" [ bench "1"  $ whnf (runIt . megapar) 1
                          , bench "2"  $ whnf (runIt . megapar) 2
                          , bench "3"  $ whnf (runIt . megapar) 3
                          , bench "4"  $ whnf (runIt . megapar) 4] ]
                        
    
        
parseArgs :: [String] -> (String,[String])
parseArgs args = (if hasCuda
                  then "cuda"
                  else
                    if hasMulti
                    then "multi"
                    else "BAD",args') 
  
  where
    cuda = "--cuda"
    multi = "--multi" 
    hasCuda = elem cuda args 
    hasMulti = elem multi args
    args' = L.delete cuda (L.delete multi args) 

loop :: Exp Int -> Exp Int
loop ticks = A.while (\i -> i <* clockRate * ticks) (+1) 0
  where
    clockRate   = 900000

{-# NOINLINE megapar #-}
megapar :: Int -> Acc ( Vector Int
                      , Vector Int
                      , Vector Int
                      , Vector Int
                      , Vector Int
                      , Vector Int
                      , Vector Int
                      , Vector Int)
megapar d = 
  lift ( compute $ A.map loop (use $ fromList (Z:.1) [d])
       , compute $ A.map loop (use $ fromList (Z:.1) [d])
       , compute $ A.map loop (use $ fromList (Z:.1) [d])
       , compute $ A.map loop (use $ fromList (Z:.1) [d])
       , compute $ A.map loop (use $ fromList (Z:.1) [d])
       , compute $ A.map loop (use $ fromList (Z:.1) [d])
       , compute $ A.map loop (use $ fromList (Z:.1) [d])
       , compute $ A.map loop (use $ fromList (Z:.1) [d]))


