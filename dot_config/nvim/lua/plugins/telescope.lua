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
      local actions = require('telescope.actions')

      require('telescope').setup {
        defaults = {
          sorting_strategy = 'ascending',
          layout_strategy = 'horizontal',
          layout_config = {
            prompt_position = 'top',
          },
          path_display = { 'smart' },
          mappings = {
            i = {
              ['<C-j>'] = actions.move_selection_next,
              ['<C-k>'] = actions.move_selection_previous,
              ['<C-c>'] = actions.close,
            },
          },
        },
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
      vim.keymap.set({ 'n', 'v' }, '<leader>fw', builtin.grep_string, { desc = 'Find Word Under Cursor' })
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Find with Grep' })
      vim.keymap.set('n', '<leader>fz', builtin.current_buffer_fuzzy_find, { desc = 'Fuzzy Find in Current Buffer' })
      vim.keymap.set('n', '<leader>fd', builtin.diagnostics, { desc = 'Find Diagnostics' })
      vim.keymap.set('n', '<leader>fr', builtin.resume, { desc = 'Resume Last Search' })
      vim.keymap.set('n', '<leader>f.', builtin.oldfiles, { desc = 'Find Recent Files' })
      vim.keymap.set('n', '<leader>fc', builtin.commands, { desc = 'Find Commands' })
      vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find Buffers' })
      vim.keymap.set('n', '<leader>fa', function()
        builtin.find_files({ hidden = true, no_ignore = true })
      end, { desc = 'Find All Files' })
      vim.keymap.set('n', '<leader>fn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end,
        { desc = 'Find in Neovim Config' })

      -- LSP keymaps inside LspAttach so they only work when LSP is running
      local function augroup(name) return vim.api.nvim_create_augroup('telescope_' .. name, { clear = true }) end

      vim.api.nvim_create_autocmd('LspAttach', {
        group = augroup 'lsp_attach',
        callback = function(event)
          local buf = event.buf

          vim.keymap.set('n', '<leader>lr', builtin.lsp_references, { buffer = buf, desc = 'Goto References' })

          vim.keymap.set('n', '<leader>li', builtin.lsp_implementations,
            { buffer = buf, desc = 'Goto Implementation' })

          vim.keymap.set('n', '<leader>ld', builtin.lsp_definitions, { buffer = buf, desc = 'Goto Definition' })

          vim.keymap.set('n', '<leader>lO', builtin.lsp_document_symbols,
            { buffer = buf, desc = 'Open Document Symbols' })

          vim.keymap.set('n', '<leader>lW', builtin.lsp_dynamic_workspace_symbols,
            { buffer = buf, desc = 'Open Workspace Symbols' })

          vim.keymap.set('n', '<leader>lt', builtin.lsp_type_definitions,
            { buffer = buf, desc = 'Goto Type Definition' })
        end,
      })

      -- Git keymaps so they only work when git-managed file is open
      vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
        group = augroup 'git',
        callback = function(event)
          -- Check if buffer directory is in git repo
          local is_git = vim.fn.system('git -C ' ..
          vim.fn.expand('%:p:h') .. ' rev-parse --is-inside-work-tree 2>/dev/null')

          if vim.v.shell_error == 0 then
            local buf = event.buf
            vim.keymap.set('n', '<leader>gs', builtin.git_status, { buffer = buf, desc = 'Git Status' })
            vim.keymap.set('n', '<leader>gc', builtin.git_commits, { buffer = buf, desc = 'Git Commits' })
            vim.keymap.set('n', '<leader>gr', builtin.git_branches, { buffer = buf, desc = 'Git Branches' })
          end
        end,
      })
    end,
  },
}
