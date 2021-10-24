local map = require('config-utils').map
local unmap = vim.api.nvim_del_keymap

vim.g.mapleader = ' '

map('n', '<Space>', '<NOP>', {noremap = true})

-- delete without yanking into the default register but instead into the register x
map({'n', 'v'}, 'x', '"xx', {noremap = true})
map({'n', 'v'}, 'X', '"xX', {noremap = true})
-- replace currently selected text with default register
-- without yanking it into the default register, but instead of the register p
map('v', 'p', '"pdP', {noremap = true})
map('v', 'P', '"pdP', {noremap = true})

-- "fix" Y to act similar as C or D
map('n', 'Y', 'y$')

-- barbar mappings

-- map('n', '<TAB>', ':BufferNext<cr>', {noremap = true, silent = true})
-- map('n', '<S-TAB>', ':BufferPrevious<cr>', {noremap = true, silent = true})
map('n', '<S-x>', ':BufferClose<cr>', {noremap = true, silent = true})
map('', '<A-h>', ':BufferPrevious<cr>', {noremap = true})
map('i', '<A-h>', '<Esc>:BufferPrevious<cr>', {noremap = true})
map('', '<A-l>', ':BufferNext<cr>', {noremap = true})
map('i', '<A-l>', '<Esc>:BufferNext<cr>', {noremap = true})

-- toggles between colemak and qwerty layout,
--
-- recursively remaps k -> j, j -> h, h -> k, as this feels more natural with colemak
local colemak_enabled = false
local function toggle_colemak()
  if colemak_enabled then
    colemak_enabled = false
    unmap('', 'K')
    unmap('', 'J')

    unmap('', 'h')
    unmap('', 'j')
    unmap('', 'k')

    unmap('', 'gh')
    unmap('', 'gj')
    unmap('', 'gk')

    unmap('', 'zh')
    -- zK does not exist
    unmap('', 'zj')
    unmap('', 'zJ')
    unmap('', 'zk')
    -- zJ does not exist
    unmap('', 'z<Space>')
    unmap('', 'z<S-Space>')
    unmap('', 'z<BS>')
    unmap('', 'z<S-BS>')

    unmap('', '<A-j>')
    map('', '<A-h>', ':BufferPrevious<cr>', {noremap = true})
    map('i', '<A-h>', '<Esc>:BufferPrevious<cr>', {noremap = true})
    -- tnoremap <A-h> <C-\><C-n>:bp<cr>

    unmap('', '<C-w>h')
    unmap('', '<C-w>H')
    unmap('', '<C-w>j')
    unmap('', '<C-w>J')
    unmap('', '<C-w>k')
    unmap('', '<C-w>K')
    unmap('', '<C-w><Space>')
    unmap('', '<C-w><S-Space>')
    unmap('', '<C-w><S-BS>')
  else
    colemak_enabled = true
    map('', 'K', 'J', {noremap = true})
    map('', 'J', 'K', {noremap = true})

    map('', 'h', 'k', {noremap = true})
    map('', 'j', 'h', {noremap = true})
    map('', 'k', 'j', {noremap = true})

    map('', 'gh', 'gk', {noremap = true})
    map('', 'gj', 'gh', {noremap = true})
    map('', 'gk', 'gj', {noremap = true})

    map('', 'zh', 'zk', {noremap = true})
    -- zK does not exist
    map('', 'zj', 'zh', {noremap = true})
    map('', 'zJ', 'zH', {noremap = true})
    map('', 'zk', 'zj', {noremap = true})
    -- zJ does not exist
    map('', 'z<Space>', 'zl', {noremap = true})
    map('', 'z<S-Space>', 'zL', {noremap = true})
    map('', 'z<BS>', 'zh', {noremap = true})
    map('', 'z<S-BS>', 'zH', {noremap = true})

    -- unmap('', '<A-h>')
    map('', '<A-j>', ':BufferPrevious<cr>', {noremap = true})
    map('i', '<A-j>', '<Esc>:BufferPrevious<cr>', {noremap = true})
    -- tnoremap <A-j> <C-\><C-n>:bp<cr>

    map('', '<C-w>h', '<C-w>k', {noremap = true})
    map('', '<C-w>H', '<C-w>K', {noremap = true})
    map('', '<C-w>j', '<C-w>h', {noremap = true})
    map('', '<C-w>J', '<C-w>H', {noremap = true})
    map('', '<C-w>k', '<C-w>j', {noremap = true})
    map('', '<C-w>K', '<C-w>J', {noremap = true})
    map('', '<C-w><Space>', '<C-w>l', {noremap = true})
    map('', '<C-w><S-Space>', '<C-w>L', {noremap = true})
    map('', '<C-w><S-BS>', '<C-w>H', {noremap = true})
  end
end

-- colemak is my default layout, but can be toggled with <leader>k as defined below
toggle_colemak()

-- which key (mostly leader mappings)
local wk = require("which-key")
wk.setup({})
wk.register({
  g = {
    name = "Git", -- optional group name
    c = {
      name = "Git commit",
      l = {"<cmd>Commits<cr>", "Show all commits"},
      c = {"<cmd>Git commit -v -q<cr>", "git commit"},
      a = {"<cmd>Git commit --amend<cr>", "git commit --amend"}
    },
    d = {name = "Git diff", d = {"<cmd>Gdiff<cr>", "git diff"}, s = {"<cmd>Gdiff --staged<cr>", "git diff --staged"}},
    h = {
      name = "Git Hunk (gitsigns)",
      s = {"<cmd>lua require'gitsigns'.stage_hunk()<cr>", "Stage hunk"},
      u = {"<cmd>lua require'gitsigns'.undo_stage_hunk()<cr>", "Undo stage hunk"},
      r = {"<cmd>lua require'gitsigns'.reset_hunk()<cr>", "Reset hunk"},
      R = {"<cmd>lua require'gitsigns'.reset_buffer()<cr>", "Reset buffer"},
      p = {"<cmd>lua require'gitsigns'.preview_hunk()<cr>", "Preview hunk"},
      b = {"<cmd>lua require'gitsigns'.blame_line()<cr>", "Blame line"}
    },
    s = {"<cmd>Git<cr>", "Git fugitive (status)"}
  },
  -- LSP Keybindings are defined in lsp.lua
  t = {
    name = "LSP jumps",
    t = "Go to definition",
    d = "Go to declaration",
    i = "Go to implementation",
    r = "Show References"
  },
  d = {
    name = "LSP diagnostics",
    d = "Show documentation",
    n = "Jump to next diagnostic",
    p = "Jump to previous diagnostic",
    l = "Show line diagnostics",
    s = "Show Signature Help"
  },
  a = "Code action",
  r = "Rename",
  f = "Format",
  u = {"<cmd>UndotreeToggle<cr>", "Toggle Undotree"},
  w = {"<cmd>w<cr>", ":write"},
  q = {"<cmd>q<cr>", ":q"},
  x = {"<cmd>:bd<cr>", ":bd"},
  z = {"ZZ", "ZZ"},
  k = {toggle_colemak, "Toggle between colemak and qwerty"},
  ["<space>"] = {"<cmd>Files<cr>", "Show Files in Workdirectory"},
  s = {"*:Rg <c-r>/<bs><bs><c-left><del><del><cr>", "Find word under cursor in Workdirectory"},
  n = {":Rg ", "Rg in Workdirectory"}
}, {prefix = "<leader>"})
wk.register({
  d = "Jump to next diagnostic",
  h = {'<cmd>lua require\"gitsigns\".next_hunk()<CR>', "Jump to next git hunk"}
}, {prefix = "["})
wk.register({
  d = "Jump to previous diagnostic",
  h = {'<cmd>lua require\"gitsigns\".prev_hunk()<CR>', "Jump to previous git hunk"}
}, {prefix = "]"})
wk.register({a = "Range Code action", f = "Range format"}, {prefix = "<leader>", mode = "v"})
wk.register({s = {"*:Rg <c-r>/<bs><bs><c-left><del><del><cr>", "Find selection in Workdirectory"}},
            {prefix = "<leader>", mode = "v", noremap = false})
wk.register({i = {h = {':<C-U>lua require"gitsigns".select_hunk()<cr>', 'Git hunk'}}}, {mode = "o"})
wk.register({i = {h = {':<C-U>lua require"gitsigns".select_hunk()<cr>', 'Git hunk'}}}, {mode = "x"})
