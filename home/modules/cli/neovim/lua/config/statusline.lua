-- local gl = require('galaxyline')
-- local lsp_status = require('lsp-status')
-- get my theme in galaxyline repo
-- local colors = require('galaxyline.theme').default
local colors = vim.g.colors_name == 'base16' and {
  -- bg = '#2E2E2E',
  bg = "#" .. vim.g.base16_gui01,
  yellow = "#" .. vim.g.base16_gui0A,
  -- dark_yellow = '#D7BA7D',
  cyan = "#" .. vim.g.base16_gui0C,
  green = "#" .. vim.g.base16_gui0B,
  -- light_green = '#B5CEA8',
  -- string_orange = '#CE9178',
  orange = "#" .. vim.g.base16_gui09,
  purple = "#" .. vim.g.base16_gui0E,
  grey = "#" .. vim.g.base16_gui04, -- '#858585',
  blue = "#" .. vim.g.base16_gui0D, -- '#569CD6',
  vivid_blue = "#" .. vim.g.base16_gui0D, -- '#4FC1FF',
  -- light_blue = '#9CDCFE',
  red = "#" .. vim.g.base16_gui08, -- '#D16969',
  error_red = "#" .. vim.g.base16_gui08, -- '#F44747',
  info_yellow = "#" .. vim.g.base16_gui0A -- '#FFCC66'
} or {
  -- bg = '#2E2E2E',
  bg = vim.g.terminal_color_0,
  yellow = vim.g.terminal_color_11,
  -- dark_yellow = '#D7BA7D',
  cyan = vim.g.terminal_color_14,
  green = vim.g.terminal_color_10,
  -- light_green = '#B5CEA8',
  -- string_orange = '#CE9178',
  orange = vim.g.terminal_color_1,
  violet = vim.g.terminal_color_13,
  magenta = vim.g.terminal_color_13,
  grey = vim.g.terminal_color_7, -- '#858585',
  blue = vim.g.terminal_color_12, -- '#569CD6',
  vivid_blue = vim.g.terminal_color_4, -- '#4FC1FF',
  -- light_blue = '#9CDCFE',
  red = vim.g.terminal_color_9, -- '#D16969',
  error_red = vim.g.terminal_color_1, -- '#F44747',
  info_yellow = vim.g.terminal_color_11 -- '#FFCC66'
}

-- Eviline config for lualine
-- Author: shadmansaleh
-- Credit: glepnir
local lualine = require 'lualine'

-- Color table for highlights
-- stylua: ignore
-- local colors = {
--   bg       = '#202328',
--   fg       = '#bbc2cf',
--   yellow   = '#ECBE7B',
--   cyan     = '#008080',
--   darkblue = '#081633',
--   green    = '#98be65',
--   orange   = '#FF8800',
--   violet   = '#a9a1e1',
--   magenta  = '#c678dd',
--   blue     = '#51afef',
--   red      = '#ec5f67',
-- }

local conditions = {
  buffer_not_empty = function() return vim.fn.empty(vim.fn.expand '%:t') ~= 1 end,
  hide_in_width = function() return vim.fn.winwidth(0) > 80 end,
  check_git_workspace = function()
    local filepath = vim.fn.expand '%:p:h'
    local gitdir = vim.fn.finddir('.git', filepath .. ';')
    return gitdir and #gitdir > 0 and #gitdir < #filepath
  end
}

-- Config
local config = {
  options = {
    -- Disable sections and component separators
    component_separators = '',
    section_separators = '',
    theme = {
      -- We are going to use lualine_c an lualine_x as left and
      -- right section. Both are highlighted by c theme .  So we
      -- are just setting default looks o statusline
      normal = {c = {fg = colors.fg, bg = colors.bg}},
      inactive = {c = {fg = colors.fg, bg = colors.bg}}
    }
  },
  sections = {
    -- these are to remove the defaults
    lualine_a = {},
    lualine_b = {},
    lualine_y = {},
    lualine_z = {},
    -- These will be filled later
    lualine_c = {},
    lualine_x = {}
  },
  inactive_sections = {
    -- these are to remove the defaults
    lualine_a = {},
    lualine_v = {},
    lualine_y = {},
    lualine_z = {},
    lualine_c = {},
    lualine_x = {}
  }
}

-- Inserts a component in lualine_c at left section
local function ins_left(component) table.insert(config.sections.lualine_c, component) end

-- Inserts a component in lualine_x ot right section
local function ins_right(component) table.insert(config.sections.lualine_x, component) end

ins_left {
  -- mode component
  function()
    -- auto change color according to neovims mode
    local mode_color = {
      n = colors.blue,
      i = colors.green,
      v = colors.magenta,
      [''] = colors.magenta,
      V = colors.magenta,
      c = colors.magenta,
      no = colors.red,
      s = colors.orange,
      S = colors.orange,
      [''] = colors.orange,
      ic = colors.yellow,
      R = colors.violet,
      Rv = colors.violet,
      cv = colors.red,
      ce = colors.red,
      r = colors.cyan,
      rm = colors.cyan,
      ['r?'] = colors.cyan,
      ['!'] = colors.red,
      t = colors.red
    }
    vim.api.nvim_command('hi! LualineMode guifg=' .. mode_color[vim.fn.mode()] .. ' guibg=' .. colors.bg)
    return '▊'
  end,
  color = 'LualineMode',
  padding = {right = 1}
}

ins_left {
  -- filesize component
  'filesize',
  cond = conditions.buffer_not_empty
}

ins_left {'filename', cond = conditions.buffer_not_empty, color = {fg = colors.magenta, gui = 'bold'}}

ins_left {'location'}

ins_left {'progress', color = {fg = colors.fg, gui = 'bold'}}

ins_left {
  'diagnostics',
  sources = {'nvim_diagnostic'},
  symbols = {error = ' ', warn = ' ', info = ' '},
  diagnostics_color = {
    color_error = {fg = colors.red},
    color_warn = {fg = colors.yellow},
    color_info = {fg = colors.cyan}
  }
}

-- Insert mid section. You can make any number of sections in neovim :)
-- for lualine it's any number greater then 2
ins_left {function() return '%=' end}

ins_left {
  -- Lsp server name .
  function()
    local msg = 'No Active Lsp'
    local buf_ft = vim.api.nvim_buf_get_option(0, 'filetype')
    local clients = vim.lsp.get_active_clients()
    if next(clients) == nil then return msg end
    for _, client in ipairs(clients) do
      local filetypes = client.config.filetypes
      if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then return client.name end
    end
    return msg
  end,
  icon = ' LSP:',
  color = {fg = '#ffffff', gui = 'bold'}
}

-- Add components to right sections
ins_right {
  'o:encoding', -- option component same as &encoding in viml
  fmt = string.upper, -- I'm not sure why it's upper case either ;)
  cond = conditions.hide_in_width,
  color = {fg = colors.green, gui = 'bold'}
}

ins_right {
  'fileformat',
  fmt = string.upper,
  icons_enabled = false, -- I think icons are cool but Eviline doesn't have them. sigh
  color = {fg = colors.green, gui = 'bold'}
}

ins_right {'branch', icon = '', color = {fg = colors.violet, gui = 'bold'}}

ins_right {
  'diff',
  -- Is it me or the symbol for modified us really weird
  symbols = {added = ' ', modified = '柳 ', removed = ' '},
  diff_color = {added = {fg = colors.green}, modified = {fg = colors.orange}, removed = {fg = colors.red}},
  cond = conditions.hide_in_width
}

ins_right {function() return '▊' end, color = {fg = colors.blue}, padding = {left = 1}}

-- Now don't forget to initialize lualine
lualine.setup(config)
