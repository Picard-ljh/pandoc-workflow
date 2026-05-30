--- Pandoc Lua filter to auto-wrap slide body content in beamer blocks.
-- For use with slide-level: 1 in exercise mode.
-- Wraps content between consecutive level-1 headers in \begin{block}{}...\end{block}.
-- @module exercise-block
-- @usage
--   pandoc input.md --lua-filter=exercise-block.lua -t beamer -o output.pdf

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
        new_blocks:insert(pandoc.RawBlock('latex', '\\begin{block}{}'))
        new_blocks:extend(slide_content)
        new_blocks:insert(pandoc.RawBlock('latex', '\\end{block}'))
      end
    else
      new_blocks:insert(block)
      i = i + 1
    end
  end
  doc.blocks = new_blocks
  return doc
end
