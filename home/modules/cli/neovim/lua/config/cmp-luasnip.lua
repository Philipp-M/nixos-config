-- compe
vim.o.completeopt = "menuone,noselect"

-- Setup nvim-cmp.
local cmp = require('cmp')
local luasnip = require('luasnip')

cmp.setup({
  snippet = {expand = function(args) luasnip.lsp_expand(args.body) end},
  mapping = {
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.close(),
    ['<CR>'] = cmp.mapping.confirm({select = true}),
    ['<Tab>'] = cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'}),
    ['<S-Tab>'] = cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})
    -- ['<Tab>'] = function(fallback)
    -- if true then
    --   vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('...', true, true, true), 'n', true)
    -- else
    --   fallback() -- The fallback function is treated as original mapped key. In this case, it might be `<Tab>`.
    -- end
  },
  sources = {{name = 'nvim_lsp'}, {name = 'luasnip'}, {name = 'buffer'}, {name = 'path'}, {name = 'calc'}}
})

local check_back_space = function()
  local col = vim.fn.col('.') - 1
  if col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') then
    return true
  else
    return false
  end
end

-- Use (s-)tab to:
--- move to prev/next item in completion menuone
--- jump to prev/next snippet's placeholder
_G.tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return "<C-n>"
  elseif luasnip and luasnip.expand_or_jumpable() then
    return "<Plug>luasnip-expand-or-jump"
  elseif check_back_space() then
    return "<Tab>"
  else
    return "<cmd>lua require('cmp').complete()<cr>"
  end
end
_G.s_tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return "<C-p>"
  elseif luasnip and luasnip.jumpable(-1) then
    return "<Plug>luasnip-jump-prev"
  else
    return "<S-Tab>"
  end
end

require("luasnip/loaders/from_vscode").lazy_load()

vim.api.nvim_set_keymap("i", "<Tab>", "v:lua.tab_complete()", {expr = true})
vim.api.nvim_set_keymap("s", "<Tab>", "v:lua.tab_complete()", {expr = true})
vim.api.nvim_set_keymap("i", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})
vim.api.nvim_set_keymap("s", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})
vim.api.nvim_set_keymap("i", "<C-E>", "<Plug>luasnip-next-choice", {})
vim.api.nvim_set_keymap("s", "<C-E>", "<Plug>luasnip-next-choice", {})
