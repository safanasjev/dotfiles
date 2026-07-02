return {
  'neovim/nvim-lspconfig',
  dependencies = {
    { 'mason-org/mason.nvim', opts = {} },
    'mason-org/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',
  },
  config = function()
    -- Create augroup
    local function augroup(name) return vim.api.nvim_create_augroup('mygroup_' .. name, { clear = true }) end

    -- Run when LSP is attached
    vim.api.nvim_create_autocmd('LspAttach', {
      group = augroup 'lsp_attach',
      callback = function(event)
        local map = function(keys, func, desc, mode)
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end
        -- Rename variable under cursor
        map('grn', vim.lsp.buf.rename, 'Rename')

        -- Execute a code action
        map('gra', vim.lsp.buf.code_action, 'Goto Code Actions', { 'n', 'x' })

        -- Go to declaration
        map('grD', vim.lsp.buf.declaration, 'Goto Declaration')

        local client = vim.lsp.get_client_by_id(event.data.client_id)

        -- Toggle inlay hints
        if client and client:supports_method('textDocument/inlayHint', event.buf) then
          map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, 'Toggle Inlay Hints')
        end
      end,
    })

    local servers = {
      -- LSP servers --
      -- Rust
      rust_analyzer = {},
      -- Python
      ruff = {},
      ty = {},
      -- Go
      gopls = {},
      -- Bash
      bashls = {},
      -- Markdown
      marksman = {},
      -- C/C++
      clangd = {},
      -- Java
      jdtls = {},
      -- Lua
      stylua = {},
      lua_ls = {

        on_init = function(client)
          if client.workspace_folders then
            local path = client.workspace_folders[1].name
            if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
          end

          client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
            runtime = {
              version = 'LuaJIT',
              path = { 'lua/?.lua', 'lua/?/init.lua' },
            },
            workspace = {
              checkThirdParty = false,
              library = vim.tbl_filter(function(d) return not d:match(vim.fn.stdpath 'config' .. '/?a?f?t?e?r?') end, vim.api.nvim_get_runtime_file('', true)),
            },
          })
        end,
        settings = {
          Lua = {
            diagnostics = {
              globals = {
                'vim',
              },
            },
          },
        },
      },
    }

    -- Create a table { servers + ensure_installe  }
    local ensure_installed = vim.tbl_keys(servers)
    vim.list_extend(ensure_installed, {
      -- Formatters and linters --
      -- C/C++
      'clang-format',
      -- Bash
      'shfmt',
      -- Markdown
      'prettier',
      -- Java
      'google-java-format',
    })
    -- Install everything
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    -- Enable each LSP
    for name, server in pairs(servers) do
      vim.lsp.config(name, server)
      vim.lsp.enable(name)
    end
  end,
}
