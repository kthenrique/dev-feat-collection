-- For auto completion
vim.opt.shortmess:append({ c = true })
vim.opt.completeopt = "menuone,noinsert,noselect"

-- Don't put message to show the mode
vim.opt.showmode = false

-- Don't add EOF at the end of file when it is missing
vim.opt.fixendofline = false

-- Use always clipboard
vim.opt.clipboard = "unnamedplus"

-- Always show tab line
vim.opt.showtabline = 2

-- Show line numbers
vim.opt.number = true

-- ignore case in search and replace
vim.opt.ignorecase = true

-- don't ignore case if Upper Case letters appear in search
vim.opt.smartcase = true

-- set the highlight for line number
vim.opt.cul = true

-- always show the signcolumn
vim.opt.signcolumn = "yes"

-- Folding
vim.opt.foldmethod = "indent"
vim.opt.foldlevelstart = 0
vim.opt.foldenable = false

-- Indentation
vim.opt.cc = "+1"
vim.opt.textwidth = 100
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

-- File patterns to ignore while expanding
vim.opt.wildignore = "*.a,*.o,*.elf,*.out,*.bin,*.pdf,*.swp,*.tmp,*.directory"

-- Local scripts
vim.opt.exrc = true
vim.opt.secure = true

-- Sessions
vim.opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal"
