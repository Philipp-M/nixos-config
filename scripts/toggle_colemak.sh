#!/bin/sh

IS_COLEMAK=$(setxkbmap -print -verbose 10 | grep -E "variant:\s*colemak")

if [[ (($1 = "us") || (-n $IS_COLEMAK)) && ($1 != "colemak") ]]; then
	setxkbmap us
elif [[ ($1 = "colemak") || (-z $IS_COLEMAK) ]]; then
	setxkbmap -layout us -variant colemak
fi

# repeat the keystrokes more often and faster
xset r rate 300 60

# map caps lock to escape (useful for vim)
xmodmap -e 'clear Lock' -e 'keycode 0x42 = Escape'
