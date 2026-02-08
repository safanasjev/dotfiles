-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  -- ThePrimeagen VimBeGood games
  'ThePrimeagen/vim-be-good',

  -- Nvim-autopairs
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = true,
    -- use opts = {} for passing setup options
    -- this is equivalent to setup({}) function
  },

  -- Indent Blankline
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    ---@module "ibl"
    ---@type ibl.config
    opts = {},
  },

  -- Comment.nvim
  {
    'numToStr/Comment.nvim',
    opts = {
      -- add any options here
    },
  },
}
