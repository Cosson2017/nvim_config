vim.o.hidden = true
vim.o.confirm = true
vim.o.termguicolors = true
vim.o.tabstop = 4
vim.o.diffopt = "internal,filler,closeoff,vertical,algorithm:patience"
vim.o.showcmd = true
vim.o.cmdheight = 2
vim.o.scrolloff = 0
vim.o.clipboard = 'unnamedplus'
vim.o.completeopt = 'menuone,noselect,noinsert'
vim.o.updatetime = 500
vim.o.selection = 'inclusive'
vim.o.hlsearch = false
vim.o.termguicolors = true
vim.o.smartcase = true
vim.o.formatoptions = ""
vim.o.maxmempattern = 10000
vim.o.wildmenu = true
vim.o.wildmode = 'longest,full'
vim.o.fileencodings = 'utf-8,ucs-bom,gb2312,gbk,gb18030,latin1'
vim.bo.shiftwidth = 4
vim.wo.cursorline = true
vim.wo.number = true
vim.wo.relativenumber = true
vim.wo.cursorcolumn = false

vim.api.nvim_set_keymap("t", "<esc>", "<c-\\><c-N>", {noremap = true})
vim.api.nvim_set_keymap("t", "<c-w><c-w>", "<c-\\><c-N><c-w><c-w>", {noremap = true})
vim.api.nvim_set_keymap("t", "<c-w>h", "<c-\\><c-N><c-w>h", {noremap = true})
vim.api.nvim_set_keymap("t", "<c-w>j", "<c-\\><c-N><c-w>j", {noremap = true})
vim.api.nvim_set_keymap("t", "<c-w>k", "<c-\\><c-N><c-w>k", {noremap = true})
vim.api.nvim_set_keymap("t", "<c-w>l", "<c-\\><c-N><c-w>l", {noremap = true})

local M = {}
function M.grep_dir()
	local default = vim.fn.expand('<cword>')
	vim.api.nvim_command("echohl PromHl")
	vim.fn.inputsave()
	local input = vim.fn.input({prompt = 'rg> ', default = default, highlight = 'GrepHl'})
	vim.fn.inputrestore()
	vim.api.nvim_command("echohl None")

	if #input == 0 then
	    return
	end
	vim.api.nvim_command('Leaderf rg ' .. input)
end

return M
