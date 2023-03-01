local execute = vim.api.nvim_command
local fn = vim.fn

local data_path = fn.stdpath("data")

local packer_install_path = data_path .. "/site/pack/packer/start/packer.nvim"

if fn.empty(fn.glob(packer_install_path)) > 0 then
  execute("!git clone https://github.com/wbthomason/packer.nvim " .. packer_install_path)
  execute("packadd packer.nvim")
end

vim.cmd "autocmd BufWritePost plugins.lua PackerCompile" -- Auto compile when there are changes in plugins.lua

return require("packer").startup(function(use)
  -- Packer can manage itself as an optional plugin
  use "wbthomason/packer.nvim"
  -- Async building & commands
  use {'tpope/vim-dispatch', cmd = {'Dispatch', 'Make', 'Focus', 'Start'}}

  use {"mbbill/undotree", cmd = {'UndotreeToggle'}, config = function() vim.g.undotree_SetFocusWhenToggle = true end}

  use {"rmagatti/auto-session", config = [[require('auto-session').setup()]]}

  -- Indentation tracking
  use {'lukas-reineke/indent-blankline.nvim', config = [[require('config.indent-blankline')]]}

  -- use 'joshdick/onedark.vim' -- Theme inspired by Atom

  -- Highlights
  use {
    -- 'nvim-treesitter/nvim-treesitter',
    '~/dev/personal/tree-sitter/nvim-treesitter',
    requires = {
      'nvim-treesitter/nvim-treesitter-refactor', 'nvim-treesitter/nvim-treesitter-textobjects', 'p00f/nvim-ts-rainbow'
    },
    config = [[require('config.treesitter')]]
  }

  -- use 'jordwalke/vim-reasonml'

  use {
    'nvim-treesitter/playground',
    cmd = {'TSPlaygroundToggle'},
    config = function() require"nvim-treesitter.configs".setup {playground = {enable = true}} end
  }

  use {"rafcamlet/nvim-luapad", opt = true, cmd = {"Lua", "LuaRun", "Luapad"}}

  use 'tomtom/tcomment_vim'
  use 'tpope/vim-surround'
  use 'tpope/vim-sleuth'
  use 'tpope/vim-repeat'

  use 'BenBergman/vsearch.vim'

  -- Git
  use {
    {'tpope/vim-fugitive', cmd = {'Git', 'Gstatus', 'Gblame', 'Gpush', 'Gpull', 'Gcommit', 'Gdiff'}},
    --  {
    --   'lewis6991/gitsigns.nvim',
    --   requires = {'nvim-lua/plenary.nvim'},
    --   config = function()
    --     require('gitsigns').setup({
    --       signs = {
    --         add = {hl = 'GitSignsAdd', text = '▊', numhl = 'GitSignsAddNr', linehl = 'GitSignsAddLn'},
    --         change = {hl = 'GitSignsChange', text = '▊', numhl = 'GitSignsChangeNr', linehl = 'GitSignsChangeLn'},
    --         delete = {hl = 'GitSignsDelete', text = '▊', numhl = 'GitSignsDeleteNr', linehl = 'GitSignsDeleteLn'},
    --         topdelete = {hl = 'GitSignsDelete', text = '▊', numhl = 'GitSignsDeleteNr', linehl = 'GitSignsDeleteLn'},
    --         changedelete = {
    --           hl = 'GitSignsChange',
    --           text = '▊',
    --           numhl = 'GitSignsChangeNr',
    --           linehl = 'GitSignsChangeLn'
    --         }
    --       },
    --       keymaps = {}
    --     })
    --   end
    -- },
     {'TimUntersberger/neogit', opt = true}
  }

  -- Keymappings
  use {"folke/which-key.nvim", config = [[require('config.keymappings')]]}

  -- LSP related

  -- TODO refactor this when https://github.com/wbthomason/packer.nvim/issues/256 is fixed
  use {
    'tami5/lspsaga.nvim',
    requires = {
      'onsails/lspkind-nvim', 'neovim/nvim-lspconfig', 'nvim-lua/lsp-status.nvim', 'ray-x/lsp_signature.nvim',
      'nvim-lua/lsp_extensions.nvim'
    },
    config = [[require('config.lsp')]]
  }

  use {'weilbith/nvim-code-action-menu', cmd = {'CodeActionMenu'}}

  use 'kosayoda/nvim-lightbulb'

  use "L3MON4D3/LuaSnip"

  use {
    "hrsh7th/nvim-cmp",
    requires = {
      "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer", "hrsh7th/cmp-path", "saadparwaiz1/cmp_luasnip", "hrsh7th/cmp-calc"
    },
    config = [[require('config.cmp-luasnip')]]
  }

  -- FZF and related
  use {
    'ojroques/nvim-lspfuzzy',
    requires = {{"junegunn/fzf.vim"}, {"junegunn/fzf"}},
    config = function()
      vim.cmd("let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow -g \"!.git/*\" -g \"!*.o\" --no-ignore-parent'")
      vim.cmd(
          "command! -bang -nargs=* Find call fzf#vim#grep('rg --column --line-number --no-heading --fixed-strings --ignore-case --hidden --follow -g \"!.git/*\" --color \"always\" '.shellescape(<q-args>), 1, <bang>0)")
      require('lspfuzzy').setup {}
    end
  }

  use "rafamadriz/friendly-snippets"

  use {"windwp/nvim-autopairs", event = 'InsertEnter *', config = [[require('config.autopairs')]]}

  use {'norcalli/nvim-colorizer.lua', config = function() require'colorizer'.setup() end}

  -- Status bars
  use {
    "nvim-lualine/lualine.nvim",
    requires = {"kyazdani42/nvim-web-devicons"},
    config = [[require('config.statusline')]]
  }
  use {"romgrk/barbar.nvim", requires = {"kyazdani42/nvim-web-devicons"}}

end)
