local lspconfig = require('lspconfig')
local lsp_status = require('lsp-status')
local saga = require('lspsaga')
local lspkind = require('lspkind')
local lsp = vim.lsp

vim.fn.sign_define("LspDiagnosticsSignError",
                   {texthl = "LspDiagnosticsSignError", text = "", numhl = "LspDiagnosticsSignError"})
vim.fn.sign_define("LspDiagnosticsSignWarning",
                   {texthl = "LspDiagnosticsSignWarning", text = "", numhl = "LspDiagnosticsSignWarning"})
vim.fn.sign_define("LspDiagnosticsSignHint",
                   {texthl = "LspDiagnosticsSignHint", text = "", numhl = "LspDiagnosticsSignHint"})
vim.fn.sign_define("LspDiagnosticsSignInformation",
                   {texthl = "LspDiagnosticsSignInformation", text = "", numhl = "LspDiagnosticsSignInformation"})

local kind_symbols = {
  Text = '',
  Method = 'Ƒ',
  Function = 'ƒ',
  Constructor = '',
  Variable = '',
  Class = '',
  Interface = 'ﰮ',
  Module = '',
  Property = '',
  Unit = '',
  Value = '',
  Enum = '了',
  Keyword = '',
  Snippet = '﬌',
  Color = '',
  File = '',
  Folder = '',
  EnumMember = '',
  Constant = '',
  Struct = ''
}

lsp_status.config {
  kind_labels = kind_symbols,
  select_symbol = function(cursor_pos, symbol)
    if symbol.valueRange then
      local value_range = {
        ['start'] = {character = 0, line = vim.fn.byte2line(symbol.valueRange[1])},
        ['end'] = {character = 0, line = vim.fn.byte2line(symbol.valueRange[2])}
      }

      return require('lsp-status/util').in_range(cursor_pos, value_range)
    end
  end,
  current_function = true
}

lsp_status.register_progress()
lspkind.init {symbol_map = kind_symbols}
lsp.handlers['textDocument/publishDiagnostics'] = lsp.with(lsp.diagnostic.on_publish_diagnostics, {
  virtual_text = false,
  signs = true,
  update_in_insert = false,
  underline = true
})
saga.init_lsp_saga {
  use_saga_diagnostic_sign = true,
  code_action_prompt = {enable = false},
  code_action_keys = {quit = '<esc>', exec = '<cr>'},
  rename_action_keys = {quit = '<esc>', exec = '<cr>'}
}
local function on_attach(client, bufnr)
  local function buf_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = {noremap = true, silent = true}
  buf_keymap('n', '<leader>td', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
  buf_keymap('n', '<leader>tt', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
  buf_keymap('n', '<leader>ti', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
  buf_keymap('n', '<leader>tr', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
  buf_keymap('n', '<leader>dd', '<cmd>lua require("lspsaga.hover").render_hover_doc()<CR>', opts)
  buf_keymap('n', '<leader>dn', '<cmd>lua require("lspsaga.diagnostic").lsp_jump_diagnostic_next()<cr>', opts)
  buf_keymap('n', '<leader>dp', '<cmd>lua require("lspsaga.diagnostic").lsp_jump_diagnostic_prev()<cr>', opts)
  buf_keymap('n', '[d', '<cmd>lua require("lspsaga.diagnostic").lsp_jump_diagnostic_next()<cr>', opts)
  buf_keymap('n', ']d', '<cmd>lua require("lspsaga.diagnostic").lsp_jump_diagnostic_prev()<cr>', opts)
  buf_keymap('n', '<leader>ds', '<cmd>lua require("lspsaga.signaturehelp").signature_help()<cr>', opts)
  buf_keymap('n', '<leader>dl', '<cmd>lua require("lspsaga.diagnostic").show_line_diagnostics()<cr>', opts)
  -- buf_keymap('n', '<leader>a', '<cmd>lua require("lspsaga.codeaction").code_action()<CR>', opts)
  buf_keymap('v', '<leader>a', ':<C-U>lua require("lspsaga.codeaction").range_code_action()<CR>', opts)
  buf_keymap('n', '<leader>r', '<cmd>lua require("lspsaga.rename").rename()<CR>', opts)

  -- scroll down hover doc or scroll in definition preview
  buf_keymap('n', '<C-f>', '<cmd>lua require("lspsaga.action").smart_scroll_with_saga(1)<CR>', opts)
  -- scroll up hover doc
  buf_keymap('n', '<C-b>', '<cmd>lua require("lspsaga.action").smart_scroll_with_saga(-1)<CR>', opts)

  -- Set some keybinds conditional on server capabilities
  if client.resolved_capabilities.document_formatting then
    buf_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<cr>", opts)
  end
  if client.resolved_capabilities.document_range_formatting then
    buf_keymap("v", "<space>f", "<cmd>lua vim.lsp.buf.range_formatting()<cr>", opts)
  end

  -- Set autocommands conditional on server_capabilities
  if client.resolved_capabilities.document_highlight then
    vim.api.nvim_exec([[
      hi LspReferenceRead cterm=bold ctermbg=red guibg=gray20
      hi LspReferenceText cterm=bold ctermbg=red guibg=gray20
      hi LspReferenceWrite cterm=bold ctermbg=red guibg=gray20
      augroup lsp_document_highlight
        autocmd! * <buffer>
        autocmd CursorMoved <buffer> lua require'nvim-lightbulb'.update_lightbulb()
        autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
        autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
      augroup END
    ]], false)
  end

  lsp_status.on_attach(client, bufnr);
  require"lsp_signature".on_attach(client, bufnr)
  require'lsp_extensions'.inlay_hints {
    highlight = "Comment",
    prefix = " > ",
    aligned = false,
    only_current_line = false,
    enabled = {"ChainingHint"}
  }
end

local js_jsx_ts_tsx_vue_args = {
  {formatCommand = "prettier --stdin-filepath ${INPUT}", formatStdin = true}, {
    lintCommand = "eslint -f unix --stdin --stdin-filename ${INPUT}",
    lintIgnoreExitCode = true,
    lintStdin = true,
    lintFormats = {"%f:%l:%c: %m"},
    formatCommand = "eslint --fix-to-stdout --stdin --stdin-filename=${INPUT}",
    formatStdin = true
  }
}

local servers = {
  bashls = {},
  clangd = {
    cmd = {
      'clangd', -- '--background-index',
      '--clang-tidy', '--completion-style=bundled', '--header-insertion=iwyu', '--suggest-missing-includes',
      '--cross-file-rename'
    },
    handlers = lsp_status.extensions.clangd.setup(),
    init_options = {
      clangdFileStatus = true,
      usePlaceholders = true,
      completeUnimported = true,
      semanticHighlighting = true
    }
  },
  cmake = {},
  cssls = {filetypes = {"css", "scss", "less", "sass"}, root_dir = lspconfig.util.root_pattern("package.json", ".git")},
  dartls = {},
  dockerls = {},
  -- mostly for formatting
  efm = {
    cmd = {"efm-langserver"},
    init_options = {documentFormatting = true},
    filetypes = {
      "lua", "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx",
      "vue", "json"
    },
    settings = {
      rootMarkers = {".git/"},
      languages = {
        lua = {{formatCommand = "lua-format -i --indent-width=2 --tab-width=2 --column-limit=120", formatStdin = true}},
        nix = {{formatCommand = "nixfmt", formatStdin = true}},
        javascript = js_jsx_ts_tsx_vue_args,
        javascriptreact = js_jsx_ts_tsx_vue_args,
        json = js_jsx_ts_tsx_vue_args,
        typescript = js_jsx_ts_tsx_vue_args,
        typescriptreact = js_jsx_ts_tsx_vue_args,
        vue = js_jsx_ts_tsx_vue_args
      }
    }
  },
  ghcide = {},
  html = {cmd = {"html-languageserver"}},
  jdtls = {cmd = {"jdt-ls"}},
  jsonls = {cmd = {'vscode-json-languageserver', '--stdio'}},
  julials = {settings = {julia = {format = {indent = 2}}}},
  rnix = {},
  ocamllsp = {},
  omnisharp = {cmd = {'omnisharp', "--languageserver", "--hostPID", tostring(vim.fn.getpid())}},
  pyright = {settings = {python = {formatting = {provider = 'yapf'}}}},
  rust_analyzer = {
    settings = {
      ["rust-analyzer"] = {
        cargo = {loadOutDirsFromCheck = true},
        procMacro = {enable = true},
        lens = {references = true, methodReferences = true},
        experimental = {procAttrMacros = true}
      }
    }
  },
  stylelint_lsp = {cmd = {"stylelint"}}, -- not yet working, needs stylelint-lsp in nixpkgs upstream
  sumneko_lua = {
    cmd = {'lua-language-server'},
    settings = {
      Lua = {
        diagnostics = {globals = {'vim'}},
        runtime = {version = 'LuaJIT', path = vim.split(package.path, ';')},
        workspace = {
          library = {[vim.fn.expand("$VIMRUNTIME/lua")] = true, [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true}
        }
      }
    }
  },
  svelte = {},
  texlab = {
    settings = {latex = {forwardSearch = {executable = 'zathura', args = {'--synctex-forward', '%l:1:%f', '%p'}}}},
    commands = {
      TexlabForwardSearch = {
        function()
          local pos = vim.api.nvim_win_get_cursor(0)
          local params = {
            textDocument = {uri = vim.uri_from_bufnr(0)},
            position = {line = pos[1] - 1, character = pos[2]}
          }
          lsp.buf_request(0, 'textDocument/forwardSearch', params,
                          function(err, _, _, _) if err then error(tostring(err)) end end)
        end,
        description = 'Run synctex forward search'
      }
    }
  },
  tsserver = {
    filetypes = {"javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx"},
    root_dir = require('lspconfig/util').root_pattern("package.json", "tsconfig.json", "jsconfig.json", ".git"),
    settings = {documentFormatting = false}
  },
  vimls = {},
  vuels = {},
  yamlls = {},
  zls = {}
}

local snippet_capabilities = {textDocument = {completion = {completionItem = {snippetSupport = true}}}}

for server, config in pairs(servers) do
  config.on_attach = on_attach
  config.handlers = (config.handlers or {})
  config.handlers["textDocument/publishDiagnostics"] = lsp.with(lsp.diagnostic.on_publish_diagnostics, {
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = true
  })
  local cmp_capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
  config.capabilities = vim.tbl_deep_extend('keep', config.capabilities or {}, lsp_status.capabilities,
                                            cmp_capabilities, snippet_capabilities)
  lspconfig[server].setup(config)
end
