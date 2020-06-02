{-# LANGUAGE OverloadedStrings #-}

import System.Taffybar
import System.Taffybar.Information.CPU
import System.Taffybar.SimpleConfig
import System.Taffybar.Widget
import System.Taffybar.Widget.Generic.Graph
import System.Taffybar.Widget.Generic.PollingGraph
import System.Taffybar.Widget.SNITray

cpuCallback = do
  (_, systemLoad, totalLoad) <- cpuLoad
  return [totalLoad, systemLoad]

main = do
  let cpuCfg =
        defaultGraphConfig
          { graphDataColors = [(0, 1, 0, 1), (1, 0, 1, 0.5)],
            graphLabel = Just "cpu"
          }
      clock = textClockNewWith defaultClockConfig
      cpu = pollingGraphNew cpuCfg 1.5 cpuCallback
      workspaces =
        workspacesNew
          defaultWorkspacesConfig
            { getWindowIconPixbuf = scaledWindowIconPixbufGetter getWindowIconPixbufFromEWMH
            }
      simpleConfig =
        defaultSimpleTaffyConfig
          { startWidgets = [workspaces],
            endWidgets = [clock, cpu, sniTrayThatStartsWatcherEvenThoughThisIsABadWayToDoIt],
            barHeight = 30
          }
  simpleTaffybar simpleConfig
