--- Pandoc Lua filter to convert Obsidian/Markdown callout blocks to LaTeX
--- environments, with ElegantNote environment mapping.
-- @module callout2latex
-- @author DeepSeek, ChatGPT, Githubonline1396529
-- @release 0.0.3
-- @usage
--   pandoc input.md --lua-filter=callout2latex -o output.pdf
--
-- Converts Markdown callout blocks like:
--   > [!note] Title
--   > Content
-- Into LaTeX environments:
--   \begin{note}[Title]
--   Content
--   \end{note}
--
-- @license MIT

local types = require 'pandoc.utils'.type
local stringify = require 'pandoc.utils'.stringify

--- Handle list conversion
-- @local
-- @param list pandoc.List List element to process
-- @return string LaTeX formatted list
local function handle_list(list)
  local env = (list.t == "BulletList") and "itemize" or "enumerate"
  local result = {"\\begin{" .. env .. "}"}
  for _, item in ipairs(list.content) do
    table.insert(
      result, "\\item " .. pandoc.write(pandoc.Pandoc(item), "latex")
    )
  end
  table.insert(result, "\\end{" .. env .. "}")
  return table.concat(result, "\n")
end

--- Main processing function for BlockQuote elements.
-- @function BlockQuote
-- @param el pandoc.BlockQuote The blockquote element to process
-- @return pandoc.Blocks|nil Modified elements or original if not a callout
-- @usage
function BlockQuote(el)
  if #el.content < 1 or el.content[1].t ~= 'Para' then
    return el
  end

  local first_para = el.content[1].content
  if #first_para < 1 or first_para[1].t ~= 'Str' then
    return el
  end

  local marker_idx = nil
  local marker_rest = nil
  for i, inline in ipairs(first_para) do
    if inline.t == 'Str' then
      local rest = inline.text:match('^%[!%w+%](.*)$')
      if rest then
        marker_idx = i
        marker_rest = rest
        break
      end
    end
  end
  if not marker_idx then return el end

  local callout_type = first_para[marker_idx].text:match('%[!(%w+)%]')
  if not callout_type then return el end

  if marker_rest ~= '' then
    first_para[marker_idx] = pandoc.Str(marker_rest)
    marker_idx = marker_idx - 1
  end

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
        pandoc.RawBlock("latex", handle_list(block))
      )
    else
      content_blocks:insert(block)
    end
  end

  -- Types that conflict with LaTeX built-in commands
  local latex_blacklist = { check = true, cite = true, abstract = true }
  local env_name = callout_type:lower()
  if latex_blacklist[env_name] then
    env_name = 'remark'
  end
  local title_str = #title_elems > 0 and stringify(title_elems) or nil

  if title_str then
    title_str = title_str:gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')
  end

  local output_blocks = pandoc.List()
  local title_part = ''
  if title_str ~= nil and not title_str:match('^%s*$') then
    title_part = '[' .. title_str .. ']'
  end
  output_blocks:insert(
    pandoc.RawBlock(
      'latex',
      '\\begin{' .. env_name .. '}' .. title_part
    )
  )

  output_blocks:extend(content_blocks)

  output_blocks:insert(pandoc.RawBlock('latex', '\\end{'..env_name..'}'))
  return output_blocks
end
