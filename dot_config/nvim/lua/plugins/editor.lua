return {
  -- Todo Comments
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      keywords = {
        NOTE = { icon = '󰍨', color = 'hint', alt = { 'INFO' } },
      },
    },
  },

  -- Markdown preview
  {
    "sammaji/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle" },
    ft = { "markdown" },
    opts = {
      auto_close = false,
    },
    keys = {
      { '<leader>tm', '<CMD>MarkdownPreviewToggle<CR>', ft = "markdown", desc = 'Toggle Markdown Preview' },
    }
  },

  -- Extend and create a/i textobjects
  { 'nvim-mini/mini.ai',        opts = {}, },

  -- Fast and feature-rich surround actions
  { 'nvim-mini/mini.surround',  opts = {}, },

  -- Move any selection in any direction
  { 'nvim-mini/mini.move',      opts = {}, },

  -- Comment lines
  { 'nvim-mini/mini.comment',   opts = {}, },

  -- Split and join arguments
  { 'nvim-mini/mini.splitjoin', opts = {}, },

  -- Autopairs
  { 'nvim-mini/mini.pairs',     event = 'InsertEnter', opts = {}, },

  -- Neo-tree
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'nvim-tree/nvim-web-devicons', -- optional, but recommended
    },
    keys = {
      { '<leader>tn', '<CMD>Neotree<CR>', desc = 'Toggle Neotree' },
    },
    lazy = false, -- neo-tree will lazily load itself
  },

  -- Oil file explorer
  {
    'stevearc/oil.nvim',
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {},
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '<leader>to', '<CMD>Oil<CR>', desc = 'Toggle Oil' },
    },
    lazy = false,
  },

  -- Show keymaps
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      delay = 0,
      icons = {
        rules = {
          { pattern = 'git', icon = '󰊢', color = 'red' },
        },
      },
      spec = {
        { '<leader>f', group = 'Find', mode = { 'n', 'v' } },
        { '<leader>g', group = 'Git', mode = { 'n', 'v' } },
        { '<leader>gh', group = 'Git Hunk', mode = { 'n', 'v' }, icon = { icon = '󰊢', color = 'orange' } },
        { '<leader>d', group = 'Debug and Diagnostics', mode = { 'n' }, icon = '󰒓' },
        {
          '<leader>l',
          group = 'LSP',
          mode = { 'n' },
          icon = function() return { cat = 'filetype', name = vim.bo.filetype } end,
        },
        { '<leader>;', group = 'Repeat Last Command', icon = '󰑓' },
        { '<leader>t', group = 'Toggle' },
        { '][', desc = 'Next Section Start' },
        { ']]', desc = 'Next Section End' },
        { '[[', desc = 'Previous Section Start' },
        { '[]', desc = 'Previous Section End' },
      },
    },
  },
}
