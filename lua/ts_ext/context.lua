local queries = require'vim.treesitter.query'
--local ts_locals = require'nvim-treesitter.locals'
--local parsers = require'nvim-treesitter.parsers'
local ts_utils = require'nvim-treesitter.ts_utils'
local a = vim.api

local QUERY_GROUP = "complete"
local SCOPE_KIND_ID = 0
local FUNC_KIND_ID = 0
local FUNC_NAME_ID = 0
local METHOD_KIND_ID = 0
local METHOD_NAME_ID = 0
local TYPE_KIND_ID = 0
local TYPE_NAME_ID = 0
local init_kind_id = {
	["scope"] = function(id) SCOPE_KIND_ID = id end,
	["func"] = function(id) FUNC_KIND_ID = id end,
	["method"] = function(id) METHOD_KIND_ID = id end,
	["type"] = function(id) TYPE_KIND_ID = id end,
	["name.func"] = function(id) FUNC_NAME_ID = id end,
	["name.method"] = function(id) METHOD_NAME_ID = id end,
	["name.type"] = function(id) TYPE_NAME_ID = id end,
}

local _query = nil
local _filetype = ""
local _capture_cache = {}

local function set_query_var()
	local cur_ft = vim.bo.filetype
	if _filetype ~=	cur_ft then
		_filetype = cur_ft
		_query = queries.get_query(_filetype, QUERY_GROUP)
		if _query == nil then return end
		for id, kind in ipairs(_query.captures) do
			local init = init_kind_id[kind]
			if init then init(id) end
		end
	end
end

local function check_and_reset_env()
	set_query_var()
	_capture_cache = {}
	return _query ~= nil
end

local function node_id(node)
	return string.format("%s_%d_%d_%d_%d", node:symbol(), node:range())
end

local function get_node_capture_kind(cur_node, parent)
	local cur_id = node_id(cur_node)
	local cache = _capture_cache[cur_id] or nil
	if cache then return cache end

	local node = parent or cur_node
	local start = cur_node:start()


	for id, inode in _query:iter_captures(node, 0, start, start + 1) do
		local inode_id = node_id(inode)
		_capture_cache[inode_id] = _capture_cache[inode_id] or {}
		table.insert(_capture_cache[inode_id], id)
	end

	return _capture_cache[cur_id] or nil
end

local function is_node_kind(node, kind, parent)
	local kinds = get_node_capture_kind(node, parent)
	if not kinds then return false end
	for _, k in ipairs(kinds) do
		if k == kind then 
			return true 
		end
	end
	return false
end

local function get_decl_name_node(node, kind, parent)
	if not node or node:child_count() == 0 then return nil end
	local parent = parent or node
	local not_leafs = {}
	for child in node:iter_children() do
		if child:child_count() == 0 then
			if is_node_kind(child, kind, parent) then
				return child
			end
		elseif not is_node_kind(child, SCOPE_KIND_ID, parent) then
			table.insert(not_leafs, child)
		end
	end

	for _, lnode in ipairs(not_leafs) do
		local ln = get_decl_name_node(lnode, kind, parent)
		if ln then return ln end
	end

	return nil
end

local _context_cache = {
	buf = 0,
	changedtick = 0,
	text = "",
	start = nil,
	end_ = nil,
}

function _context_cache:check_hit()
	if not start or not end_ then return false end
	if self.changedtick ~= vim.b.changedtick then return false end

	local pos = vim.fn.getpos('.')
	if pos[1] ~= buf then return false end
	if pos[2] < self.start[1] then return false end
	if self.start[1] == pos[2] and pos[3] < self.start[2] then return false end
	if self.end_[1] < pos[2] then return false end
	if self.end_[1] == pos[2] and self.end_[2] < pos[3] then return false end
	return true
end

function _context_cache:reset()
	self.start = nil
	self.end_ = nil
	self.changedtick = 0
	self.buf = 0
	self.text = ""
end

function _context_cache:update_smallest_decl_context()
	local current_node = ts_utils.get_node_at_cursor()
	local init_cache = function(kind)
		local start_row, start_col, end_row, end_col = current_node:range()
		self.start = {start_row, start_col}
		self.end_ = {end_row, end_col}
		self.changedtick = vim.b.changedtick
		self.buf = a.nvim_get_current_buf()
		self.text = ""
		local name_node = get_decl_name_node(current_node, kind)
		if name_node then
			self.text = ts_utils.get_node_text(name_node, 0)[1] or ""
		end
	end

	while current_node do
		if is_node_kind(current_node, FUNC_KIND_ID) then
			init_cache(FUNC_NAME_ID)
			return
		end
		if is_node_kind(current_node, METHOD_KIND_ID) then
			init_cache(METHOD_NAME_ID)
			return
		end
		if is_node_kind(current_node, TYPE_KIND_ID) then
			init_cache(TYPE_NAME_ID)
			return
		end
		current_node = current_node:parent()
	end
	self:reset()
	return nil
end

function _get_smallest_decl_context()
	if not check_and_reset_env() then return "" end
	if not _context_cache:check_hit() then 
		_context_cache:update_smallest_decl_context() 
	end
	return _context_cache.text
end

function _goto_smallest_decl_context(is_start)
	if not check_and_reset_env() then return "" end
	if not _context_cache:check_hit() then 
		_context_cache:update_smallest_decl_context() 
	end

	if not  _context_cache.start then return end
	local pos = is_start and _context_cache.start or _context_cache.end_
	a.nvim_win_set_cursor(0, {pos[1] + 1, pos[2]})
end

return function(M)
	M.statusline = _get_smallest_decl_context
	M.goto_context_start = function() _goto_smallest_decl_context(true) end
	M.goto_context_end = function() _goto_smallest_decl_context(false) end
	--goto_pre_context = _goto_smallest_decl_context,
	--goto_next_context = _goto_smallest_decl_context,
end