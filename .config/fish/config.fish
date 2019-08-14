alias ll 'lsd -Al' 
alias lld 'lsd -Altr' 
alias llt 'lsd -Altr --tree' 
alias lls 'lsd -ArlS --total-size' 
alias l 'll'
alias lsblka 'lsblk --output NAME,LABEL,UUID,SIZE,MODEL,MOUNTPOINT,FSTYPE'
alias tree 'tree -C'
alias cdgo 'cd $HOME/Development/go/src' 
alias cdrust 'cd $HOME/Development/rust/' 
alias cdpy 'cd $HOME/Development/python'
alias cddocker 'cd $HOME/Development/docker/' 
alias cddev 'cd $HOME/Development' 
alias cdwww 'cd $HOME/Development/www' 
alias cdpro 'cd $HOME/Development/projects' 
alias cdvox 'cd $HOME/Development/projects/voxinfinity' 
alias cdvue 'cd $HOME/Development/vue/'
alias cdeth 'cd $HOME/Development/ethereumBased'
alias cdvul 'cd $HOME/Development/vulkan' 
alias cdgql 'cd $HOME/Development/GraphQL' 
alias cdwork 'cd $HOME/Development/work' 
alias cdnode 'cd $HOME/Development/nodeBased' 
alias cdml 'cd $HOME/Development/MachineLearning' 
alias cduni 'cd $HOME/Uni/' 
alias cdrand 'cd $HOME/Development/randomStuff/' 
alias cdsmall 'cd $HOME/Development/randomStuff/small' 
alias cdray 'cd $HOME/Development/rayTracing/' 
alias cdandroid 'cd $HOME/Development/Android/' 
alias countlinesr 'grep -r "" ./ | wc -l'
alias cdate 'date +%Y%m%d%H%M'
alias du_s 'du -h | sort -h'

alias rsyncp 'rsync --info=progress2'
alias sudoe 'sudo -E'

set -gx GOPATH $HOME/Development/go

set -gx NPM_PACKAGES $HOME/.npm-packages


# Unset manpath so we can inherit from /etc/manpath via the `manpath` command
set -e MANPATH # delete if you already modified MANPATH elsewhere in your config
set -gx MANPATH $NPM_PACKAGES/share/man:(manpath)

set -gx PATH $PATH /usr/bin/
set -gx PATH $PATH $HOME/bin/
set -gx PATH $PATH $HOME/.local/bin/
set -gx PATH $PATH $HOME/.cargo/bin/
set -gx PATH $PATH /opt/cuda/bin/
set -gx PATH $PATH /usr/bin/core_perl/
set -gx PATH $PATH $HOME/.gem/ruby/2.3.0/bin/
set -gx PATH $PATH $HOME/.gem/ruby/2.5.0/bin/
set -gx PATH $PATH $HOME/.config/yarn/global/node_modules/.bin
set -gx PATH $PATH ./node_modules/.bin
set -gx PATH $PATH $HOME/Development/go/bin
set -gx PATH $PATH $HOME/.yarn-global
set -gx PATH $NPM_PACKAGES/bin:$PATH

set -x LESSOPEN '| sh /usr/bin/src-hilite-lesspipe.sh %s'
set -x LESS '-R'
set -x PYTHONIOENCODING 'utf8'
set -gx CC clang
set -gx CXX clang++
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx HOMEDIR $HOME/
set -gx QT_QPA_PLATFORMTHEME "qt5ct"
set fish_greeting ""

################## set colors ###################

set -g theme_color_scheme gruvbox
set -gx color0 "#282828"
set -gx color1 "#cc241d"
set -gx color2 "#98971a"
set -gx color3 "#d79921"
set -gx color4 "#458588"
set -gx color5 "#b16286"
set -gx color6 "#689d6a"
set -gx color7 "#a89984"
set -gx color8 "#928374"
set -gx color9 "#fb4934"
set -gx color10 "#b8bb26"
set -gx color11 "#fabd2f"
set -gx color12 "#83a598"
set -gx color13 "#d3869b"
set -gx color14 "#8ec07c"
set -gx color15 "#ebdbb2"

################## custom key bindings ###################

# start X at login
if status --is-login
    if lspci | grep NVIDIA
        if test -z "$DISPLAY" -a $XDG_VTNR -eq 1
            nvidia-xrun $HOME/.xinitrc
        end
    else
        if test -z "$DISPLAY" -a $XDG_VTNR -eq 1
            startx
        end
    end
end

