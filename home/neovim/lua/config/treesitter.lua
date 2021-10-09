require'nvim-treesitter.configs'.setup {
  ensure_installed = 'all', -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  highlight = {enable = true, use_languagetree = true, additional_vim_regex_highlighting = true},
  -- TODO seems to be broken
  indent = {enable = false},
  autotag = {enable = true},
  autopairs = {enable = true},
  rainbow = {
    enable = true,
    extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
    max_file_lines = nil -- Do not enable for files with more than n lines, int
    -- colors = {}, -- table of hex strings
    -- termcolors = {} -- table of colour name strings
  }
}
