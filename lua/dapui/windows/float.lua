local M = {}
local api = vim.api
local config = {
  max_height = nil,
  max_width = nil
}

local Float = {ids = {}, listeners = {close = {}}, position = {}}

function M.setup(float_config)
  config = vim.tbl_deep_extend("keep", float_config, config)
end

local function create_border_lines(border_opts)
  local width = border_opts.width
  local height = border_opts.height
  local border_lines = {"╭" .. string.rep("─", width - 2) .. "╮"}
  for _ = 3, height, 1 do
    border_lines[#border_lines + 1] = "│" .. string.rep(" ", width - 2) .. "│"
  end
  border_lines[#border_lines + 1] = "╰" .. string.rep("─", width - 2) .. "╯"
  return border_lines
end

local function create_opts(content_width, content_height, position)
  local line_no = position.line
  local col_no = position.col

  local vert_anchor = "N"
  local hor_anchor = "W"

  local max_height = config.max_height or vim.o.lines
  local max_width = config.max_width or vim.o.columns
  if 0 < max_height and max_height < 1 then
    max_height = math.floor(vim.o.lines * max_height)
  end
  if 0 < max_width and max_width < 1 then
    max_width = math.floor(vim.o.columns * max_width)
  end
  local height = math.min(content_height, max_height - 2)
  local width = math.min(content_width, max_width - 2)

  local row = line_no + math.min(0, vim.o.lines - (height + line_no + 3))
  local col = col_no + math.min(0, vim.o.columns - (width + col_no + 3))

  return {
    relative = "editor",
    row = row,
    col = col,
    anchor = vert_anchor .. hor_anchor,
    width = width,
    height = height,
    style = "minimal",
    border = "single"
  }
end

function Float:new(ids, position)
  local win = {}
  setmetatable(win, self)
  self.__index = self
  win.ids = ids
  win.position = position
  return win
end

function Float:listen(event, callback)
  self.listeners[event][#self.listeners[event] + 1] = callback
end

function Float:resize(width, height)
  local opts = create_opts(width, height, self.position)
  api.nvim_win_set_config(self.ids[1], opts)
end

function Float:get_buf()
  local pass, win = pcall(api.nvim_win_get_buf, self.ids[1])
  if not pass then
    return -1
  end
  return win
end

function Float:jump_to()
  api.nvim_set_current_win(self.ids[1])
end

function Float:close(force)
  if not force and api.nvim_get_current_win() == self.ids[1] then
    return false
  end
  local buf = self:get_buf()
  for _, win_id in pairs(self.ids) do
    api.nvim_win_close(win_id, true)
  end
  for _, listener in pairs(self.listeners.close) do
    listener({buffer = buf})
  end
  return true
end

-- settings:
--   Required:
--     height
--     width
--   Optional:
--     buffer
--     position
function M.open_float(settings)
  local line_no = vim.fn.screenrow()
  local col_no = vim.fn.screencol()
  local position = settings.position or {line = line_no, col = col_no}
  local opts = create_opts(settings.width, settings.height, position)
  local content_buffer = settings.buffer or api.nvim_create_buf(false, true)
  local content_window = api.nvim_open_win(content_buffer, false, opts)

  local output_win_id = api.nvim_win_get_number(content_window)
  vim.fn.setwinvar(output_win_id, "&winhl", "Normal:Normal,FloatBorder:DapUIFloatBorder")
  vim.api.nvim_win_set_var(content_window, "wrap", false)

  return Float:new({content_window}, position)
end

return M
