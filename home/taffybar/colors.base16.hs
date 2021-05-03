module Colors where

import Data.Char
import GHC.Float.RealFracMethods
import System.Taffybar.Widget.Generic.Graph

hexChar2Double :: Char -> Double
hexChar2Double c = int2Double (digitToInt c)

singleHex2ColorVal c = hexChar2Double c / 15

doubleHex2ColorVal (a, b) = (hexChar2Double a * 16 + hexChar2Double b) / 255

decodeHexColor :: String -> Maybe RGBA
decodeHexColor s = case s of
  ('#' : rest) ->
    case rest of
      [a, b, c] -> Just (singleHex2ColorVal a, singleHex2ColorVal b, singleHex2ColorVal c, 1)
      [a, b, c, d] -> Just (singleHex2ColorVal a, singleHex2ColorVal b, singleHex2ColorVal c, singleHex2ColorVal d)
      [a, b, c, d, e, f] -> Just (doubleHex2ColorVal (a, b), doubleHex2ColorVal (c, d), doubleHex2ColorVal (e, f), 1)
      [a, b, c, d, e, f, g, h] -> Just (doubleHex2ColorVal (a, b), doubleHex2ColorVal (c, d), doubleHex2ColorVal (e, f), doubleHex2ColorVal (g, h))
      _ -> Nothing
  _ -> Nothing
