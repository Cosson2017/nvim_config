-- 所有的api都是 0-based

local M = {}

local vapi = vim.api
local log = require'completor.log'

M.cur_mode = function()
	return vapi.nvim_get_mode().mode
end

M.cur_buf = function()
	return vapi.nvim_get_current_buf()
end

M.cur_win = function()
	return vapi.nvim_get_current_win()
end

M.cur_line = function()
	return vapi.nvim_get_current_line()
end

M.get_line = function(line)
	local lines = vapi.nvim_buf_get_lines(0, line, line + 1, false)
	if #lines == 0 then
		log.error("get buf line err line:", line)
		return ""
	end
	return lines[1]
end

-- 你啊
M.cur_pos = function()
	local row, col = unpack(vapi.nvim_win_get_cursor(0))
	row = row - 1
--	local line = vapi.nvim_buf_get_lines(0, row, row+1, true)[1]
--	col = vim.str_utfindex(line, col)
	return {row, col}
end

M.set_cursor = function(pos)
	vapi.nvim_win_set_cursor(0, {pos[1] + 1, pos[2]})
end

-- -1 前面
-- 0 相等
-- 1 后面
M.pos_relation = function(A, B)
	if A[1] < B[1] then return -1 end
	if A[1] > B[1] then return 1 end
	if A[2] < B[2] then return -1 end
	if A[2] > B[2] then return 1 end
	return 0
end

M.complete = function(pos, items)
	vim.fn.complete(pos[2] + 1, items)
end

M.set_lines = function(head, tail, lines)
	vim.api.nvim_buf_set_lines(0, head, tail, false, lines)
end

return M
