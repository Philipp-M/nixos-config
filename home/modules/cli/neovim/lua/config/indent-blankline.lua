if vim.g.colors_name == 'base16' then
  vim.cmd("highlight IndentBlanklineIndentBg1 guibg=#" .. vim.g.base16_gui02 .. " gui=nocombine")
  vim.cmd("highlight IndentBlanklineIndentBg2 guibg=#" .. vim.g.base16_gui01 .. " gui=nocombine")
else
  vim.cmd("highlight IndentBlanklineIndentBg1 guibg=" .. vim.g.terminal_color_8 .. " gui=nocombine")
  vim.cmd("highlight IndentBlanklineIndentBg2 guibg=" .. vim.g.terminal_color_0 .. " gui=nocombine")
end

require('indent_blankline').setup {
  use_treesitter = true,
  char = " ",
  space_char_blankline = " ",
  char_highlight_list = {"IndentBlanklineIndentBg1", "IndentBlanklineIndentBg2"},
  space_char_highlight_list = {"IndentBlanklineIndentBg1", "IndentBlanklineIndentBg2"}
}
