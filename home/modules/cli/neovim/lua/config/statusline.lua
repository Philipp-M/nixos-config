local gl = require('galaxyline')
local lsp_status = require('lsp-status')
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
  purple = vim.g.terminal_color_13,
  grey = vim.g.terminal_color_7, -- '#858585',
  blue = vim.g.terminal_color_12, -- '#569CD6',
  vivid_blue = vim.g.terminal_color_4, -- '#4FC1FF',
  -- light_blue = '#9CDCFE',
  red = vim.g.terminal_color_9, -- '#D16969',
  error_red = vim.g.terminal_color_1, -- '#F44747',
  info_yellow = vim.g.terminal_color_11 -- '#FFCC66'
}

local condition = require('galaxyline.condition')
local gls = gl.section
gl.short_line_list = {'NvimTree', 'vista', 'dbui', 'packer'}

-- local lspclient = require('galaxyline.provider_lsp')

gls.left = {
  {
    ViMode = {
      provider = function()
        -- auto change color according the vim mode
        local mode_color = {
          n = colors.blue,
          i = colors.green,
          v = colors.purple,
          [''] = colors.purple,
          V = colors.purple,
          c = colors.grey,
          no = colors.blue,
          s = colors.orange,
          S = colors.orange,
          [''] = colors.orange,
          ic = colors.yellow,
          R = colors.red,
          Rv = colors.red,
          cv = colors.blue,
          ce = colors.blue,
          r = colors.cyan,
          rm = colors.cyan,
          ['r?'] = colors.cyan,
          ['!'] = colors.blue,
          t = colors.blue
        }
        vim.api.nvim_command('hi GalaxyViMode guifg=' .. mode_color[vim.fn.mode()])
        return '▊ '
      end,
      highlight = {colors.red, colors.bg}
    }
  }, {
    GitIcon = {
      provider = function() return ' ' end,
      condition = condition.check_git_workspace,
      separator = ' ',
      separator_highlight = {'NONE', colors.bg},
      highlight = {colors.orange, colors.bg}
    }
  }, {
    GitBranch = {
      provider = 'GitBranch',
      condition = condition.check_git_workspace,
      separator = ' ',
      separator_highlight = {'NONE', colors.bg},
      highlight = {colors.grey, colors.bg}
    }
  }, {
    DiffAdd = {
      provider = 'DiffAdd',
      condition = condition.hide_in_width,
      icon = '  ',
      highlight = {colors.green, colors.bg}
    }
  }, {
    DiffModified = {
      provider = 'DiffModified',
      condition = condition.hide_in_width,
      icon = ' 柳',
      highlight = {colors.blue, colors.bg}
    }
  }, {
    DiffRemove = {
      provider = 'DiffRemove',
      condition = condition.hide_in_width,
      icon = '  ',
      highlight = {colors.red, colors.bg}
    }
  }, {
    LspStatus = {
      provider = function() return lsp_status.status() end,
      highlight = {colors.grey, colors.bg},
      event = 'LspDiagnosticsChanged'
    }
  }
}

-- FileEncode = {
--   provider = 'FileEncode',
--   condition = condition.hide_in_width,

gls.right = {
  {DiagnosticError = {provider = 'DiagnosticError', icon = '  ', highlight = {colors.error_red, colors.bg}}},
  {DiagnosticWarn = {provider = 'DiagnosticWarn', icon = '  ', highlight = {colors.orange, colors.bg}}},
  {DiagnosticHint = {provider = 'DiagnosticHint', icon = '  ', highlight = {colors.vivid_blue, colors.bg}}},
  {DiagnosticInfo = {provider = 'DiagnosticInfo', icon = '  ', highlight = {colors.info_yellow, colors.bg}}}, {
    ShowLspClient = {
      provider = 'GetLspClient',
      condition = function()
        local tbl = {['dashboard'] = true, [' '] = true}
        if tbl[vim.bo.filetype] then return false end
        return true
      end,
      icon = ' ',
      highlight = {colors.grey, colors.bg}
    }
  }, {
    BufferType = {
      provider = 'FileTypeName',
      condition = condition.hide_in_width,
      separator = ' ',
      separator_highlight = {'NONE', colors.bg},
      highlight = {colors.grey, colors.bg}
    }
  }, {
    FileEncode = {
      provider = 'FileEncode',
      condition = condition.hide_in_width,
      separator = ' ',
      separator_highlight = {'NONE', colors.bg},
      highlight = {colors.grey, colors.bg}
    }
  }, {
    PerCent = {
      provider = 'LinePercent',
      separator = ' ',
      separator_highlight = {'NONE', colors.bg},
      highlight = {colors.grey, colors.bg}
    }
  }, {
    -- show Line and column number in custom format:  <nr>  <nr>
    -- ro=, ws=☲, lnr=, mlnr=☰, colnr=, br=, nx=Ɇ, crypt=🔒, dirty=⚡
    LineInfo = {
      provider = function() return string.format("%d %d", vim.fn.line('.'), vim.fn.col('.')) end,
      separator = ' ',
      separator_highlight = {'NONE', colors.bg},
      highlight = {colors.grey, colors.bg}
    }
  }
}

gls.short_line_left = {
  {
    BufferType = {
      provider = 'FileTypeName',
      separator = ' ',
      separator_highlight = {'NONE', colors.bg},
      highlight = {colors.grey, colors.bg}
    }
  },
  {SFileName = {provider = 'SFileName', condition = condition.buffer_not_empty, highlight = {colors.grey, colors.bg}}},
  {BufferIcon = {provider = 'BufferIcon', highlight = {colors.grey, colors.bg}}}
}
