return {
  {
    'ibhagwan/fzf-lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local fzf = require('fzf-lua')

      fzf.setup {
        winopts = {
          preview = {
            layout = 'horizontal',
            scrollbar = false,
          },
        },
        fzf_opts = {
          ['--layout'] = 'reverse',
        },
      }

      vim.keymap.set('n', '<leader>fh', fzf.help_tags, { desc = 'Find Help' })
      vim.keymap.set('n', '<leader>fk', fzf.keymaps, { desc = 'Find Keymaps' })
      vim.keymap.set('n', '<leader>ff', fzf.files, { desc = 'Find Files' })
      vim.keymap.set('n', '<leader>ft',
        function() fzf.grep({ search = 'TODO|HACK|PERF|NOTE|FIX|XXX|OPTIM', no_esc = true }) end)
      vim.keymap.set('n', '<leader>fp', fzf.builtin, { desc = 'Find fzf-lua Pickers' })
      vim.keymap.set({ 'n', 'v' }, '<leader>fw', fzf.grep_cword, { desc = 'Find Word Under Cursor' })
      vim.keymap.set('n', '<leader>fg', fzf.live_grep, { desc = 'Find with Grep' })
      vim.keymap.set('n', '<leader>fz', fzf.blines, { desc = 'Fuzzy Find in Current Buffer' })
      vim.keymap.set('n', '<leader>dd', fzf.diagnostics_document, { desc = 'Doument Diagnostics' })
      vim.keymap.set('n', '<leader>dw', fzf.diagnostics_document, { desc = 'Workspace Diagnostics' })
      vim.keymap.set('n', '<leader>dq', fzf.quickfix, { desc = 'Diagnostics Quickfix List' })
      vim.keymap.set('n', '<leader>fr', fzf.resume, { desc = 'Resume Last Search' })
      vim.keymap.set('n', '<leader>f.', fzf.oldfiles, { desc = 'Find Recent Files' })
      vim.keymap.set('n', '<leader>fc', fzf.commands, { desc = 'Find Commands' })
      vim.keymap.set('n', '<leader>fb', fzf.buffers, { desc = 'Find Buffers' })
      vim.keymap.set('n', '<leader>fm', fzf.marks, { desc = 'Find Marks' })
      vim.keymap.set('n', '<leader>fa', function()
        fzf.files({ hidden = true, no_ignore = true })
      end, { desc = 'Find All Files' })
      vim.keymap.set('n', '<leader>fn', function()
        fzf.files({ cwd = vim.fn.stdpath 'config' })
      end, { desc = 'Find in Neovim Config' })

      -- LSP keymaps inside LspAttach so they only work when LSP is running
      local function augroup(name) return vim.api.nvim_create_augroup('fzflua_' .. name, { clear = true }) end

      vim.api.nvim_create_autocmd('LspAttach', {
        group = augroup 'lsp_attach',
        callback = function(event)
          local buf = event.buf

          vim.keymap.set('n', '<leader>lr', fzf.lsp_references, { buffer = buf, desc = 'Goto References' })

          vim.keymap.set('n', '<leader>li', fzf.lsp_implementations,
            { buffer = buf, desc = 'Goto Implementation' })

          vim.keymap.set('n', '<leader>ld', fzf.lsp_definitions, { buffer = buf, desc = 'Goto Definition' })

          vim.keymap.set('n', '<leader>lO', fzf.lsp_document_symbols,
            { buffer = buf, desc = 'Open Document Symbols' })

          vim.keymap.set('n', '<leader>lW', fzf.lsp_live_workspace_symbols,
            { buffer = buf, desc = 'Open Workspace Symbols' })

          vim.keymap.set('n', '<leader>lt', fzf.lsp_typedefs,
            { buffer = buf, desc = 'Goto Type Definition' })
        end,
      })

      -- Git keymaps so they only work when git-managed file is open
      vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
        group = augroup 'git',
        callback = function(event)
          local is_git = vim.fn.system('git -C ' ..
            vim.fn.expand('%:p:h') .. ' rev-parse --is-inside-work-tree 2>/dev/null')

          if vim.v.shell_error == 0 then
            local buf = event.buf
            vim.keymap.set('n', '<leader>gs', fzf.git_status, { buffer = buf, desc = 'Git Status' })
            vim.keymap.set('n', '<leader>gc', fzf.git_commits, { buffer = buf, desc = 'Git Commits' })
            vim.keymap.set('n', '<leader>gb', fzf.git_branches, { buffer = buf, desc = 'Git Branches' })
          end
        end,
      })
    end,
  },
}
