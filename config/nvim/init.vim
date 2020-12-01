"""" GENERAL """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set nocompatible              " be iMproved, required
filetype off                  " required
set shell=bash

set path+=**

let g:python_host_prog = 'python'

" Set tabs and shifts to 2 spaces
set tabstop=2
set smarttab
set shiftwidth=2
set softtabstop=2
set formatoptions-=t
set expandtab

" Enable mouse
set mouse=a
if !has('nvim')
    set encoding=utf-8
    set ttymouse=xterm2
endif

" Persistent Undo
if has('persistent_undo')
    let undodir = "$HOME/.local/share/nvim/undo"   " where to save undo histories
    call system('mkdir ' . undodir)    " create undodir if not existing
    set undofile                       " Save undo's after file closes
    set undodir=$HOME/.local/share/nvim/undo   " where to save undo histories
    set undolevels=100000              " How many undos
    set undoreload=1000000             " number of lines to save for undo
endif


let mapleader = "\<Space>"
let g:mapleader = "\<Space>"

set ttimeout ttimeoutlen=5

set hidden

" set the clipboard to the X clipboard for better interaction
if has('unnamedplus')
    set clipboard=unnamedplus
endif

"""" PLUGINS START """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Install Vim Plug if not installed
if empty(glob('~/.local/share/nvim/site/autoload/plug.vim'))
!curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall
endif

call plug#begin('$HOME/.local/share/nvim/plugged')

Plug 'drmikehenry/vim-fixkey'

Plug 'tpope/vim-dispatch'
if has('nvim')
  Plug 'radenling/vim-dispatch-neovim'
endif



"""" VISUALS """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""'''''''' INDENT_LINE
Plug 'Yggdroot/indentLine'
"{
    let g:indentLine_char = '▏'
"}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" AIRLINE
Plug 'bling/vim-airline'
"{
" settings are below because of undefined functions
"}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" RAINBOW_PARENTHESES
Plug 'luochen1990/rainbow'
"{
    let g:rainbow_active = 1
"}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""



"""" USEFUL EXTENSIONS """""""""""""""""""""""""""""""""""""""""""""""""""""""""

Plug 'scrooloose/nerdtree'
Plug 'tpope/vim-sleuth'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'tomtom/tcomment_vim'

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" FUGITIVE
Plug 'tpope/vim-fugitive'
"{
    nnoremap <leader>gdd :Gdiff<cr>
    nnoremap <leader>gs :Gstatus<cr>
    nnoremap <leader>gcc :Gcommit -v -q<CR>
    nnoremap <leader>gca :Gcommit --amend<CR>
"}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" FZF
Plug 'junegunn/fzf', { 'dir': '$HOME/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
"{
    nnoremap <leader><space> :FZF<CR>
    nnoremap <leader>h :History<CR>
    nnoremap <leader>gcl :Commits<CR>
    nnoremap <leader>n :Find 
    nnoremap <leader>s *:Find <C-r>/<BS><BS><C-Left><Del><Del><CR>
    " let $FZF_DEFAULT_COMMAND = 'ag -g "" --ignore=\*.o'
    let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow -g "!.git/*" -g "!*.o" --no-ignore-parent'
    command! -bang -nargs=* Find call fzf#vim#grep('rg --column --line-number --no-heading --fixed-strings --ignore-case --hidden --follow -g "!.git/*" --color "always" '.shellescape(<q-args>), 1, <bang>0)
"}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


"""" COMPLETION / LANGUAGE FEATURES """"""""""""""""""""""""""""""""""""""""""""

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" COC

Plug 'neoclide/coc.nvim',             {'do': 'yarn install --frozen-lockfile'}
"{
"
    let g:coc_global_extensions = [
        \'coc-omnisharp',
        \'coc-svelte',
        \'coc-markdownlint',
        \'coc-marketplace',
        \'coc-rust-analyzer',
        \'coc-vimlsp',
        \'coc-sh',
        \'coc-css',
        \'coc-emmet',
        \'coc-eslint',
        \'coc-git',
        \'coc-highlight',
        \'coc-html',
        \'coc-java',
        \'coc-json',
        \'coc-lists',
        \'coc-pairs',
        \'coc-python',
        \'coc-snippets',
        \'coc-tsserver',
        \'coc-vetur',
        \'coc-yaml',
        \'coc-calc',
    \]
    " Better display for messages
    set cmdheight=2

    " Smaller updatetime for CursorHold & CursorHoldI
    set updatetime=300

    " don't give |ins-completion-menu| messages.
    set shortmess+=c

    " always show signcolumns
    set signcolumn=yes

    " Use tab for trigger completion with characters ahead and navigate.
    " Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
    inoremap <silent><expr> <TAB>
        \ pumvisible() ? "\<C-n>" :
        \ <SID>check_back_space() ? "\<TAB>" :
        \ coc#refresh()
    inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

    function! s:check_back_space() abort
        let col = col('.') - 1
        return !col || getline('.')[col - 1]  =~# '\s'
    endfunction

    " Use <c-space> to trigger completion.
    inoremap <silent><expr> <C-space> coc#refresh()

    " Use <cr> for confirm completion, `<C-g>u` means break undo chain at current position.
    " Coc only does snippet and additional edit on confirm.
    inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"

    " Use `[c` and `]c` for navigate diagnostics
    nmap <silent> [c <Plug>(coc-diagnostic-prev)
    nmap <silent> ]c <Plug>(coc-diagnostic-next)

    " Remap keys for gotos
    nmap <silent> <leader>tt <Plug>(coc-definition)
    nmap <silent> <leader>td <Plug>(coc-type-definition)
    nmap <silent> <leader>ti <Plug>(coc-implementation)
    nmap <silent> <leader>tr <Plug>(coc-references)

    " Use K for show documentation in preview window
    nnoremap <silent> <leader>d :call <SID>show_documentation()<CR>

    function! s:show_documentation()
        if &filetype == 'vim'
            execute 'h '.expand('<cword>')
        else
            call CocAction('doHover')
        endif
    endfunction

    " Highlight symbol under cursor on CursorHold
    autocmd CursorHold * silent call CocActionAsync('highlight')

    " Remap for rename current word
    nmap <leader>rn <Plug>(coc-rename)
    " Fix autofix problem of current line
    nmap <leader>cf  <Plug>(coc-fix-current)

    nnoremap <silent> <leader>cd  :<C-u>CocList diagnostics<cr>
    nnoremap <silent> <leader>co  :<C-u>CocList outline<cr>
    nnoremap <silent> <leader>cs  :<C-u>CocList -I symbols<cr>
    nnoremap <silent> <leader>cn  :<C-u>CocNext<cr>
    nnoremap <silent> <leader>cp  :<C-u>CocPrev<cr>

    " Remap for format selected region
    " use vim-autoformat for this still (probably change in the future)
    " vmap <leader>f  <Plug>(coc-format-selected)
    " nmap <leader>f  <Plug>(coc-format-selected)

    " mappings for coc-snippets

    " Use <C-l> for trigger snippet expand.
    imap <C-l> <Plug>(coc-snippets-expand)

    " Use <C-j> for select text for visual placeholder of snippet.
    vmap <C-j> <Plug>(coc-snippets-select)

    " Use <C-j> for jump to next placeholder, it's default of coc.nvim
    let g:coc_snippet_next = '<c-j>'

    " Use <C-k> for jump to previous placeholder, it's default of coc.nvim
    let g:coc_snippet_prev = '<c-k>'

    " Use <C-j> for both expand and jump (make expand higher priority.)
    imap <C-j> <Plug>(coc-snippets-expand-jump)

    " mappings for coc-git

    nnoremap <leader>ghs :CocCommand git.chunkStage<CR>
    vnoremap <leader>ghs :CocCommand git.chunkStage<CR>
    nnoremap <leader>ghu :CocCommand git.chunkUndo<CR>
    vnoremap <leader>ghu :CocCommand git.chunkUndo<CR>
    nnoremap <leader>ghc :CocCommand git.showCommit<CR>
    vnoremap <leader>ghc :CocCommand git.showCommit<CR>
    vnoremap <leader>ghc :CocCommand git.showCommit<CR>
    vnoremap <leader>ghc :CocCommand git.showCommit<CR>
    nnoremap <leader>gds :CocCommand git.diffCached<CR>
    nmap [h <Plug>(coc-git-prevchunk)
    nmap ]h <Plug>(coc-git-nextchunk)
    nnoremap <leader>gf :CocCommand git.foldUnchanged<CR>

    " without this markdownlint isn't working
    let g:coc_filetype_map = { 'pandoc': 'markdown' }
"}
Plug 'antoinemadec/coc-fzf'

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" ALE
" Plug 'w0rp/ale'   TODO probably not needed anymore since coc.nvim
"{
"    " \   'javascript': ['standard'],
"    let g:ale_linters = {
"            \   'cpp': [],
"            \   'cs': ['OmniSharp'],
"            \}
"    " let g:ale_javascript_eslint_options = '-c /usr/lib/node_modules/eslint-config-standard/eslintrc.json'
"}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" AUTOFORMAT
Plug 'sbdchd/neoformat'
"{
    vmap <leader>f :Neoformat<CR>
    nmap <leader>f :Neoformat<CR>
"}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Plug 'honza/vim-snippets'

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" LATEX
Plug 'vim-latex/vim-latex'
"{
    let Tex_FoldedSections = ""
    let Tex_FoldedEnvironments = ""
    let Tex_FoldedMisc = ""
    let g:Tex_SmartKeyBS = 0
    let g:Tex_SmartKeyQuote = 0
    let g:Tex_SmartKeyDot = 0
    let g:tex_conceal = ""
"}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Plug 'mattn/emmet-vim', { 'for': ['html', 'vue.html.javascript.css', 'vue', 'css', 'scss', 'javascript'] }



"""" SYNTAX HIGHLIGHTING """""""""""""""""""""""""""""""""""""""""""""""""""""""

Plug 'nvim-treesitter/nvim-treesitter'
Plug 'JesseKPhillips/d.vim', { 'for': ['d'] }
Plug 'mesonbuild/meson', { 'rtp': 'data/syntax-highlighting/vim/'  }

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" PANDOC-MARKDOWN
Plug 'vim-pandoc/vim-pandoc'
"{
    let g:pandoc#syntax#conceal#use = 0
    let g:pandoc#keyboard#display_motions = 0
    let g:pandoc#modules#disabled = ["folding"]
"}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app & yarn install'  }
"{
    nmap <silent> <leader>mt <Plug>MarkdownPreviewToggle
    let g:mkdp_auto_close = 0
"}

Plug 'vim-pandoc/vim-pandoc-syntax'
Plug 'pboettch/vim-cmake-syntax', { 'for': 'cmake' }
Plug 'tikhomirov/vim-glsl'
Plug 'petRUShka/vim-opencl', { 'for': 'opencl' }
" Plug 'octol/vim-cpp-enhanced-highlight', { 'for': ['cpp', 'c'] }
Plug 'cespare/vim-toml', { 'for': 'toml'}
Plug 'dag/vim-fish', { 'for': 'fish'}
Plug 'JulesWang/css.vim', { 'for': ['vue.html.javascript.css', 'vue', 'css', 'scss'] }
Plug 'cakebaker/scss-syntax.vim', { 'for': ['vue.html.javascript.css', 'vue', 'css', 'scss'] }
Plug 'leafgarland/typescript-vim', { 'for': ['typescript', 'vue.html.javascript.css', 'vue'] }
Plug 'posva/vim-vue', { 'for': ['vue.html.javascript.css', 'vue'] }
Plug 'burner/vim-svelte', { 'for': ['svelte'] }
Plug 'pangloss/vim-javascript', { 'for': ['javascript', 'vue'] }
Plug 'othree/html5.vim', { 'for': ['htmldjango', 'html', 'vue.html.javascript.css', 'vue'] }
Plug 'tomlion/vim-solidity'
Plug 'peterhoeg/vim-qml'
Plug 'jparise/vim-graphql'
Plug 'vim-scripts/ShaderHighLight'
Plug 'ron-rs/ron.vim'
Plug 'elixir-editors/vim-elixir'
" Plug 'arzg/vim-rust-syntax-ext', { 'for': ['rust'] }
Plug 'udalov/kotlin-vim', { 'for': ['kotlin'] }
Plug 'dart-lang/dart-vim-plugin', { 'for': 'dart'}
Plug 'LnL7/vim-nix'

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" JSON
Plug 'elzr/vim-json', { 'for': 'json' }
"{
    set conceallevel=0
    let g:vim_json_syntax_conceal = 0
"}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Plug 'godlygeek/tabular', { 'for': 'markdown' }

Plug 'dhruvasagar/vim-table-mode'
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" TABLE MODE
"{
    map <leader>\ :TableModeToggle<CR>
    " let g:table_mode_header_fillchar = "="
    let g:table_mode_tableize_map = '<leader>tmt'
    let g:table_mode_corner_corner = "+"
"}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

call plug#end()
"""" PLUGINS END """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

filetype plugin indent on    " required



"""" KEYMAPPINGS """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
nmap <leader>w :w<cr>
nmap <leader>z :wq<cr>
nmap <leader>q :q<cr>
nmap <leader>x :bd<cr>

map Y y$

" polyfill for <A>
let c = 'a'
if !has('nvim')
    while c <= 'z'
        exec "set <A-".c.">=\e".c
        exec "imap \e".c." <A-".c.">"
        let c = nr2char(1+char2nr(c))
    endw
endif


nnoremap <A-l> :bn<CR>
nnoremap <A-h> :bp<CR>
inoremap <A-l> <Esc>:bn<CR>
inoremap <A-h> <Esc>:bp<CR>
" tnoremap <A-l> <Esc>:bn<CR>
" tnoremap <A-h> <Esc>:bp<CR>
" tnoremap <A-l> <C-\><C-n>:bn<CR>
" tnoremap <A-h> <C-\><C-n>:bp<CR>

vnoremap <silent> y y`]
vnoremap <silent> p p`]
nnoremap <silent> p p`]

" delete without yanking into the default register but instead into the register x
nnoremap x "xx
vnoremap x "xx
nnoremap X "xX
vnoremap X "xX
" nnoremap d "dd
" vnoremap d "dd
" replace currently selected text with default register
" without yanking it into the default register, but instead of the register p
vnoremap p "pdP
vnoremap P "pdP

" quick switch between last buffer and current buffer
nnoremap <BS> :b#<CR>

" Map Ctrl-Backspace to delete the previous word in insert mode.
imap <C-BS> <C-W>

noremap <F2> :call ToggleColemak()<CR>

" Search for selected text, forwards or backwards. (* and # work with selection as well)
vnoremap <silent> * :<C-U>
    \let old_reg = getreg('"')<Bar>let old_regtype = getregtype('"')<CR>
    \gvy/<C-R><C-R>=substitute(
    \escape(@", '/\.*$^~['), '\_s\+', '\\_s\\+', 'g')<CR><CR>
    \gV:call setreg('"', old_reg, old_regtype)<CR>
vnoremap <silent> # :<C-U>
    \let old_reg = getreg('"')<Bar>let old_regtype = getregtype('"')<CR>
    \gvy?<C-R><C-R>=substitute(
    \escape(@", '?\.*$^~['), '\_s\+', '\\_s\\+', 'g')<CR><CR>
    \gV:call setreg('"', old_reg, old_regtype)<CR>


" calculate expressions probably done by coc-calc
" vmap <leader>c :!xargs echo 'scale=5; ' \| BC_LINE_LENGTH=0 bc -l \| sed '/\./ s/\.\{0,1\}0\{1,\}$//'<cr><cr>

" color and optical enhancements
let $NVIM_TUI_ENABLE_TRUE_COLOR = 1
set termguicolors
set noshowmode
set background=dark
let g:base16_transparent_background = 1
colorscheme base16

syntax on
set fillchars+=vert:│

" airline settings need to be set here because of an undefined function
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1

" rounded separators (extra-powerline-symbols):
let g:airline_left_sep = "\uE0B4"
let g:airline_right_sep = "\uE0B6"

" set the CN (column number) symbol:
let g:airline_section_z = airline#section#create(["\uE0A1" . '%{line(".")}' . "\uE0A3" . '%{col(".")}'])

" trailing spaces are shown with a ·
set listchars=tab:▸\ ,trail:·
set list

" neovide
set guifont=Fira\ Code\ Regular\ Nerd\ Font\ Complete:h10

" some extensions which are not recognized by default
autocmd BufNewFile,BufRead *.html5   set syntax=php
autocmd BufNewFile,BufRead *.glsl   set syntax=glsl
autocmd BufNewFile,BufRead *.toml   set syntax=toml
autocmd BufNewFile,BufRead *.fish   set syntax=fish
autocmd BufNewFile,BufRead *.svelte   set syntax=svelte

set laststatus=2
set textwidth=120
set relativenumber
set number

" indentation
let g:indent_guides_enable_on_vim_startup = 1
set wildmenu
set showcmd
set hlsearch
set ruler

set autoread

set statusline+=%#warningmsg#
" set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let &t_ut = ''


" nvim-treesitter
"{
lua <<EOF
require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,                                     -- false will disable the whole extension
    custom_captures = {                                -- mapping of user defined captures to highlight groups
      -- ["foo.bar"] = "Identifier"                    -- highlight own capture @foo.bar with highlight group "Identifier", see :h nvim-treesitter-query-extensions
    },
  },
  incremental_selection = {
    enable = { "rust", "typescript" },
    keymaps = {                                        -- mappings for incremental selection (visual mappings)
      init_selection = "gnn",                          -- maps in normal mode to init the node/scope selection
      node_incremental = "grn",                        -- increment to the upper named parent
      scope_incremental = "grc",                       -- increment to the upper scope (as defined in locals.scm)
      node_decremental = "grm",                        -- decrement to the previous node
    }
  },
  refactor = {
    highlight_definitions = {
      enable = true
    },
    highlight_current_scope = {
      enable = true
    },
    smart_rename = {
      enable = true,
      keymaps = {
        smart_rename = "grr"                           -- mapping to rename reference under cursor
      }
    },
    navigation = {
      enable = true,
      keymaps = {
        goto_definition = "gnd",                       -- mapping to go to definition of symbol under cursor
        list_definitions = "gnD"                       -- mapping to list all definitions in current file
      }
    }
  },
  textobjects = { -- syntax-aware textobjects
    enable = true,
    disable = {},
    keymaps = {
        ["iL"] = { -- you can define your own textobjects directly here
          python = "(function_definition) @function",
          cpp = "(function_definition) @function",
          c = "(function_definition) @function",
          java = "(method_declaration) @function"
        },
        -- or you use the queries from supported languages with textobjects.scm
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["aC"] = "@class.outer",
        ["iC"] = "@class.inner",
        ["ac"] = "@conditional.outer",
        ["ic"] = "@conditional.inner",
        ["ae"] = "@block.outer",
        ["ie"] = "@block.inner",
        ["al"] = "@loop.outer",
        ["il"] = "@loop.inner",
        ["is"] = "@statement.inner",
        ["as"] = "@statement.outer",
        ["ad"] = "@comment.outer",
        ["am"] = "@call.outer",
        ["im"] = "@call.inner"
      }
  },
  -- ensure_installed = {"rust", "c", "typescript", "javascript", "vue", "c_sharp", "java", "css"} -- one of "all", "language", or a list of languages
  ensure_installed = "all" -- one of "all", "language", or a list of languages
}
EOF
"}


" Remapping for Colemak
" ----------------------

" This remaps the movemet keys j and k (In Colemak, J (= Qwerty Y) is placed
" above K (= Qwerty N), which I find confusing in Vim since j moves down and k
" up. I think the remappings below result in a more logical and easier to
" reach layout, keeping in mind that space and backspace (= Qwerty Caps-Lock)
" can be used instead of Colemak J (= Qwerty Y). I use the join-lines command
" much more than the help command, and have therefore swapped J and K since I
" find Colemak K (Qwerty N) much easier to reach than Colemak J (Qwerty Y).

" The first five mappings are basically all one needs to remember.

let s:colemakEnabled = 0

function! ToggleColemak()
    if s:colemakEnabled
        let s:colemakEnabled = 0
        unmap K
        unmap J

        unmap h
        unmap j
        unmap k

        unmap gh
        unmap gj
        unmap gk

        noremap zh
        "zK does not exist
        unmap zj
        unmap zJ
        unmap zk
        "zJ does not exist
        unmap z<Space>
        unmap z<S-Space>
        unmap z<BS>
        unmap z<S-BS>

        unmap <A-j>
        noremap <A-h> :bp<CR>
        inoremap <A-h> <Esc>:bp<CR>
        " tnoremap <A-h> <C-\><C-n>:bp<CR>

        unmap <C-w>h
        unmap <C-w>H
        unmap <C-w>j
        unmap <C-w>J
        unmap <C-w>k
        unmap <C-w>K
        unmap <C-w><Space>
        unmap <C-w><S-Space>
        unmap <C-w><S-BS>
        else
        let s:colemakEnabled = 1
        noremap K J
        noremap J K

        noremap h k
        noremap j h
        noremap k j

        noremap gh gk
        noremap gj gh
        noremap gk gj

        noremap zh zk
        "zK does not exist
        noremap zj zh
        noremap zJ zH
        noremap zk zj
        "zJ does not exist
        noremap z<Space> zl
        noremap z<S-Space> zL
        noremap z<BS> zh
        noremap z<S-BS> zH


        unmap <A-h>
        noremap <A-j> :bp<CR>
        inoremap <A-j> <Esc>:bp<CR>
        " tnoremap <A-j> <C-\><C-n>:bp<CR>

        noremap <C-w>h <C-w>k
        noremap <C-w>H <C-w>K
        noremap <C-w>j <C-w>h
        noremap <C-w>J <C-w>H
        noremap <C-w>k <C-w>j
        noremap <C-w>K <C-w>J
        noremap <C-w><Space> <C-w>l
        noremap <C-w><S-Space> <C-w>L
        noremap <C-w><S-BS> <C-w>H
    endif
endfunction

call ToggleColemak()
