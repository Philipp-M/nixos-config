{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Main where

import System.Taffybar.Support.PagerHints (pagerHints)
import XMonad
import XMonad.Actions.Promote
import XMonad.Hooks.EwmhDesktops (ewmh, fullscreenEventHook)
import XMonad.Hooks.ManageDocks
import XMonad.Layout.MultiToggle
import XMonad.Layout.MultiToggle.Instances
import XMonad.Layout.NoBorders (smartBorders)
import XMonad.Layout.Dwindle
import XMonad.Layout.StackTile
import qualified XMonad.StackSet as W
import XMonad.Util.EZConfig

myLayouts =
  id
    . mkToggle (NOBORDERS ?? FULL ?? EOT)
    . mkToggle (single MIRROR)
    $ avoidStruts
    $ tiled
      ||| (Mirror tiled)
      ||| (Dwindle R CW 1.5 1.1)
      ||| (Full)
  where
    tiled = Tall nmaster delta ratio -- default master pane layout
    nmaster = 1
    ratio = 1 / 2
    delta = 3 / 100

myKeybindings =
  [ ("M-c", spawn "chromium"),
    ("M-<Backspace>", kill),
    ("M-<Return>", spawn myTerminal),
    ("M-<Space>", spawn myLauncher),
    ("M-f", sendMessage $ Toggle FULL),
    ("M-n", sendMessage NextLayout),
    ("M-p", promote),
    ("M-k", windows W.focusDown),
    ("M-h", windows W.focusUp),
    ("M-S-h", windows W.swapUp),
    ("M-S-k", windows W.swapDown),
    ("M-j", sendMessage Shrink),
    ("M-l", sendMessage Expand),
    ("M-<Esc>", windows W.focusDown),
    ("M-S-<Esc>", windows W.focusUp)
  ]

myTerminal = "alacritty"

myLauncher = "rofi -show run"

main =
  xmonad
    $ docks
    $ ewmh
    $ pagerHints
      def
        { terminal = myTerminal,
          borderWidth = 0,
          handleEventHook = handleEventHook def <+> fullscreenEventHook,
          manageHook = manageDocks <+> manageHook def,
          layoutHook = myLayouts,
          modMask = mod4Mask -- Use Super instead of Alt
        }
      `additionalKeysP` myKeybindings
