-- pandoc Lua filter: neutralize raw HTML and dangerous URL schemes at the AST level.
-- RawBlock/RawInline (format html/html5) become verbatim code so tags cannot execute.
-- Link/Image targets with javascript:/vbscript:/file:/data: schemes are defanged.

local RAW_HTML_FORMATS = {
  html = true,
  html4 = true,
  html5 = true,
}

local DANGEROUS_SCHEMES = { "javascript:", "vbscript:", "file:" }

local function normalize(target)
  return (target or ""):gsub("[%s\1-\31]", ""):lower()
end

local function has_dangerous_scheme(cleaned)
  for _, scheme in ipairs(DANGEROUS_SCHEMES) do
    if cleaned:sub(1, #scheme) == scheme then
      return true
    end
  end
  return false
end

function RawBlock(el)
  if RAW_HTML_FORMATS[el.format] then
    return pandoc.CodeBlock(el.text)
  end
end

function RawInline(el)
  if RAW_HTML_FORMATS[el.format] then
    return pandoc.Code(el.text)
  end
end

function Link(el)
  local cleaned = normalize(el.target)
  if has_dangerous_scheme(cleaned) or cleaned:sub(1, 5) == "data:" then
    el.target = "#"
  end
  return el
end

function Image(el)
  local cleaned = normalize(el.src)
  if has_dangerous_scheme(cleaned) then
    el.src = ""
  elseif cleaned:sub(1, 5) == "data:" and cleaned:sub(1, 11) ~= "data:image/" then
    el.src = ""
  end
  return el
end
