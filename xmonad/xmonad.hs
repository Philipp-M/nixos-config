module Main where

import           XMonad
import           XMonad.Hooks.EwmhDesktops        (ewmh, fullscreenEventHook)
import           XMonad.Hooks.ManageDocks
-- import           XMonad.Layout.Spacing
import           System.Taffybar.Support.PagerHints (pagerHints) 

main = xmonad $
        docks $
        ewmh $
        pagerHints
        def
        { 
	  -- terminal = "st"
	  -- terminal = "alacritty"
	  terminal = "kitty"
	, borderWidth = 0
        , handleEventHook = handleEventHook def <+> fullscreenEventHook
        , manageHook = manageDocks <+> manageHook def
        , layoutHook = avoidStruts $ layoutHook def
        -- , layoutHook = spacingRaw True (Border 0 10 10 10) True (Border 10 10 10 10) True $ avoidStruts $ layoutHook def
	, modMask = mod4Mask -- Use Super instead of Alt
        }
