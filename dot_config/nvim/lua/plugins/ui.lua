return {
  -- Icons
  { 'nvim-tree/nvim-web-devicons', lazy = true },

  -- Colorscheme
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000, -- load before everything else
    opts = {
      style = 'night',
      styles = {
        comments = { italic = false },
      },
    },
    config = function(_, opts)
      require('tokyonight').setup(opts)
      vim.cmd.colorscheme 'tokyonight'

      -- Transparent window
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = 'none' })
      vim.api.nvim_set_hl(0, "FloatBorder", { bg = 'none', fg = "#27A1B9" })

      -- blink.cmp
      vim.api.nvim_set_hl(0, "BlinkCmpMenu", { link = "NormalFloat" })
      vim.api.nvim_set_hl(0, "BlinkCmpMenuBorder", { link = "FloatBorder" })
      vim.api.nvim_set_hl(0, "BlinkCmpDoc", { link = "NormalFloat" })
      vim.api.nvim_set_hl(0, "BlinkCmpDocBorder", { link = "FloatBorder" })
      vim.api.nvim_set_hl(0, "BlinkCmpSignatureHelp", { link = "NormalFloat" })
      vim.api.nvim_set_hl(0, "BlinkCmpSignatureHelpBorder", { link = "FloatBorder" })

      -- fzf.lua
      vim.api.nvim_set_hl(0, "FzfLuaBorder", { link = "FloatBorder" })
      vim.api.nvim_set_hl(0, "FzfLuaNormal", { link = "NormalFloat" })
      vim.api.nvim_set_hl(0, "FzfLuaTitle", { bg = 'none', fg = '#FF9E64' })
      vim.api.nvim_set_hl(0, "FzfLuaPreviewTitle", { bg = 'none', fg = '#FF9E64' })
      vim.api.nvim_set_hl(0, "FzfLuaTitleFlags", { bg = 'none' })
    end,
  },

  -- Statusline
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    opts = {
      options = {
        theme = 'tokyonight',
        icons_enabled = true,
        component_separators = '',
        section_separators = '',
      },
    },
  },

  -- LSP status updates
  {
    'j-hui/fidget.nvim',
    event = 'VeryLazy',
    opts = {},
  },

  -- Indentation guides
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = { 'BufReadPre', 'BufNewFile' },
    ---@module "ibl"
    ---@type ibl.config
    opts = {},
  },
}
