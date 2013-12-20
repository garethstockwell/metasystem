-- Imports {{{
import XMonad

import XMonad.Actions.Plane

import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.UrgencyHook

import XMonad.Layout.Grid
import XMonad.Layout.ResizableTile
import XMonad.Layout.IM
import XMonad.Layout.ThreeColumns
import XMonad.Layout.NoBorders
import XMonad.Layout.Circle
import XMonad.Layout.PerWorkspace (onWorkspace)
import XMonad.Layout.Fullscreen

import XMonad.Util.EZConfig
import XMonad.Util.Run

import qualified XMonad.StackSet as W
--- }}}

myModMask                      = mod4Mask

myTerminal                     = "urxvt"

myNormalBorderColor            = "#dddddd"
myFocusedBorderColor           = "#ff0000"

myBorderWidth                  = 1

myFocusFollowsMouse :: Bool
myFocusFollowsMouse            = True

myWorkspaces =
    [
        "7:Chat", "8:Foo",  "9:Bar",
        "4:Docs", "5:Dev",  "6:Web",
        "1:Term", "2:",     "3:Mail"
    ]

startupWorkspace             = "5:Dev"

defaultLayouts = smartBorders(avoidStruts(
  -- ResizableTall layout has a large master window on the left,
  -- and remaining windows tile on the right. By default each area
  -- takes up half the screen, but you can resize using "super-h" and
  -- "super-l".
  ResizableTall 1 (3/100) (1/2) []

  -- Mirrored variation of ResizableTall. In this layout, the large
  -- master window is at the top, and remaining windows tile at the
  -- bottom of the screen. Can be resized as described above.
  ||| Mirror (ResizableTall 1 (3/100) (1/2) [])

  -- Full layout makes every window full screen. When you toggle the
  -- active window, it will bring the active window to the front.
  ||| noBorders Full

  -- Grid layout tries to equally distribute windows in the available
  -- space, increasing the number of columns and rows as necessary.
  -- Master window is at top left.
  ||| Grid

  -- ThreeColMid layout puts the large master window in the center
  -- of the screen. As configured below, by default it takes of 3/4 of
  -- the available space. Remaining windows tile to both the left and
  -- right of the master window. You can resize using "super-h" and
  -- "super-l".
  ||| ThreeColMid 1 (3/100) (3/4)

  -- Circle layout places the master window in the center of the screen.
  -- Remaining windows appear in a circle around it
  ||| Circle))

myLayouts = defaultLayouts


--- main {{{
main = do
    xmproc <- spawnPipe "xmobar ${HOME}/.xmonad/xmobar.hs"
    xmonad $ defaultConfig {
        modMask                  = myModMask

      , terminal                 = myTerminal

      , focusFollowsMouse        = myFocusFollowsMouse

      , borderWidth              = myBorderWidth
      , normalBorderColor        = myNormalBorderColor
      , focusedBorderColor       = myFocusedBorderColor

      , workspaces               = myWorkspaces

      , layoutHook               = myLayouts

      , startupHook = do
          windows $ W.greedyView startupWorkspace

      , logHook = dynamicLogWithPP xmobarPP
                      { ppOutput = hPutStrLn xmproc
                      , ppTitle = xmobarColor "green" "" . shorten 50
                      }
    }
--- }}}

