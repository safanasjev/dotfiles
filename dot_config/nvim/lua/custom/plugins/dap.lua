return {
  -- Core DAP plugin
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      -- UI plugins for better debugging experience
      'rcarriga/nvim-dap-ui',
      'nvim-neotest/nvim-nio',

      -- Virtual text showing variable values
      'theHamsta/nvim-dap-virtual-text',

      -- Mason integration for installing debuggers
      'jay-babu/mason-nvim-dap.nvim',
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      -- Setup dapui
      dapui.setup()

      -- Setup virtual text
      require('nvim-dap-virtual-text').setup()

      -- Auto-open/close UI
      dap.listeners.after.event_initialized['dapui_config'] = function()
        dapui.open()
      end

      -- dap.listeners.before.event_terminated['dapui_config'] = function()
      -- dapui.close()
      -- end
      -- dap.listeners.before.event_exited['dapui_config'] = function()
      -- dapui.close()
      -- end

      -- Language-specific configuration

      -- Keybindings
      vim.keymap.set('n', '<F5>', dap.continue, { desc = 'Debug: Start/Continue' })
      vim.keymap.set('n', '<F10>', dap.step_over, { desc = 'Debug: Step Over' })
      vim.keymap.set('n', '<F11>', dap.step_into, { desc = 'Debug: Step Into' })
      vim.keymap.set('n', '<F12>', dap.step_out, { desc = 'Debug: Step Out' })
      vim.keymap.set('n', '<leader>b', dap.toggle_breakpoint, { desc = 'Debug: Toggle Breakpoint' })
      vim.keymap.set('n', '<leader>B', function()
        dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end, { desc = 'Debug: Set Conditional Breakpoint' })

      -- Toggle UI
      vim.keymap.set('n', '<leader>du', dapui.toggle, { desc = 'Debug: Toggle UI' })

      -- Terminate debugging
      vim.keymap.set('n', '<leader>dt', dap.terminate, { desc = 'Debug: Terminate' })
    end,
  },

  -- Mason configuration
  {
    'jay-babu/mason-nvim-dap.nvim',
    dependencies = { 'mason.nvim', 'mfussenegger/nvim-dap' },
    opts = {
      ensure_installed = {
        'python', -- debugpy for Python
        'codelldb', -- for C/C++/Rust
        -- Add more debuggers as needed
      },
      handlers = {},
    },
  },
}
