import XMonad

main = xmonad $ defaultConfig {
      borderWidth = 2
    , terminal = "urxvt"
    , normalBorderColor = "#cccccc"
    , focusedBorderColor = "#cd8b00"
}

