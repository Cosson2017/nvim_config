
local log = require("nvim-completor/log")
local api = require("nvim-completor/api")

-----
-- 使用vim.regex进行正则匹配
-----

local M = {}

-- [start_mark_id, end_mark_id)
-- { buf_id = {mark1, mark2, ...} } 
local mark_map = {}
local default_mark = 0

local convert_step = function(str)
	local s = str:find("%$")
	if not s or s == #str then return str end
	local next_char = str:sub(s+1, s+1)
	if next_char == "{" then
		local front_str = str:sub(1, s-1)
		local after_str = str:sub(s)

		local ms = after_str:match("^%$%b{}")
		if not ms or #ms == 0 then return front_str .. "${", after_str:sub(3) end

		local next_str = after_str:sub(#ms + 1)
		-- local ph = ms:sub(3, -2):match("^[0-9]+:(.+)")
		local ph = ms:sub(3, -2):match("^[0-9]+:(.*)")
		if not ph then return front_str .. ms, next_str end
		return front_str .. ph, next_str, {col = #front_str, len = #ph}
	end

	if '0' <= next_char and next_char <= '9' then
		local front_str = str:sub(1, s-1)
		local after_str = str:sub(s)

		local ms = after_str:match("^%$[0-9]+")
		return front_str .. ms, after_str:sub(#ms + 1), {col = #front_str, len = #ms}
	end

	return str:sub(1, s), str:sub(s + 1)
end

local convert_iter = function(str)
	local iter_str = str
	return function()
		if not iter_str or #iter_str == 0 then return end
		local ret_str, istr, ph = convert_step(iter_str)
		iter_str = istr
		return ret_str, ph
	end
end

local convert_to_str_item = function(str)
	local phs = {}
	local ret = ""

	for s, ph in convert_iter(str) do
		if ph then ph.col = ph.col + #ret end
		ret = ret .. s
		table.insert(phs, ph)
	end

	return {str = ret, phs = phs}
end

M.create_pos_extmarks = function(buf, phs)
	if #phs == 0 then return end
	local marks = mark_map[buf] or {}
	for _, ph in ipairs(phs) do
		local mark_id = api.set_extmark(0, ph, {ph[1], ph[2] + ph[3]})
		table.insert(marks, mark_id)
	end

	mark_map[buf] = marks
	log.debug("marks: ", vim.fn.string(marks))
end

M.jump_to_next_pos = function(pos)
	local buf_id = api.cur_buf()
	local win_id = api.cur_win()
	local cur_pos = pos or api.cur_pos()

	log.debug("marks:", mark_map)
	local marks = mark_map[buf_id] or {}
	local del_marks = {}

	if default_mark > 0 then
		local pos = api.get_extmark(default_mark)
		default_mark = 0
		if #pos > 0 then
			api.set_cursor(pos[1])
			api.del_extmark(default_mark)
			return
		end
	end
	default_mark = 0

	local next = 0
	local pos_buf = {}
	local check = function(i, mark)
		local pos_range = api.get_extmark(mark)
		table.insert(pos_buf, i, pos_range)

		log.debug(cur_pos, pos_range)
		if #pos_range < 2 then 
			table.insert(del_marks, i)
			api.del_extmark(mark)
			return
		end

		local pos2 = pos_range[2]
		if api.pos_relation(cur_pos, pos2) ~= -1 then
			table.insert(del_marks, i)
			api.del_extmark(mark)
			return
		end

		if next == 0 then next = i; return end
		local next_pos = pos_buf[next]

		-- TODO: 是否做更全面的位置关系判断， 包含， 交叉等关系
		if api.pos_relation(next_pos[2], pos2) == -1 then
			return
		end
		next = i

		-- next_pos = {i = i, pos1 = pos1, pos2 = pos2, m1 = mark[1], m2 = mark[2]}
	end

	for i, mark in ipairs(marks) do
		check(i, mark)
	end

	if next then table.insert(del_marks, next) end
	table.sort(del_marks, function(i1, i2) return i1 > i2 end)

	local remove_marks = function()
		for _, i in ipairs(del_marks) do
			table.remove(marks, i)
		end
		mark_map[buf_id] = marks
	end

	local contain_del = function(n)
		for _, d in ipairs(del_marks) do
			if d == n then return true end
		end
		return false
	end

	if next == 0 then remove_marks(); return end

	local pos1 ,pos2 = pos_buf[next][1], pos_buf[next][2]
	api.del_extmark(marks[next])

	local line = api.get_line(pos1[1])
	line = line:sub(1, pos1[2]) .. line:sub(pos2[2] + 1)
	api.set_lines(pos1[1], pos1[1] + 1, {line})
	api.set_cursor(pos1)

	for i, pb in ipairs(pos_buf) do
		local pb1, pb2 = pb[1], pb[2]
		local mark = marks[i]
		local reduce = pos2[2] - pos1[2]
		if i ~= next and 
			pb1[1] == pos1[1] and 
			not contain_del(i) then

			if pb1[2] >= pos2[2] then
				pb1[2] = pb1[2] - reduce
				pb2[2] = pb2[2] - reduce
			end
			api.set_extmark(mark, pb1, pb2)
		end
	end

	remove_marks()
end

-- edit: { new_text = {line1, line2}, head = { line, col } , tail = {line, col} }
M.apply_edit = function(ctx, edit, create_mark)
	local cur_buf = api.cur_buf()
	local marks = mark_map[cur_buf] or {}
	local old_marks = {}

	-- 起止行号
	local start = edit.head[1]
	local tail = edit.tail[1]
	-- 当前操作行
	-- 第二次进来的时候， 就不准确了， 除非更新ctx.typed
	--local temp = ctx.typed
	--if ctx.pos[1] ~= start then
	--	temp = api.get_line(start)
	--end
	temp = api.get_line(start)
	edit.new_text[1] = temp:sub(1, edit.head[2]) .. edit.new_text[1]

	local new_marks = {}
	for i, text in ipairs(edit.new_text) do
		local ret = convert_to_str_item(text)
		edit.new_text[i] = ret.str
		if create_mark then
			local line = start + i - 1
			for _, ph in ipairs(ret.phs) do
				table.insert(new_marks, {line, ph.col, ph.len})
			end
		end
	end

	local tlen = #edit.new_text
	local cursor_col = #edit.new_text[tlen]

	-- 第二次进来的时候， 就不准确了， 除非更新ctx.typed
	-- temp = ctx.typed
	-- if ctx.pos[1] ~= tail then
	-- 	temp = api.get_line(tail)
	-- end
	if cursor_col == 0 and edit.tail[2] == 0 then
		table.remove(edit.new_text, tlen)
		tlen = tlen - 1
		cursor_col = #edit.new_text[tlen]
	else
		temp = api.get_line(tail)
		edit.new_text[tlen] = edit.new_text[tlen] .. temp:sub(edit.tail[2] + 1)	
		tail = tail + 1
	end

	local tail_line = edit.head[1] + #edit.new_text - 1
	local check = function(mark)
		local mpos = api.get_extmark(mark)
		if #mpos == 0 then return end

		local mpos1, mpos2 = mpos[1], mpos[2]
		if mpos1[1] == edit.tail[1] and api.pos_relation(mpos1, edit.tail) ~= -1 then
			local offset = cursor_col - edit.tail[2]
			mpos1 = {tail_line, mpos1[2] + offset}
			mpos2 = mpos2 and {tail_line, mpos2[2] + offset}
			table.insert(old_marks, {mark, mpos1, mpos2})
			return
		end

		if mpos1[1] == edit.head[1] and api.pos_relation(mpos1, edit.head) == -1 then
			table.insert(old_marks, {mark, mpos1, mpos2})
			return
		end
	end

	if default_mark > 0 then check(default_mark) end
	for _, mark in ipairs(marks) do
		check(mark)
	end
	
	api.set_lines(start, tail, edit.new_text)

	-- 恢复marks
	for _, m in ipairs(old_marks) do
		api.set_extmark(m[1], m[2], m[3])
	end
	M.create_pos_extmarks(cur_buf, new_marks)

	if #new_marks == 0 then
		if default_mark == 0 then
			default_mark = api.set_extmark(0, {start + tlen - 1, cursor_col})
		end
	else
		if default_mark > 0 then
			api.del_extmark(default_mark)
		end
		default_mark = -1
	end
end

M.get_curline_marks = function(line)
	local buf = api.cur_buf()
	local marks = mark_map[buf]
	if marks == nil then return {} end

	-- {{ mark_id = xx, col = xx }}
	local cur_marks = {}
	for _, mark in ipairs(marks) do
		local pos = api.get_extmark(mark)
		if #pos > 0 and pos[1][1] == line then
			table.insert(cur_marks, {mark_id = mark, range = pos})
		end
	end

	return cur_marks
end

M.restore_ctx = function(ctx)
	local ctx_line = ctx.pos[1]
	api.set_lines(ctx_line, ctx_line + 1, {ctx.typed})
	for _, m in ipairs(ctx.marks) do
		api.set_extmark(m.mark_id, m.range[1], m.range[2])
	end
end

return M
