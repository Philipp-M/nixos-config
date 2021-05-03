module NetworkMonitor where

import           Control.Monad
import           Control.Monad.Trans.Class
import qualified Data.Text as T
import           GI.Gtk
import           System.Taffybar.Context
import           System.Taffybar.Hooks
import           System.Taffybar.Information.Network
import           System.Taffybar.Util
import           System.Taffybar.Widget.Generic.ChannelWidget
import           Text.Printf
import           Text.StringTemplate

defaultNetFormat :: String
defaultNetFormat = "▼ $inAuto$ ▲ $outAuto$"

showInfo :: String -> Int -> Int -> (Double, Double) -> T.Text
showInfo template prec width (incomingb, outgoingb) =
  let
    attribs = [ ("inB", show incomingb)
              , ("inKB", toKB prec width incomingb)
              , ("inMB", toMB prec width incomingb)
              , ("inAuto", toAuto prec width incomingb)
              , ("outB", show outgoingb)
              , ("outKB", toKB prec width outgoingb)
              , ("outMB", toMB prec width outgoingb)
              , ("outAuto", toAuto prec width outgoingb)
              ]
  in
    render . setManyAttrib attribs $ newSTMP template

toKB :: Int -> Int -> Double -> String
toKB prec width = setDigits prec width . (/1024)

toMB :: Int -> Int -> Double -> String
toMB prec width = setDigits prec width . (/ (1024 * 1024))

setDigits :: Int -> Int -> Double -> String
setDigits dig width = printf format
    where format = "%" ++ show width ++ "." ++ show dig ++ "f"

toAuto :: Int -> Int -> Double -> String
toAuto prec width value = printf "%*.*f%s" width p v unit
  where value' = max 0 value
        mag :: Int
        mag = if value' == 0 then 0 else max 0 $ min 4 $ floor $ logBase 1024 value'
        v = value' / 1024 ** fromIntegral mag
        unit = case mag of
          0 -> "B/s  "
          1 -> "KiB/s"
          2 -> "MiB/s"
          3 -> "GiB/s"
          4 -> "TiB/s"
          _ -> "??B/s" -- unreachable
        p :: Int
        p = max 0 $ floor $ fromIntegral prec - logBase 10 v

networkMonitorNew :: String -> Maybe [String] -> TaffyIO GI.Gtk.Widget
networkMonitorNew template interfaces = do
  NetworkInfoChan chan <- getNetworkChan
  let filterFn = maybe (const True) (flip elem) interfaces
  label <- lift $ labelNew Nothing
  void $ channelWidgetNew label chan $ \speedInfo ->
    let (up, down) = sumSpeeds $ map snd $ filter (filterFn . fst) speedInfo
        labelString = showInfo template 3 5 (fromRational down, fromRational up)
    in postGUIASync $ labelSetMarkup label labelString
  toWidget label
