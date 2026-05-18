--- Pandoc Lua filter to convert Markdown callout blocks to Beamer blocks.
-- @module callout2beamer
-- @usage
--   pandoc input.md --lua-filter=callout2beamer -t beamer -o output.pdf
--
-- Maps > [!type] alerts to Beamer block environments:
--   note/info/todo/faq/question     → block (blue)
--   warning/caution/danger/important → alertblock (red)
--   tip/hint/success/example/done   → exampleblock (green)
-- @license MIT

local stringify = require 'pandoc.utils'.stringify

-- Beamer block type mapping
local block_map = {
  note       = 'block',
  info       = 'block',
  todo       = 'block',
  faq        = 'block',
  question   = 'block',
  remark     = 'block',
  abstract   = 'block',
  check      = 'block',
  cite       = 'block',

  warning    = 'alertblock',
  caution    = 'alertblock',
  danger     = 'alertblock',
  important  = 'alertblock',
  attention  = 'alertblock',
  failure    = 'alertblock',
  bug        = 'alertblock',

  tip        = 'exampleblock',
  hint       = 'exampleblock',
  success    = 'exampleblock',
  example    = 'exampleblock',
  done       = 'exampleblock',
}

local default_block = 'block'

--- Handle list conversion
local function handle_list(list)
  local env = (list.t == "BulletList") and "itemize" or "enumerate"
  local result = {"\\begin{" .. env .. "}"}
  for _, item in ipairs(list.content) do
    table.insert(result,
      "\\item " .. pandoc.write(pandoc.Pandoc(item), "latex"))
  end
  table.insert(result, "\\end{" .. env .. "}")
  return table.concat(result, "\\n")
end

function BlockQuote(el)
  if #el.content < 1 or el.content[1].t ~= 'Para' then
    return el
  end

  local first_para = el.content[1].content
  if #first_para < 1 or first_para[1].t ~= 'Str' then
    return el
  end

  local marker_idx = nil
  for i, inline in ipairs(first_para) do
    if inline.t == 'Str' and inline.text:match('^%[!%w+%]$') then
      marker_idx = i
      break
    end
  end
  if not marker_idx then return el end

  local callout_type = first_para[marker_idx].text:match('%[!(%w+)%]')
  if not callout_type then return el end

  local content_start_idx = nil
  for i = marker_idx + 1, #first_para do
    if first_para[i].t == 'SoftBreak' then
      content_start_idx = i + 1
      break
    end
  end

  local title_elems = {}
  for i = marker_idx + 1, (content_start_idx or #first_para + 1) - 1 do
    table.insert(title_elems, first_para[i])
  end

  local content_blocks = pandoc.List()

  if content_start_idx then
    local content_inlines = {}
    for i = content_start_idx, #first_para do
      local elem = first_para[i]
      if elem.t == 'SoftBreak' then
        if #content_inlines > 0 then
          content_blocks:insert(pandoc.Para(content_inlines))
          content_inlines = {}
        end
      else
        table.insert(content_inlines, elem)
      end
    end
    if #content_inlines > 0 then
      content_blocks:insert(pandoc.Para(content_inlines))
    end
  end

  for i = 2, #el.content do
    local block = el.content[i]
    if block.t == "BulletList" or block.t == "OrderedList" then
      content_blocks:insert(
        pandoc.RawBlock("latex", handle_list(block)))
    else
      content_blocks:insert(block)
    end
  end

  local block_type = block_map[callout_type:lower()] or default_block
  local title_str = #title_elems > 0 and stringify(title_elems) or nil

  if title_str then
    title_str = title_str:gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')
  end

  local output_blocks = pandoc.List()
  local title_part = ''
  if title_str ~= nil and not title_str:match('^%s*$') then
    title_part = '{' .. title_str .. '}'
  else
    title_part = '{}'
  end
  output_blocks:insert(
    pandoc.RawBlock('latex',
      '\\begin{' .. block_type .. '}' .. title_part))

  output_blocks:extend(content_blocks)

  output_blocks:insert(pandoc.RawBlock('latex',
    '\\end{' .. block_type .. '}'))
  return output_blocks
end
