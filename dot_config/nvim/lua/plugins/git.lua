return {
  -- Fugitive
  -- {
  --   'tpope/vim-fugitive',
  -- },

  -- Gitsigns
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_', show_count = true },
        topdelete = { text = '‾', show_count = true },
        changedelete = { text = '~' },
        untracked = { text = '┆' },
      },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to Next Git Change' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to Previous Git Change' })

        -- Actions
        -- visual mode
        map('v', '<leader>ghs', function() gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end,
          { desc = 'Git Stage Hunk' })
        map('v', '<leader>ghr', function() gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end,
          { desc = 'Git Reset Hunk' })
        -- normal mode
        map('n', '<leader>ghs', gitsigns.stage_hunk, { desc = 'Git Stage Hunk' })
        map('n', '<leader>ghr', gitsigns.reset_hunk, { desc = 'Git Reset Hunk' })
        map('n', '<leader>gS', gitsigns.stage_buffer, { desc = 'Git Stage Buffer' })
        map('n', '<leader>gR', gitsigns.reset_buffer, { desc = 'Git Reset Buffer' })
        map('n', '<leader>ghp', gitsigns.preview_hunk, { desc = 'Git Preview Hunk' })
        map('n', '<leader>ghi', gitsigns.preview_hunk_inline, { desc = 'Git Preview Hunk Inline' })
        map('n', '<leader>gl', function() gitsigns.blame_line { full = true } end, { desc = 'Git Blame Line' })
        map('n', '<leader>gd', gitsigns.diffthis, { desc = 'Git Diff Against Index' })
        map('n', '<leader>gD', function() gitsigns.diffthis '@' end, { desc = 'Git Diff Against Last Commit' })
        map('n', '<leader>ghQ', function() gitsigns.setqflist 'all' end,
          { desc = 'Git Hunk Quickfix List (all files in repo)' })
        map('n', '<leader>ghq', gitsigns.setqflist, { desc = 'Git Hunk Quickfix List (all changes in this file)' })
        -- Toggles
        map('n', '<leader>tw', gitsigns.toggle_word_diff, { desc = 'Git intra-line Word Diff' })

        -- Text object
        map({ 'o', 'x' }, 'ih', gitsigns.select_hunk)
      end,
    },
  },
}
