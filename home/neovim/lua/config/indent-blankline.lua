vim.cmd("highlight IndentBlanklineIndentBg1 guibg=#" .. vim.g.base16_gui00 .. " gui=nocombine")
vim.cmd("highlight IndentBlanklineIndentBg2 guibg=#" .. vim.g.base16_gui01 .. " gui=nocombine")
vim.cmd("highlight IndentBlanklineIndent1 guibg=#" .. vim.g.base16_gui08 .. " gui=nocombine")
vim.cmd("highlight IndentBlanklineIndent2 guibg=#" .. vim.g.base16_gui09 .. " gui=nocombine")
vim.cmd("highlight IndentBlanklineIndent3 guibg=#" .. vim.g.base16_gui0A .. " gui=nocombine")
vim.cmd("highlight IndentBlanklineIndent4 guibg=#" .. vim.g.base16_gui0B .. " gui=nocombine")
vim.cmd("highlight IndentBlanklineIndent5 guibg=#" .. vim.g.base16_gui0C .. " gui=nocombine")
vim.cmd("highlight IndentBlanklineIndent6 guibg=#" .. vim.g.base16_gui0D .. " gui=nocombine")
vim.cmd("highlight IndentBlanklineIndent7 guibg=#" .. vim.g.base16_gui0E .. " gui=nocombine")
vim.cmd("highlight IndentBlanklineIndent8 guibg=#" .. vim.g.base16_gui0F .. " gui=nocombine")

require('indent_blankline').setup {
  show_current_context = true,
  use_treesitter = true,
  char = " ",
  space_char_blankline = " ",
  char_highlight_list = {"IndentBlanklineIndentBg1", "IndentBlanklineIndentBg2"},
  space_char_highlight_list = {"IndentBlanklineIndentBg1", "IndentBlanklineIndentBg2"},
  context_highlight_list = {
    "IndentBlanklineIndent1", "IndentBlanklineIndent2", "IndentBlanklineIndent3", "IndentBlanklineIndent4",
    "IndentBlanklineIndent5", "IndentBlanklineIndent6", "IndentBlanklineIndent7", "IndentBlanklineIndent8"
  },
  -- mostly optimized for rust
  context_patterns = {
    "field_.*_list", "^table", "^block", "token_tree", "^trait", "parenthesized_expression", "^tuple",
    "^match", "^for", "^else", "^if", "^macro", "function", "return", "enum_item"
  }
}
