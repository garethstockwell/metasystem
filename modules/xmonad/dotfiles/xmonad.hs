-- xmonad.hs
--
-- Based on content from
--     http://pbrisbin.com
--     http://www.untaken.org/my-perfect-xmonad-setup/
--     https://github.com/davidbrewer/xmonad-ubuntu-conf
--     http://blog.liangzan.net/blog/2012/01/19/my-solarized-themed-arch-linux-setup/

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

import XMonad

import Control.Exception as E
import Control.Monad ( liftM2 )

import Data.Char ( toLower )
import Data.List ( intercalate )

import System.Environment ( getEnv )
import System.IO.Unsafe ( unsafePerformIO )

import XMonad.Actions.Plane
import XMonad.Actions.SpawnOn
import XMonad.Actions.UpdatePointer
import XMonad.Actions.WorkspaceNames

import XMonad.Hooks.DynamicLog
import XMonad.Hooks.FadeInactive
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers ( isDialog, isFullscreen,
                                    doFullFloat, doCenterFloat )
import XMonad.Hooks.UrgencyHook

import XMonad.Layout.Circle
import XMonad.Layout.Grid
import XMonad.Layout.Fullscreen
import XMonad.Layout.IndependentScreens ( countScreens )
import XMonad.Layout.IM
import XMonad.Layout.NoBorders
import XMonad.Layout.PerWorkspace ( onWorkspace )
import XMonad.Layout.ResizableTile
import XMonad.Layout.ThreeColumns

import XMonad.Util.EZConfig
import XMonad.Util.NamedWindows
import XMonad.Util.Run

import qualified Data.Map as M
import qualified XMonad.StackSet as W ( findTag, focusDown,
                                        sink, shift, greedyView )


-------------------------------------------------------------------------------
-- Environment
-------------------------------------------------------------------------------

-- Ask the shell environment for the value of a variable in XMonad's environment, with a
-- default value.
-- In order to /set/ an environment variable (eg. combine with a prompt so you can modify
-- @$HTTP_PROXY@ dynamically), you need to use 'System.Posix.putEnv'.
--
-- From http://xmonad.org/xmonad-docs/xmonad-contrib/src/XMonad-Prompt-Shell.html
--

econst :: Monad m => a -> IOException -> m a
econst = const . return

env :: String -> String -> IO String
env variable fallthrough = getEnv variable `E.catch` econst fallthrough


-------------------------------------------------------------------------------
-- Basic setup
-------------------------------------------------------------------------------

myModMask                      = mod4Mask

myTerminal                     = "urxvt"

--myBrowser                      = "firefox"
myBrowser                      = "google-chrome"

myFocusFollowsMouse :: Bool
myFocusFollowsMouse            = True


-------------------------------------------------------------------------------
-- Workspaces
-------------------------------------------------------------------------------

myWorkspaceTerm                = "1:term"
myWorkspaceWeb                 = "2:web"
myWorkspaceEdit                = "3:edit"
myWorkspaceTarget              = "4:target"
myWorkspaceMail                = "5:mail"
myWorkspaceChat                = "6:chat"
myWorkspaceMusic               = "7:music"
myWorkspaceRemote              = "8:remote"
myWorkspaceMisc                = "9:misc"

myWorkspaces =
    [ myWorkspaceTerm
    , myWorkspaceWeb
    , myWorkspaceEdit
    , myWorkspaceTarget
    , myWorkspaceMail
    , myWorkspaceChat
    , myWorkspaceMusic
    , myWorkspaceRemote
    , myWorkspaceMisc
    ]

startupWorkspace             = myWorkspaceTerm


-------------------------------------------------------------------------------
-- Theme
-------------------------------------------------------------------------------

-- Solarized
colorBase03                  = "#002b36"
colorBase02                  = "#073642"
colorBase01                  = "#586e75"
colorBase00                  = "#657b83"
colorBase0                   = "#839496"
colorBase1                   = "#93a1a1"
colorBase2                   = "#eee8d5"
colorBase3                   = "#fdf6e3"
colorYellow                  = "#b58900"
colorOrange                  = "#cb4b16"
colorRed                     = "#dc322f"
colorMagenta                 = "#d33682"
colorViolet                  = "#6c71c4"
colorBlue                    = "#268bd2"
colorCyan                    = "#2aa198"
colorGreen                   = "#859900"

colorBackground              = colorBase03
colorForeground              = colorBase00

colorNormalBorder            = "#dddddd"
colorFocusedBorder           = "#ff0000"

fontXft                      = "xft:inconsolta"

fontDmenu                    = fontXft ++ ":pixelsize=12"


-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------

heightStatus                 = 18

widthBorder                  = 1

widthTray                    = 180

widthStatusSingle            = 640


-------------------------------------------------------------------------------
-- LayoutHook
-------------------------------------------------------------------------------

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


-------------------------------------------------------------------------------
-- ManageHook
-------------------------------------------------------------------------------

-- See http://pbrisbin.com/posts/lazy_haskell/

liftAny p list = foldr ((<||>) . p) (return False) list

matchAny :: String -> Query Bool
matchAny s = liftAny (=? s) [ fmap (map toLower) className ]

myManageShift = composeAll
    [ liftAny matchAny s
      <&&> fmap not isDialog
      --> action | (s, action) <- myActions
    ] where
        myActions = [
              (myClassesIgnore,    doIgnore)

            , (myClassesSink,      doSink)

            , (myClassesTerm,      doShift myWorkspaceTerm)
            , (myClassesWeb,       doShift myWorkspaceWeb)
            , (myClassesEdit,      doShift myWorkspaceEdit)
            , (myClassesTarget,    doShift myWorkspaceTarget)
            , (myClassesMail,      doShift myWorkspaceMail)
            , (myClassesChat,      doShift myWorkspaceChat)
            , (myClassesMusic,     doShift myWorkspaceMusic)
            , (myClassesRemote,    doShift myWorkspaceRemote)
            , (myClassesMisc,      doShift myWorkspaceMisc)
            ]
        myClassesIgnore    = [ "unity-2d-panel", "unity-2d-launcher"
                             , "desktop-window"
                             , "kdesktop"
                             ]

        myClassesSink      = [ "gimp" ]

        myClassesTerm      = [ myTerminal ]
        myClassesWeb       = [ myBrowser ]
        myClassesEdit      = [ "adt", "atom", "eclipse", "gvim" ]
        myClassesTarget    = [ "gvncviewer", "qemu", "xterm" ]
        myClassesMail      = [ "thunderbird" ]
        myClassesChat      = [ "pidgin", "skype" ]
        myClassesMusic     = [ "spotify" ]
        myClassesRemote    = [ "remmina", "vmplayer" ]
        myClassesMisc      = [ ]

        -- Hook used to shift windows without focusing them
        --doShiftAndGo = doF . liftM2 (.) W.greedyView W.shift

        -- Hook used to push floating windows back into the layout
        -- This is used for gimp windwos to force them into a layout.
        doSink = ask >>= \w -> liftX (reveal w) >> doF (W.sink w)


myManageHook :: ManageHook
myManageHook = (composeAll $ concat
    [ [ manageHook defaultConfig ]
    , [ manageSpawn ]
    , [ isDialog --> doCenterFloat ]
    , [ isFullscreen --> doF W.focusDown <+> doFullFloat ]
    ] )
    <+> manageDocks
    <+> myManageShift
    where


-------------------------------------------------------------------------------
-- Keys
-------------------------------------------------------------------------------

myTerminalMux = myTerminal ++ " -e tmux attach -t default"

binPath = unsafePerformIO $ env "METASYSTEM_XMONAD_BIN" "???"
myVolume = binPath ++ "/xmonad-volume.sh"
myVolumeUp = myVolume ++ " up --level"
myVolumeDown = myVolume ++ " down --level"
myVolumeMute = myVolume ++ " mute --level"

myKeys = [ ("M-S-<Backspace>", spawn "xscreensaver-command -lock")
         , ("M-S-t",           spawnHere myTerminal)
         , ("M-S-<Return>",    spawnHere myTerminalMux)
         , ("M-S-b",           spawnHere myBrowser)
         , ("M-p",             spawnHere myDmenuRun)

         , ("M-S-<Up>",        spawn myVolumeUp)
         , ("M-S-<Down>",      spawn myVolumeDown)
         , ("M-S-m",           spawn myVolumeMute)
         ]


-------------------------------------------------------------------------------
-- Dmenu
-------------------------------------------------------------------------------

myDmenuStyle = "-fn '" ++ fontDmenu ++ "'"

myDmenuRun = "dmenu_run " ++ myDmenuStyle


-------------------------------------------------------------------------------
-- Status bar
--
-- Single monitor:
--     left: status
--     right - N: conky
--     right: tray
--
-- Dual monitor:
-- Monitor 1:
--     left: status
--     right: tray
-- Monitor 2:
--     left: conky
-------------------------------------------------------------------------------

myDzenStyle  = "-h '" ++ show heightStatus ++ "' " ++
               "-y '0' " ++
               "-dock "

myDzenStatus = "dzen2 -p "

myDzenStatusSingle = intercalate " "
                         [ myDzenStatus,
                           "-x",         "0",
                           "-w",         show widthStatusSingle,
                           "-ta",        "l",
                           myDzenStyle
                         ]

myDzenStatusMultiple = intercalate " "
                         [ myDzenStatus,
                           "-xs",        "1",
                           "-ta",        "l",
                           myDzenStyle
                         ]

myDzenConky = "conky -c ~/.xmonad/conkyrc | dzen2 -p "

myDzenConkySingle = intercalate " "
                         [ myDzenConky,
                           "-x",         show widthStatusSingle,
                           "-w",         show widthStatusSingle,
                           "-ta",        "r",
                           myDzenStyle ]

myDzenConkyMultiple = intercalate " "
                         [ myDzenConky,
                           "-xs",        "2",
                           "-ta",        "r",
                           myDzenStyle
                         ]

myTrayer = intercalate " "
               [ "trayer",
                 "--edge",               "top",
                 "--align",              "right",
                 "--SetDockType",        "true",
                 "--SetPartialStrut",    "true",
                 "--expand",             "true",
                 "--widthtype",          "pixel",
                 "--width",              show widthTray,
                 "--heighttype",         "pixel",
                 "--height",             show heightStatus,
                 "--transparent",        "true",
                 "--alpha",              "0",
                 "--tint",               colorBackground
               ]


-------------------------------------------------------------------------------
-- LogHook
-------------------------------------------------------------------------------

-- Set fadeAmount to < 1.0 to make unfocussed windows semi-transparent

myLogFade :: X ()
myLogFade = fadeInactiveLogHook fadeAmount
    where fadeAmount = 1.0

myLogHook status = workspaceNamesPP defaultPP {
      ppOutput  = hPutStrLn status
    , ppCurrent = dzenColor colorBlue "" . wrap " " " "
    , ppHidden  = dzenColor colorBase0 "" . wrap " " " "
    , ppHiddenNoWindows = dzenColor colorBase2 "" . wrap " " " "
    , ppUrgent  = dzenColor colorRed "" . wrap " " " "
    , ppSep     = "  "
    , ppLayout  = \y -> ""
    , ppTitle   = dzenColor colorForeground "" . wrap " " " "
    }
    >>= dynamicLogWithPP
    >> updatePointer (Relative 0.5 0.5)
    >> myLogFade


-------------------------------------------------------------------------------
-- UrgencyHook
-------------------------------------------------------------------------------

data LibNotifyUrgencyHook = LibNotifyUrgencyHook deriving (Read, Show)

instance UrgencyHook LibNotifyUrgencyHook where
    urgencyHook LibNotifyUrgencyHook w = do
        name     <- getName w
        Just idx <- fmap (W.findTag w) $ gets windowset

        safeSpawn "notify-send" [show name, "workspace " ++ idx]


-------------------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------------------

-- Zombie slaying
myRestart :: String
myRestart = "/usr/bin/killall -9 dzen2; " ++
            "/usr/bin/killall -9 conky; " ++
            "/usr/bin/killall -9 trayer; " ++
            "xmonad --recompile && xmonad --restart"


-------------------------------------------------------------------------------
-- Main
-------------------------------------------------------------------------------

main = do

    nScreens <- countScreens

    status <- case nScreens of
        1 -> spawnPipe myDzenStatusSingle
        _ -> spawnPipe myDzenStatusMultiple

    conky <- case nScreens of
        1 -> spawnPipe myDzenConkySingle
        _ -> spawnPipe myDzenConkyMultiple

    tray  <- spawnPipe myTrayer

    xmonad
        $ withUrgencyHook LibNotifyUrgencyHook
        $ defaultConfig
            { modMask                  = myModMask
            , terminal                 = myTerminal
            , focusFollowsMouse        = myFocusFollowsMouse
            , borderWidth              = widthBorder
            , normalBorderColor        = colorNormalBorder
            , focusedBorderColor       = colorFocusedBorder
            , workspaces               = myWorkspaces
            , layoutHook               = myLayoutHook
            , manageHook               = myManageHook
            , logHook                  = myLogHook status
            } `additionalKeysP` myKeys

