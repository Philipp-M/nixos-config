module Main where

import           XMonad
import           XMonad.Hooks.EwmhDesktops        (ewmh, fullscreenEventHook)
import           XMonad.Hooks.ManageDocks
import           System.Taffybar.Support.PagerHints (pagerHints) 

main = xmonad $
        docks $
        -- ewmh $
        pagerHints
        def
        { 
	  -- terminal = "st"
	  -- terminal = "alacritty"
	  terminal = "kitty"
	, borderWidth = 0
        , handleEventHook = fullscreenEventHook
	-- modMask = mod4Mask -- Use Super instead of Alt
        }

