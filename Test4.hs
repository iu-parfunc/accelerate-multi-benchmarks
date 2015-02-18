{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators       #-}
{-# OPTIONS_GHC -fno-cse #-}

-- This is a test for concurrent kernel execution. However, there isn't a good
-- way to test whether it works other than loading the program into nvvp \=
--
--module Test4 where
module Main where 
import Prelude                                  as P

import Data.Array.Accelerate                    as A
import Data.Array.Accelerate.Interpreter        as I
import Data.Array.Accelerate.CUDA               as C

import System.Mem



main :: IO ()
main = do
  print $ C.runMulti test2


xs :: Acc (Vector Int)
xs = use $ fromList (Z:.1) [3]

ys :: Acc (Vector Int)
ys = use $ fromList (Z:.1) [3]

zs :: Acc (Vector Int)
zs = use $ fromList (Z:.1) [3]

ws :: Acc (Vector Int)
ws = use $ fromList (Z:.1) [3]

loop :: Exp Int -> Exp Int
loop ticks = A.while (\i -> i <* clockRate * ticks) (+1) 0
  where
    clockRate   = 900000

-- compute :: Arrays a => Acc a -> Acc a
-- compute = id >-> id

{-# NOINLINE test1 #-}
test1 :: Acc (Vector (Int,Int,Int,Int,Int,Int,Int,Int,Int))
test1 = A.zip9
  (compute $ A.map loop (use $ fromList (Z:.1) [1]))
  (compute $ A.map loop (use $ fromList (Z:.1) [1]))
  (compute $ A.map loop (use $ fromList (Z:.1) [1]))
  (compute $ A.map loop (use $ fromList (Z:.1) [1]))
  (compute $ A.map loop (use $ fromList (Z:.1) [1]))
  (compute $ A.map loop (use $ fromList (Z:.1) [1]))
  (compute $ A.map loop (use $ fromList (Z:.1) [1]))
  (compute $ A.map loop (use $ fromList (Z:.1) [1]))
  (compute $ A.map loop (use $ fromList (Z:.1) [1]))


{-# NOINLINE test2 #-}
test2 :: Acc ( Vector Int
             , Vector Int
             , Vector Int
             , Vector Int
             , Vector Int
             , Vector Int
             , Vector Int
             , Vector Int
             , Vector Int)
test2 = 
  lift ( compute $ A.map loop (use $ fromList (Z:.1) [1])
       , compute $ A.map loop (use $ fromList (Z:.1) [1])
       , compute $ A.map loop (use $ fromList (Z:.1) [1])
       , compute $ A.map loop (use $ fromList (Z:.1) [1])
       , compute $ A.map loop (use $ fromList (Z:.1) [1])
       , compute $ A.map loop (use $ fromList (Z:.1) [1])
       , compute $ A.map loop (use $ fromList (Z:.1) [1])
       , compute $ A.map loop (use $ fromList (Z:.1) [1])
       , compute $ A.map loop (use $ fromList (Z:.1) [1]))

test3 :: Acc (Vector Int)
test3 = A.map loop
      $ use (fromList (Z:.3) [1..])

