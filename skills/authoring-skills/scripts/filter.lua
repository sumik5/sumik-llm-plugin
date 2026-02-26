function Div(el)
  -- 内容を抽出
  return el.content
end

function Link(el)
  -- [](link) のように、表示文字列が空のリンクは生成しない
  if #el.content == 0 then
    return {}
  end
  -- htmlそのままの記法が返ってこないように工夫
  return pandoc.Link(el.content, el.target)
end

local function drop_first(cells)
  -- 1列目を落とす
  local out = {}
  for i = 2, #cells do
    out[#out + 1] = cells[i]
  end
  return out
end

function Table(tbl)
  -- 列情報を更新（更新しないと列を落としてもその分だけ自動補完される）
  if #tbl.colspecs > 1 then
    table.remove(tbl.colspecs, 1)
  end
  for _, body in ipairs(tbl.bodies) do
    for _, row in ipairs(body.body) do
      row.cells = drop_first(row.cells)
    end
    -- 最後の行に空行を追加（最下層に線を引く）
    local col_count = #body.body[1].cells
    local empty_row = pandoc.Row({})
    for i = 1, col_count do
      table.insert(empty_row.cells, pandoc.Cell({pandoc.Plain({pandoc.Str(" ")})}))
    end
    table.insert(body.body, empty_row)
  end
  return tbl
end
