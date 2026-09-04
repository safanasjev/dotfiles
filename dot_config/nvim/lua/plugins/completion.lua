return {

  -- Autocompletion
  {
    'saghen/blink.cmp',

    version = '1.*',

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        ['<C-f>'] = { 'select_and_accept', 'fallback' },
        ['<C-k>'] = { 'select_prev', 'fallback' },
        ['<C-j>'] = { 'select_next', 'fallback' },
        ['<C-e>'] = { 'show_signature', 'hide_signature', 'fallback' },
      },


      appearance = {
        nerd_font_variant = 'normal',
      },

      sources = {
        default = { 'lsp', 'path' },
      },

      completion = {
        documentation = { auto_show = false },

        menu = {
          auto_show = false,
          draw = { treesitter = { 'lsp' } },
        },

        ghost_text = { enabled = true },
      },

      signature = {
        enabled = true,
        trigger = {
          enabled = false,
        },
        window = {
          treesitter_highlighting = true,
          show_documentation = true
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
