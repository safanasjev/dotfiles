return {
  'mfussenegger/nvim-dap',
  dependencies = {
    -- Debugger UI (replaces nvim-dap-ui, nvim-nio and nvim-dap-virtual-text)
    { 'igorlfs/nvim-dap-view', version = '1.*' },

    -- Installs the debug adapters
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add standalone debuggers here

    -- Go
    'https://github.com/leoluz/nvim-dap-go',
  },

  keys = {
    {
      '<F3>',
      function()
        require('dap').close()
        require('dap-view').close()
      end,
      desc = 'Debug: Stop',
    },
    { '<F4>', function() require('dap').restart() end, desc = 'Debug: Restart' },
    { '<F5>', function() require('dap').continue() end, desc = 'Debug: Start/Continue' },
    { '<F10>', function() require('dap').step_over() end, desc = 'Debug: Step Over' },
    { '<F11>', function() require('dap').step_into() end, desc = 'Debug: Step Into' },
    { '<F12>', function() require('dap').step_out() end, desc = 'Debug: Step Out' },
    { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Debug: Breakpoint' },
    { '<leader>dc', function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, desc = 'Debug: Conditional Breakpoint' },
    -- Add the variable under the cursor (or the visual selection) to Watches
    { '<leader>da', function() require('dap-view').add_expr() end, mode = { 'n', 'v' }, desc = 'Debug: Add Watch' },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    { '<F7>', function() require('dap-view').toggle() end, desc = 'Debug: See last session result.' },
  },
  config = function()
    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {
        -- Disable Delve options in Debugger UI
        delve = function() end,
      },

      ensure_installed = {
        'delve',
        'codelldb',
        'python',
        -- Add more debuggers here
      },
    }

    require('dap-view').setup {
      auto_toggle = true,

      -- Replaces nvim-dap-virtual-text (needs neovim 0.12+ and treesitter)
      virtual_text = { enabled = true },

      winbar = {
        controls = {
          enabled = true,
        },
      },
    }

    -- Change breakpoint icons
    vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#FF5F57' })
    vim.api.nvim_set_hl(0, 'DapStop', { fg = '#FEBC2D' })
    -- Plain unicode icons, so they render without a nerd font
    local breakpoint_icons = vim.g.have_nerd_font
        and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
      or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    for type, icon in pairs(breakpoint_icons) do
      local tp = 'Dap' .. type
      local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
      vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    end

    -- Configure standalone debuggers here
    require('dap-go').setup {
      delve = {},
    }
  end,
}
