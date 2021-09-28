local utils = require('config-utils')
local map = utils.map
local unmap = vim.api.nvim_del_keymap
local opt = utils.opt
local cmd = vim.cmd
local g = vim.g
local o, wo, bo = vim.o, vim.wo, vim.bo

require('plugins')

g.base16_transparent_background = 1
g.neovide_transparency = 0.85
g.clipboard = {
  name = 'xsel (ssh X11 xclip STDOUT issue forwarding fixed)',
  copy = {['+'] = {'xsel', '--input', '--clipboard'}, ['*'] = {'xsel', '--input', '--primary'}},
  paste = {['+'] = {'xsel', '--output', '--clipboard'}, ['*'] = {'xsel', '--output', '--primary'}},
  cache_enabled = 1
}

local buffer = {o, bo}
local window = {o, wo}

opt('termguicolors', true)
opt('background', 'dark')
opt('showmode', false)
opt('laststatus', 2)
opt('textwidth', 120)
opt('scrolloff', 0)
opt('hidden', true)
opt('showmatch', true)
opt('ignorecase', false)
opt('tabstop', 2, buffer)
opt('softtabstop', 0, buffer)
opt('expandtab', true, buffer)
opt('shiftwidth', 2, buffer)
opt('number', true, window)
opt('relativenumber', true, window)
opt('undofile', true, buffer)
opt('undolevels', 100000)
opt('undoreload', 1000000)
opt('timeoutlen', 400) -- By default timeoutlen is 1000 ms
opt('updatetime', 1000) -- By default timeoutlen is 4000 ms
opt('lazyredraw', true)
opt('conceallevel', 0, window)
opt('mouse', 'a')
opt('signcolumn', 'yes:1', window)
opt('guicursor', [[n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50]])

opt('guifont', 'Iosevka:h30')

if vim.fn.has('unnamedplus') == 1 then opt('clipboard', 'unnamedplus') end

-- detect nix files
cmd('au BufRead,BufNewFile *.nix set filetype=nix')
cmd('colorscheme base16')
