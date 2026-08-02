-------------------------------------------------------------------------------

-- [[ Set the Leader First ]] --

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-------------------------------------------------------------------------------

-- [[ Native Plugins ]] --

-- Enalble undo tree with native plugin manager
vim.cmd 'packadd nvim.undotree'

-------------------------------------------------------------------------------

-- [[ Options ]] --

-- Nerd font must be installed
vim.g.have_nerd_font = true

-- 24-bit color support
vim.opt.termguicolors = true

-- No folding
vim.opt.foldenable = false
vim.opt.foldmethod = 'manual'
vim.opt.foldlevelstart = 99

-- Tab settings
vim.opt.tabstop = 4 -- Number of spaces tabs count for
vim.opt.shiftwidth = 4 -- Size of an indent
vim.opt.softtabstop = 4 -- Tab key inserts 4 spaces
vim.opt.expandtab = true -- Use spaces instead of tabs

-- Disable line wrapping
vim.opt.wrap = false

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Mouse support
vim.opt.mouse = 'a'

-- Use rg instead of grep
vim.opt.grepprg = 'rg --vimgrep'

-- Don't show mode since using statusline
vim.opt.showmode = false

-- Disable the default ruler
vim.opt.ruler = false

-- Enable autowrite
vim.opt.autowrite = true

-- Always show the signcolumn,
vim.opt.signcolumn = 'yes'

-- Only set clipboard if not in ssh, to make sure the OSC 52
-- integration works automatically.
vim.opt.clipboard = vim.env.SSH_CONNECTION and '' or 'unnamedplus' -- Sync with system clipboard

-- Enable breakindent
vim.opt.breakindent = true

-- Enable undo/redo changes even after closing and reopening a file
vim.opt.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Wrap lines at convenient points
vim.opt.linebreak = true

-- Show linebreak
vim.opt.showbreak = '↪ '

-- Global statusline
vim.opt.laststatus = 3

-- Insert indents automatically
vim.opt.smartindent = true

-- Decrease update time
vim.opt.updatetime = 200

-- Decrease mapped sequence wait time
vim.opt.timeoutlen = 300

-- Enable spell check for given languages
vim.opt.spelllang = { 'en' }
-- NOTE: available languages can be found here: https://ftp.nluug.nl/pub/vim/runtime/spell/

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Show some invisible characters
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions
vim.opt.inccommand = 'split'

-- Enable highlighting of the current line
vim.opt.cursorline = true

-- Number of lines to keep above and below the cursor
vim.opt.scrolloff = 4

-- Number of lines to keep above and below the cursor
vim.opt.sidescrolloff = 8

-- Undo history
vim.opt.undolevels = 10000

-- Confirm to save changes before exiting modified buffer
vim.opt.confirm = true

-- Allow cursor to move where there is no text in visual block mode
vim.opt.virtualedit = 'block'

-- Better jump history
vim.opt.jumpoptions = 'view'

-------------------------------------------------------------------------------

-- [[ Keymaps ]] --

-- Undotree
vim.keymap.set('n', '<leader>tu', require('undotree').open, { desc = 'Toggle Undotree' })

-- Fix : typo
vim.keymap.set('n', ';', ':')

-- Switch to last buffer with <Tab>
vim.keymap.set('n', '<Tab>', '<C-^>', { desc = 'Cycle Buffers' })

-- Repeat last command
vim.keymap.set('n', '<leader>;', '@:', { desc = 'Repeat Last Command' })

-- Center when jump to line number
vim.keymap.set('n', 'G', 'Gzz', { noremap = true })

-- Save file
vim.keymap.set('n', '<leader>w', '<CMD>w<CR>', { desc = 'Save File' })

-- Center cursor on scroll
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Center cursor on down scroll' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Center cursor on up scroll' })

-- Center search results
vim.keymap.set('n', 'n', 'nzz', { silent = true })
vim.keymap.set('n', 'N', 'Nzz', { silent = true })
vim.keymap.set('n', '*', '*zz', { silent = true })
vim.keymap.set('n', '#', '#zz', { silent = true })
vim.keymap.set('n', 'g*', 'g*zz', { silent = true })

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<CMD>nohlsearch<CR>')

-- Diagnostics keympas
local diagnostic_goto = function(next, severity)
  return function()
    vim.diagnostic.jump {
      count = (next and 1 or -1) * vim.v.count1,
      severity = severity and vim.diagnostic.severity[severity] or nil,
      float = true,
    }
  end
end
vim.keymap.set('n', '<leader>dq', vim.diagnostic.setloclist, { desc = 'Diagnostics Quickfix List' })
vim.keymap.set('n', '<leader>dl', vim.diagnostic.open_float, { desc = 'Line Diagnostics' })
vim.keymap.set('n', ']d', diagnostic_goto(true), { desc = 'Next Diagnostic' })
vim.keymap.set('n', '[d', diagnostic_goto(false), { desc = 'Prev Diagnostic' })

-- Switch buffers with <left> and <right> arrow keys
vim.keymap.set('n', '<left>', '<CMD>bp<CR>')
vim.keymap.set('n', '<right>', '<CMD>bn<CR>')

--  Switch between windows with CTRL+<hjkl>
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Resize window using <ctrl> + arrow keys
vim.keymap.set('n', '<C-Up>', '<CMD>resize +2<CR>', { desc = 'Increase Window Height' })
vim.keymap.set('n', '<C-Down>', '<CMD>resize -2<CR>', { desc = 'Decrease Window Height' })
vim.keymap.set('n', '<C-Left>', '<CMD>vertical resize -2<CR>', { desc = 'Decrease Window Width' })
vim.keymap.set('n', '<C-Right>', '<CMD>vertical resize +2<CR>', { desc = 'Increase Window Width' })

-- Better up/down
vim.keymap.set({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Down', expr = true, silent = true })
vim.keymap.set({ 'n', 'x' }, '<Down>', "v:count == 0 ? 'gj' : 'j'", { desc = 'Down', expr = true, silent = true })
vim.keymap.set({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Up', expr = true, silent = true })
vim.keymap.set({ 'n', 'x' }, '<Up>', "v:count == 0 ? 'gk' : 'k'", { desc = 'Up', expr = true, silent = true })

-- Better indenting
vim.keymap.set('x', '<', '<gv')
vim.keymap.set('x', '>', '>gv')

-------------------------------------------------------------------------------

-- [[ Diagnostics ]] --

vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },
  virtual_text = true,
  virtual_lines = false,
  jump = { on_jump = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.HINT] = '󰌶',
      [vim.diagnostic.severity.INFO] = '',
    },
  },
}

-------------------------------------------------------------------------------

-- [[ Autocommands ]] --

-- Create augroup
local function augroup(name) return vim.api.nvim_create_augroup('mygroup_' .. name, { clear = true }) end

-- Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ 'FocusGained', 'TermClose', 'TermLeave' }, {
  group = augroup 'checktime',
  callback = function()
    if vim.o.buftype ~= 'nofile' then vim.cmd 'checktime' end
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  group = augroup 'highlight_yank',
  callback = function() (vim.hl or vim.highlight).on_yank() end,
})

-- Wrap and check for spell in text filetypes
vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'wrap_spell',
  pattern = { 'text', 'plaintex', 'typst', 'gitcommit', 'markdown' },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Make it easier to close man-files when opened inline
vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'man_unlisted',
  pattern = { 'man' },
  callback = function(event) vim.bo[event.buf].buflisted = false end,
})

-- Resize splits if window got resized
vim.api.nvim_create_autocmd({ 'VimResized' }, {
  group = augroup 'resize_splits',
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
  end,
})

-- close some filetypes with <q>
vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'close_with_q',
  pattern = {
    'PlenaryTestPopup',
    'checkhealth',
    'dap-float',
    'dbout',
    'gitsigns-blame',
    'grug-far',
    'help',
    'lspinfo',
    'neotest-output',
    'neotest-output-panel',
    'neotest-summary',
    'notify',
    'qf',
    'spectre_panel',
    'startuptime',
    'tsplayground',
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.schedule(function()
      vim.keymap.set('n', 'q', function()
        vim.cmd 'close'
        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
      end, {
        buffer = event.buf,
        silent = true,
        desc = 'Quit buffer',
      })
    end)
  end,
})

-------------------------------------------------------------------------------

-- [[ Plugin Manager ]] --

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require('lazy').setup {
  spec = {
    { import = 'plugins' },
  },
  install = { colorscheme = { 'tokyonight' } },
  checker = { enabled = false },
}

-------------------------------------------------------------------------------

--[[

Acknowledgments

This config was inspired and uses code from:
    - [LazyVim](https://github.com/LazyVim/LazyVim)
    - [jonhoo/configs](https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.lua)
    - [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)

--]]

-------------------------------------------------------------------------------
