# Overview

These are my personal dotfiles, which represent my current setup with *NixOS*.

The current state of these dotfiles is a hybrid of a *NixOS* configuration (in `nixos`) and [rcm](https://github.com/thoughtbot/rcm) managed config files.
The plan is to refactor all possible rcm managed config files into the *NixOS* configuration in the future, to have a completely functional setup.

Currently following notable applications/configs are in use and completely managed via the *NixOS* configuration:

* autorandr
* alacritty
* fish
* git
* picom (using tryone144s *dual_kawase* blur fork)
* redshift
* starship
* taffybar
* xmonad
* rofi

Following applications/configs are in use and managed via rcm:

* neovim
* mpv
* XResources

Following applications/configs are configured, but currently not in use and might be out of sync (and probably be removed in the near future):

* i3
* polybar
* kitty
* fish (old config)
* alacritty (old config)
* mpd
* picom (old config)
* autorandr (old config)
* scripts directory in general
* xprofile
* xinitrc

## *NixOS* Configuration

The configuration for my machines are in `nixos/machines/`.

Following machines are configured:

* zen

Most (user) applications are configured in `nixos/home.nix`.

The main system configuration for all machines is in `nixos/configuration.nix`.
