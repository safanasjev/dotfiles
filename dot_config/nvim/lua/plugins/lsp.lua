return {
  'neovim/nvim-lspconfig',
  dependencies = {
    { 'mason-org/mason.nvim', opts = {} },
    'mason-org/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',
  },
  config = function()
    local function augroup(name) return vim.api.nvim_create_augroup('mygroup_' .. name, { clear = true }) end

    -- Run when LSP is attached
    vim.api.nvim_create_autocmd('LspAttach', {
      group = augroup 'lsp_attach',
      callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        -- Toggle inlay hints
        if client then
          vim.keymap.set('n', '<leader>th',
            function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end,
            { buffer = event.buf, desc = 'Toggle Inlay Hints' })
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
      gopls = {
        settings = {
          gopls = {
            hints = {
              assignVariableTypes = true,
              compositeLiteralFields = true,
              compositeLiteralTypes = true,
              constantValues = true,
              functionTypeParameters = true,
              parameterNames = true,
              rangeVariableTypes = true,
            },
            completeUnimported = true,
            usePlaceholders = true,
            analyses = {
              unusedparams = true,
            },
          },
        },
      },
      golangci_lint_ls = {
        cmd = { 'golangci-lint-langserver' },
        root_markers = { '.git', 'go.mod' },
        init_options = {
          command = {
            'golangci-lint', 'run', '--output.json.path', 'stdout', '--show-stats=false', '--issues-exit-code=1'
          },
        },
      },
      -- Bash
      bashls = {},
      shellcheck = {},
      -- Markdown
      marksman = {},
      -- C/C++
      clangd = {},
      -- Java
      jdtls = {
        settings = {
          java = {
            inlayHints = { parameterNames = { enabled = "all" } },
          }
        }
      },
      -- Lua
      lua_ls = {
        -- Special Lua Config, as recommended by neovim help docs
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
              library = vim.tbl_filter(function(d) return not d:match(vim.fn.stdpath 'config' .. '/?a?f?t?e?r?') end,
                vim.api.nvim_get_runtime_file('', true)),
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

    local inlay_hints = { enabled = true }

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
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    for name, server in pairs(servers) do
      vim.lsp.config(name, server)
      vim.lsp.enable(name)
    end
  end,
}
