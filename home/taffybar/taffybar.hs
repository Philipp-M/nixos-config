{-# LANGUAGE OverloadedStrings #-}

-- customized Widgets CPUMonitor and NetworkMonitor, probably merge upstream with pull request
import CPUMonitor
import NetworkMonitor
import System.Taffybar
import System.Taffybar.Information.CPU
import System.Taffybar.Information.Memory
import System.Taffybar.SimpleConfig
import System.Taffybar.Widget.SNITray
import System.Taffybar.Widget.SimpleClock
import System.Taffybar.Widget.Text.MemoryMonitor
import System.Taffybar.Widget.Windows
import System.Taffybar.Widget.Workspaces


main = do
  let clock = textClockNewWith defaultClockConfig
      cpuMon = textCpuMonitorNew "cpu: $total$% ▏" 1.5
      memMon = textMemoryMonitorNew "mem: $used$MB used ▏" 5
      netMon = networkMonitorNew "▏ net: $inAuto$ ▼ $outAuto$ ▲ ▏" Nothing
      windowsTitle =
        windowsNew
          WindowsConfig
            { getMenuLabel = truncatedGetMenuLabel 100,
              getActiveLabel = truncatedGetActiveLabel 100
            }
      workspaces =
        workspacesNew
          defaultWorkspacesConfig
            { getWindowIconPixbuf = scaledWindowIconPixbufGetter getWindowIconPixbufFromEWMH,
              showWorkspaceFn = hideEmpty
            }
      simpleConfig =
        defaultSimpleTaffyConfig
          { startWidgets = [workspaces],
            centerWidgets = [windowsTitle],
            endWidgets = [clock, cpuMon, memMon, netMon, sniTrayNew],
            barHeight = 30
          }
  simpleTaffybar simpleConfig
