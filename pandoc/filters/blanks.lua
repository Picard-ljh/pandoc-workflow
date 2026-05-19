--- Pandoc Lua filter to convert Markdown underscores to LaTeX blank lines.
-- @module blanks
-- @usage
--   pandoc input.md --lua-filter=blanks.lua -o output.pdf

function Str(elem)
  local text = elem.text
  if not text:find('___', 1, true) then return nil end

  local parts = pandoc.List()
  local pos = 1
  while true do
    local s, e = text:find('___+', pos)
    if not s then break end
    -- extend to consume all consecutive underscores
    while e < #text and text:sub(e + 1, e + 1) == '_' do
      e = e + 1
    end
    if s > pos then
      parts:insert(pandoc.Str(text:sub(pos, s - 1)))
    end
    parts:insert(pandoc.RawInline('latex', '\\underline{\\hspace{3cm}}'))
    pos = e + 1
  end
  if pos <= #text then
    parts:insert(pandoc.Str(text:sub(pos)))
  end
  return parts
end
