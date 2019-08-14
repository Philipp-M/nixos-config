#!/bin/bash

(cat ; (stest -flx $(echo $PATH | tr : ' ') | sort -u)) | rofi -dmenu -matching fuzzy -i -sort -levenshtein-sort
