return {

  -- Conform
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    opts = {
      notify_on_error = false,
      format_on_save = {
        -- These options will be passed to conform.format()
        timeout_ms = 500,
        lsp_format = 'fallback',
      },
      formatters_by_ft = {
        rust = { 'rustfmt' },
        lua = { 'stylua' },
        python = { 'ruff_organize_imports', 'ruff_format' },
        c = { 'clang-format' },
        cpp = { 'clang-format' },
        sh = { 'shfmt' },
        bash = { 'shfmt' },
        markdown = { 'prettier' },
        go = { 'gofmt' },
        java = { 'google-java-format' },
        javascript = { 'prettier' },
      },
    },
  },

  -- Indentation style detection
  { 'NMAC427/guess-indent.nvim', opts = {} },
}
