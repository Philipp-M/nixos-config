# Overview

This file describes my xmonad config, most notably my current keybindings

## Key bindings

The <kbd>mod</kbd> key is currently mapped to <kbd>Super</kbd>

Most of the following keybindings are still the default bindings, with optimized colemak flavor.

### Action key bindings

| Key binding                                             | Action                                                                        |
|---------------------------------------------------------|-------------------------------------------------------------------------------|
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>slash</kbd>  | Run xmessage with a summary of the default keybindings (useful for beginners) |
| <kbd>mod</kbd> - <kbd>return</kbd>                      | Launch terminal                                                               |
| <kbd>mod</kbd> - <kbd>c</kbd>                           | Launch chromium                                                               |
| <kbd>mod</kbd> - <kbd>space</kbd>                       | Launch rofi                                                                   |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>p</kbd>      | Launch gmrun                                                                  |
| <kbd>mod</kbd> - <kbd>backspace</kbd>                   | Close the focused window                                                      |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>q</kbd>      | Quit xmonad                                                                   |
| <kbd>mod</kbd> - <kbd>q</kbd>                           | Restart xmonad                                                                |

### Movement key bindings

#### Window Movement key bindings

| Key binding                                             | Action                                                                        |
|---------------------------------------------------------|-------------------------------------------------------------------------------|
| <kbd>mod</kbd> - <kbd>n</kbd>                           | Rotate through the available layout algorithms                                |
| <kbd>mod</kbd> - <kbd>f</kbd>                           | Toggle Full Layout with no topbar                                             |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>space</kbd>  | Reset the layouts on the current workspace to default                         |
| <kbd>mod</kbd> - <kbd>n</kbd>                           | Resize viewed windows to the correct size                                     |
| <kbd>mod</kbd> - <kbd>escape</kbd>                      | Move focus to the next window                                                 |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>escape</kbd> | Move focus to the previous window                                             |
| <kbd>mod</kbd> - <kbd>k</kbd>                           | Move focus to the next window                                                 |
| <kbd>mod</kbd> - <kbd>h</kbd>                           | Move focus to the previous window                                             |
| <kbd>mod</kbd> - <kbd>m</kbd>                           | Move focus to the master window                                               |
| <kbd>mod</kbd> - <kbd>p</kbd>                           | Promote the focused window to the master area and toggle between next window  |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>k</kbd>      | Swap the focused window with the next window                                  |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>h</kbd>      | Swap the focused window with the previous window                              |
| <kbd>mod</kbd> - <kbd>j</kbd>                           | Shrink the master area                                                        |
| <kbd>mod</kbd> - <kbd>l</kbd>                           | Expand the master area                                                        |
| <kbd>mod</kbd> - <kbd>t</kbd>                           | Push window back into tiling                                                  |
| <kbd>mod</kbd> - <kbd>comma</kbd>                       | Increment the number of windows in the master area                            |
| <kbd>mod</kbd> - <kbd>period</kbd>                      | Deincrement the number of windows in the master area                          |

#### Window Movement key and mouse button bindings

| Binding                                                 | Action                                                                        |
|---------------------------------------------------------|-------------------------------------------------------------------------------|
| <kbd>mod</kbd> - <kbd>button1</kbd>                     | Set the window to floating mode and move by dragging                          |
| <kbd>mod</kbd> - <kbd>button3</kbd>                     | Set the window to floating mode and resize by dragging                        |
| <kbd>mod</kbd> - <kbd>button2</kbd>                     | Raise the window to the top of the stack                                      |

#### Workspace Movement key bindings

| Key binding                                             | Action                                                                        |
|---------------------------------------------------------|-------------------------------------------------------------------------------|
| <kbd>mod</kbd> - <kbd>[1..9]</kbd>                      | Switch to workspace N                                                         |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>[1..9]</kbd> | Move client to workspace N                                                    |

#### Screen Movement key bindings
| Key binding                                             | Action                                                                        |
|---------------------------------------------------------|-------------------------------------------------------------------------------|
| <kbd>mod</kbd> - <kbd>=</kbd>                           | Switch to the next screen                                                     |
| <kbd>mod</kbd> - <kbd>shift</kbd> - <kbd>=</kbd>        | Move client to the next screen                                                |
| <kbd>mod</kbd> - <kbd>{w,e,r}</kbd>                     | Switch to physical/Xinerama screens 1, 2, or 3                                |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>{w,e,r}</kbd>| Move client to screen 1, 2, or 3                                              |
