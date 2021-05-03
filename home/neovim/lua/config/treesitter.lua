require'nvim-treesitter.configs'.setup {
  ensure_installed = 'all', -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  highlight = {enable = true, use_languagetree = true},
  -- TODO seems to be broken
  indent = {enable = false},
  autotag = {enable = true},
  autopairs = {enable = true}
}

