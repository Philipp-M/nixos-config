{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Main where

import XMonad
import XMonad.Actions.Promote
import XMonad.Actions.CycleWS (nextScreen, shiftNextScreen)
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen)
import XMonad.Hooks.ManageDocks
import XMonad.Layout.MultiToggle
import XMonad.Layout.MultiToggle.Instances
import XMonad.Layout.NoBorders (smartBorders, noBorders)
import XMonad.Layout.NoFrillsDecoration
import XMonad.Layout.Spacing
import XMonad.Layout.Dwindle
import XMonad.Layout.Reflect
import XMonad.Layout.StackTile
import qualified XMonad.StackSet as W
import XMonad.Util.EZConfig
import XMonad.Hooks.SetWMName

mySpacing = spacingRaw True (Border 5 5 5 5) True (Border 5 5 5 5) True

topbarHeight = 7

black  = "#{{base00}}"
white  = "#{{base06}}"
red    = "#{{base08}}"
green  = "#{{base0B}}"
yellow = "#{{base0A}}"
blue   = "#{{base0D}}"
active = blue


topBarTheme = def
    { inactiveBorderColor   = black
    , inactiveColor         = black
    , inactiveTextColor     = black
    , activeBorderColor     = active
    , activeColor           = active
    , activeTextColor       = active
    , urgentBorderColor     = red
    , urgentTextColor       = yellow
    , decoHeight            = topbarHeight
    }

addTopBar = noFrillsDeco shrinkText topBarTheme

myLayouts = smartBorders $ mkToggle (single NBFULL)
    $ avoidStruts
    $ addTopBar
    $ mySpacing
    $ tiled
      ||| reflectHoriz tiled
      ||| Dwindle R CW 1 1.1
      -- ||| Dwindle L CW 1.5 1.1
      -- currently only use 2 layouts: Dwindle and tiled
  where
    tiled = Tall nmaster delta ratio -- default master pane layout
    nmaster = 1
    ratio = 1 / 2
    delta = 3 / 100

myKeybindings =
  -- [ ("M-w", spawn "chromium"),
  [ ("M-w", spawn "env MOZ_USE_XINPUT2=1 firefox"),
    ("M-<Backspace>", kill),
    ("M-<Return>", spawn myTerminal),
    ("M-<Space>", spawn myLauncher),
    ("M-f", sendMessage $ Toggle NBFULL),
    ("M-n", sendMessage NextLayout),
    ("M-i", spawn "toggle-light"),
    ("M-p", promote),
    ("M-=", nextScreen),
    ("M-S-=", shiftNextScreen),
    ("M-k", windows W.focusDown),
    ("M-h", windows W.focusUp),
    ("M-S-h", windows W.swapUp),
    ("M-S-k", windows W.swapDown),
    ("M-j", sendMessage Shrink),
    ("M-l", sendMessage Expand),
    ("M-<Esc>", windows W.focusDown),
    ("M-S-<Esc>", windows W.focusUp),
    ("<XF86AudioPlay>", spawn "mpc toggle")
  ]

myTerminal = "kitty"

myLauncher = "rofi -show run"

main =
  xmonad
    $ ewmhFullscreen
    $ ewmh
    $ docks
    -- $ pagerHints
      def
        { terminal = myTerminal,
          borderWidth = 0,
          manageHook = manageDocks <+> manageHook def,
          layoutHook = myLayouts,
          startupHook = setWMName "LG3D",
          modMask = mod4Mask -- Use Super instead of Alt
        }
      `additionalKeysP` myKeybindings
