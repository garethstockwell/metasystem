-- Imports {{{
import XMonad

import Control.Monad ( liftM2 )

import XMonad.Actions.Plane
import XMonad.Actions.SpawnOn
import XMonad.Actions.UpdatePointer
import XMonad.Actions.WorkspaceNames

import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers (isDialog, isFullscreen, doFullFloat, doCenterFloat)
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

import qualified Data.Map as M
import qualified XMonad.StackSet as W ( focusDown, sink, shift, greedyView )
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
        "1:dev",   "2:web",   "3:mail",
        "4:chat",  "5:music", "6:remote",
        "7:",      "8:",      "9:"
    ]

startupWorkspace             = "1:Dev"

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

myLayoutHook = avoidStruts $ defaultLayouts

myManageHook :: ManageHook
myManageHook = composeAll $ concat
    [ [ manageDocks ]
    , [ manageHook defaultConfig ]

    , [ isDialog --> doCenterFloat ]
    , [ isFullscreen --> doF W.focusDown <+> doFullFloat ]

    , [className =? c --> doFloat | c <- myCFloats]
    , [title =? t --> doFloat | t <- myTFloats]
    , [resource =? r --> doFloat | r <- myRFloats]

    , [(className =? i <||> resource =? i) --> doIgnore | i <- myIgnores]

    , [(className =? x <||> title =? x <||> resource =? x) --> doSink | x <- mySinks]
    , [(className =? x <||> title =? x <||> resource =? x) --> doFullFloat | x <- myFullscreens]

    --, [(className =? x <||> title =? x <||> resource =? x) --> doShift "1:dev" | x <- myShiftsDev]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShift "2:web" | x <- myShiftsWeb]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShift "3:mail" | x <- myShiftsMail]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShift "4:chat" | x <- myShiftsChat]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShift "5:music" | x <- myShiftsMusic]
    , [(className =? x <||> title =? x <||> resource =? x) --> doShift "6:remote" | x <- myShiftsRemote]
    --, [(className =? x <||> title =? x <||> resource =? x) --> doShift "7" | x <- myShifts7]
    --, [(className =? x <||> title =? x <||> resource =? x) --> doShift "8" | x <- myShifts8]
    --, [(className =? x <||> title =? x <||> resource =? x) --> doShift "9" | x <- myShifts9]

    ] where

    -- Hook used to shift windows without focusing them
    --doShiftAndGo = doF . liftM2 (.) W.greedyView W.shift
    -- Hook used to push floating windows back into the layout
    -- This is used for gimp windwos to force them into a layout.
    doSink = ask >>= \w -> liftX (reveal w) >> doF (W.sink w)
    -- Float dialogs, Download windows and Save dialogs
    myCFloats = ["Sysinfo", "XMessage"]
    myTFloats = ["Downloads", "Save As..."]
    myRFloats = ["Dialog"]
    -- Ignore gnome leftovers
    myIgnores = ["Unity-2d-panel", "Unity-2d-launcher", "desktop_window", "kdesktop"]
    mySinks = ["gimp"]
    -- Run VLC, firefox and VLC on fullscreen
    myFullscreens = ["vlc", "Image Viewer", "firefox"]
    -- Define default workspaces for some programs
    --myShiftsDev = []
    myShiftsWeb = ["Firefox-bin", "Firefox", "firefox", "Firefox Web Browser"]
    myShiftsMail = ["thunderbird", "Thunderbird-bin", "thunderbird-bin", "Thunderbird"]
    myShiftsChat = ["Pidgin Internet Messenger", "Buddy List", "pidgin", "Pidgin", "skype", "skype-wrapper", "Skype"]
    myShiftsMusic = ["spotify"]
    myShiftsRemote = ["remmina"]
    --myShifts7 = []
    --myShifts8 = []
    --myShifts9 = []

myRestart :: String
myRestart = "for pid in $(pgrep dzen2); do kill -9 $pid; done && for pid in $(pgrep conky); do kill -9 $pid; done && xmonad --recompile && xmonad --restart"

myKeys = [ ("M-S-<Backspace>", spawn "xscreensaver-command -lock")

         , ("M-q", spawn myRestart)

         ]

myDzenStyle  = " -h '18' -y '0' -fg '#777777' -bg '#222222'"

-- Place on first monitor (-xs 1)
myDzenStatus = "dzen2 -p -xs 1 -ta l" ++ myDzenStyle

-- Place on second monitor (-xs 2)
myDzenConky  = "conky -c ~/.xmonad/conkyrc | dzen2 -p -xs 2 -ta r" ++ myDzenStyle

myLogHook status = workspaceNamesPP defaultPP {
      ppOutput  = hPutStrLn status
    , ppCurrent = dzenColor "#3399ff" "" . wrap " " " "
    , ppHidden  = dzenColor "#dddddd" "" . wrap " " " "
    , ppHiddenNoWindows = dzenColor "#777777" "" . wrap " " " "
    , ppUrgent  = dzenColor "#ff0000" "" . wrap " " " "
    , ppSep     = "  "
    , ppLayout  = \y -> ""
    , ppTitle   = dzenColor "#ffffff" "" . wrap " " " "
    } >>= dynamicLogWithPP >> updatePointer Nearest

myStartupHook = do
	spawnOn "1:dev" myTerminal

	spawnOn "2:web" "firefox"

	spawnOn "4:chat" "pidgin"
	spawnOn "4:chat" "skype"

	--spawnOn "5:music" "spotify"

	spawnOn "6:remote" "remmina"

--- main {{{
main = do

    status <- spawnPipe myDzenStatus
    conky  <- spawnPipe myDzenConky

    xmonad $ defaultConfig {
        modMask                  = myModMask

      , terminal                 = myTerminal

      , focusFollowsMouse        = myFocusFollowsMouse

      , borderWidth              = myBorderWidth
      , normalBorderColor        = myNormalBorderColor
      , focusedBorderColor       = myFocusedBorderColor

      , workspaces               = myWorkspaces

      , layoutHook               = myLayoutHook

      , manageHook               = myManageHook

      , startupHook				 = myStartupHook

      , logHook                  = myLogHook status

    } `additionalKeysP` myKeys
--- }}}

