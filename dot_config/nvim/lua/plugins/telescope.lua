return {
  {
    'nvim-telescope/telescope.nvim',
    version = '*',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-ui-select.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    config = function()
      require('telescope').setup {
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }

      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- Keympas
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Find Help' })
      vim.keymap.set('n', '<leader>fk', builtin.keymaps, { desc = 'Find Keymaps' })
      vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find Files' })
      vim.keymap.set('n', '<leader>ft', function() vim.cmd 'TodoTelescope' end, { desc = 'Find Todo Comments' })
      vim.keymap.set('n', '<leader>fp', builtin.builtin, { desc = 'Find Telescope Pickers' })
      vim.keymap.set({ 'n', 'v' }, '<leader>fw', builtin.grep_string, { desc = 'Find Current Word with Grep' })
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Find by Grep' })
      vim.keymap.set('n', '<leader>fz', builtin.grep_string, { desc = 'Fuzzy Find' })
      vim.keymap.set('n', '<leader>fd', builtin.diagnostics, { desc = 'Find Diagnostics' })
      vim.keymap.set('n', '<leader>fr', builtin.resume, { desc = 'Find Resume' })
      vim.keymap.set('n', '<leader>f.', builtin.oldfiles, { desc = 'Find Recent Files' })
      vim.keymap.set('n', '<leader>fc', builtin.commands, { desc = 'Find Commands' })
      vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find Buffers' })
      vim.keymap.set(
        'n',
        '<leader>f/',
        function()
          builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
            previewer = false,
          })
        end,
        { desc = 'Fuzzy Find in Current Buffer' }
      )
      vim.keymap.set('n', '<leader>fn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end,
        { desc = 'Find in Neovim Config' })

      -- LSP keymaps inside LspAttach so they only work when LSP is running
      local function augroup(name) return vim.api.nvim_create_augroup('telescope_' .. name, { clear = true }) end

      vim.api.nvim_create_autocmd('LspAttach', {
        group = augroup 'lsp_attach',
        callback = function(event)
          local buf = event.buf

          -- Find references
          vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = 'Goto References' })

          -- Goto implementation
          vim.keymap.set('n', 'gri', builtin.lsp_implementations,
            { buffer = buf, desc = 'Goto Implementation' })

          -- Goto definition
          vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = 'Goto Definition' })

          -- Fuzzy find all the symbols in current document
          vim.keymap.set('n', 'grO', builtin.lsp_document_symbols,
            { buffer = buf, desc = 'Open Document Symbols' })

          -- Fuzzy find all the symbols in current workspace
          vim.keymap.set('n', 'grW', builtin.lsp_dynamic_workspace_symbols,
            { buffer = buf, desc = 'Open Workspace Symbols' })

          -- Goto type definition
          vim.keymap.set('n', 'grt', builtin.lsp_type_definitions,
            { buffer = buf, desc = 'Goto Type Definition' })
        end,
      })
    end,
  },
}
