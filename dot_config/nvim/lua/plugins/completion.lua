return {

  -- Autocompletion
  {
    'saghen/blink.cmp',

    -- use a release tag to download pre-built binaries
    version = '1.*',

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      -- C-f to accept
      -- 'super-tab' for mappings similar to vscode (tab to accept)
      -- 'enter' for enter to accept
      -- 'none' for no mappings
      --
      -- All presets have the following mappings:
      -- C-space: Open menu or open docs if already open
      -- C-n/C-p or Up/Down: Select next/previous item
      -- C-h: Hide menu
      -- C-k: Toggle signature help (if signature.enabled = true)
      --
      -- See :h blink-cmp-config-keymap for defining your own keymap
      keymap = {
        preset = 'default',
        ['<C-f>'] = { 'accept' },
        ['<C-h>'] = { 'hide' },
      },

      appearance = {
        nerd_font_variant = 'normal',
      },

      sources = {
        -- Don't use snippets and text as sources
        default = { 'lsp', 'path' },
      },

      completion = {

        -- (Default) Only show the documentation popup when manually triggered
        documentation = { auto_show = false },

        menu = {
          -- Don't automatically show the completion menu
          auto_show = false,
          draw = { treesitter = { 'lsp' } },
        },

        -- Display a preview of the selected item on the current line
        ghost_text = { enabled = true },
      },

      signature = {
        enabled = true,
        -- Don't show unless triggered with <C-k>
        trigger = {
          enabled = false,
        },
      },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
    },

    opts_extend = { 'sources.default' },
  },

  -- Autopairs
  {
    'nvim-mini/mini.pairs',
    event = 'InsertEnter',
    opts = {},
  },
}
