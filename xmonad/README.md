# Overview

This file describes my xmonad config, most notably my current keybindings

## Key bindings

The following keybindings are still the default bindings, with subject to change

The <kbd>mod</kbd> key is currently the default <kbd>alt</kbd>

### Action key bindings

| Key binding                                             | Action                                                                        |
|---------------------------------------------------------|-------------------------------------------------------------------------------|
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>slash</kbd>  | Run xmessage with a summary of the default keybindings (useful for beginners) |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>return</kbd> | Launch terminal                                                               |
| <kbd>mod</kbd> - <kbd>p</kbd>                           | Launch dmenu                                                                  |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>p</kbd>      | Launch gmrun                                                                  |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>c</kbd>      | Close the focused window                                                      |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>q</kbd>      | Quit xmonad                                                                   |
| <kbd>mod</kbd> - <kbd>q</kbd>                           | Restart xmonad                                                                |

### Movement key bindings

#### Window Movement key bindings

| Key binding                                             | Action                                                                        |
|---------------------------------------------------------|-------------------------------------------------------------------------------|
| <kbd>mod</kbd> - <kbd>space</kbd>                       | Rotate through the available layout algorithms                                |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>space</kbd>  | Reset the layouts on the current workspace to default                         |
| <kbd>mod</kbd> - <kbd>n</kbd>                           | Resize viewed windows to the correct size                                     |
| <kbd>mod</kbd> - <kbd>tab</kbd>                         | Move focus to the next window                                                 |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>tab</kbd>    | Move focus to the previous window                                             |
| <kbd>mod</kbd> - <kbd>j</kbd>                           | Move focus to the next window                                                 |
| <kbd>mod</kbd> - <kbd>k</kbd>                           | Move focus to the previous window                                             |
| <kbd>mod</kbd> - <kbd>m</kbd>                           | Move focus to the master window                                               |
| <kbd>mod</kbd> - <kbd>return</kbd>                      | Swap the focused window and the master window                                 |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>j</kbd>      | Swap the focused window with the next window                                  |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>k</kbd>      | Swap the focused window with the previous window                              |
| <kbd>mod</kbd> - <kbd>h</kbd>                           | Shrink the master area                                                        |
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
| <kbd>mod</kbd> - <kbd>{w,e,r}</kbd>                     | Switch to physical/Xinerama screens 1, 2, or 3                                |
| <kbd>mod</kbd> - <kbd>shift</kbd>   - <kbd>{w,e,r}</kbd>| Move client to screen 1, 2, or 3                                              |
