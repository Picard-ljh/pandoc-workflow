--- Pandoc Lua filter to auto-wrap slide body content in beamer blocks.
-- For use with slide-level: 1 in exercise mode.
-- Wraps content between consecutive level-1 headers in \begin{block}{}...\end{block},
-- unless the slide already contains block markup (from callout2beamer or ### headers).
-- @module exercise-block
-- @usage
--   pandoc input.md --lua-filter=exercise-block.lua -t beamer -o output.pdf

local function slide_has_block(content)
  for _, b in ipairs(content) do
    if b.t == 'RawBlock' and b.format == 'latex' then
      local text = b.text:gsub('^%s+', '')
      if text:match('^\\begin{') then
        return true
      end
    elseif b.t == 'Header' and b.level >= 2 then
      return true
    elseif b.t == 'Div' then
      return true
    end
  end
  return false
end

function Pandoc(doc)
  local new_blocks = pandoc.List()
  local i = 1
  while i <= #doc.blocks do
    local block = doc.blocks[i]
    if block.t == 'Header' and block.level == 1 then
      new_blocks:insert(block)
      i = i + 1
      local slide_content = pandoc.List()
      while i <= #doc.blocks do
        local next_block = doc.blocks[i]
        if next_block.t == 'Header' and next_block.level == 1 then
          break
        end
        slide_content:insert(next_block)
        i = i + 1
      end
      if #slide_content > 0 then
        if slide_has_block(slide_content) then
          new_blocks:extend(slide_content)
        else
          new_blocks:insert(pandoc.RawBlock('latex', '\\begin{block}{}'))
          new_blocks:extend(slide_content)
          new_blocks:insert(pandoc.RawBlock('latex', '\\end{block}'))
        end
      end
    else
      -- Blocks before the first #: pass through unwrapped (shouldn't exist in well-formed exercise docs)
      new_blocks:insert(block)
      i = i + 1
    end
  end
  doc.blocks = new_blocks
  return doc
end