
local function diagnostic_info()
	local info = ""
	if not vim.tbl_isempty(vim.lsp.buf_get_clients(0)) then
		local diag = vim.lsp.diagnostic.get_count(vim.fn.bufnr('%'), 'Error')
		if diag > 0 then
			info = info .. 'E:' .. diag .. " "
		end
		diag = vim.lsp.diagnostic.get_count(vim.fn.bufnr('%'), 'Warning')
		if diag > 0 then
			info = info .. 'W:' .. diag
		end
	end
	return vim.trim(info)
end

local function parse_progress_info()
	if vim.tbl_isempty(vim.lsp.buf_get_clients(0)) then
		return ""
	end

	local buf_messages = require'vim.lsp.util'.get_progress_messages()
	local msgs = {}
	for _, msg in ipairs(buf_messages) do
		local name = msg.name
		local client_name = '[' .. name .. ']'
		local contents = ''
		if msg.progress then
			contents = msg.title
			if msg.message then
				contents = contents .. ' ' .. msg.message
			end

			if msg.percentage then
				contents = contents .. ' (' .. msg.percentage .. ')'
			end

			if msg.spinner then
				contents = spinner_frames[(msg.spinner % #spinner_frames) + 1] .. ' ' .. contents
			end
		elseif msg.status then
			contents = msg.content
			if msg.uri then
				local filename = vim.uri_to_fname(msg.uri)
				filename = vim.fn.fnamemodify(filename, ':~:.')
				local space = math.min(60, math.floor(0.6 * vim.fn.winwidth(0)))
				if #filename > space then
					filename = vim.fn.pathshorten(filename)
				end

				contents = '(' .. filename .. ') ' .. contents
			end
		else
			contents = msg.content
		end

		table.insert(msgs, client_name .. ' ' .. contents)
	end
	return vim.trim(table.concat(msgs, ' '))
end


vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
	vim.lsp.diagnostic.on_publish_diagnostics, {
		update_in_insert = false,
	}
)

-- vim.cmd[[autocmd InsertLeave * lua vim.lsp.handlers['$/progress']()]]
--vim.cmd[[autocmd User LspProgressUpdate lua lsp_ext_progress_update = true]]
-- vim.api.nvim_command("doautocmd User LspProgressUpdate")

local M = {}

function M.lsp_info()
	return vim.trim(parse_progress_info() .. ' ' .. diagnostic_info())
end

return M
