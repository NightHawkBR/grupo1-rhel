-- Filtro Pandoc para a pesquisa em formato ABNT (saída LaTeX).
-- * Resumo em página própria, espaçamento simples; Sumário logo depois.
-- * Numeração de página a partir da Introdução.
-- * Figuras com legenda ACIMA da imagem (a linha "Fonte:" vem no texto, abaixo).
-- * Parágrafos "Fonte: ..." em fonte menor, sem recuo.
-- * Referências em espaçamento simples, alinhadas à esquerda.

local stringify = pandoc.utils.stringify
local in_refs = false

local function raw(s) return pandoc.RawBlock('latex', s) end

function Header(h)
  local t = stringify(h.content)
  if t == 'Resumo' then
    return { raw('\\clearpage\\thispagestyle{empty}\\begingroup\\setstretch{1.0}'),
             raw('\\begin{center}\\textbf{RESUMO}\\end{center}\\vspace{6pt}') }
  elseif t == 'Introdução' and h.level == 1 then
    return { raw('\\endgroup\\clearpage\\tableofcontents\\thispagestyle{empty}\\clearpage\\pagestyle{abnt}'), h }
  elseif t == 'Referências' then
    in_refs = true
    return { raw('\\clearpage\\phantomsection\\addcontentsline{toc}{section}{REFERÊNCIAS}'),
             raw('\\begin{center}\\textbf{REFERÊNCIAS}\\end{center}'),
             raw('\\begingroup\\setstretch{1.0}\\raggedright\\setlength{\\parindent}{0pt}\\setlength{\\parskip}{8pt}') }
  end
  return h
end

function Figure(f)
  local cap = stringify(f.caption.long)
  local img = nil
  pandoc.walk_block(pandoc.Div(f.content), { Image = function(i) img = i end })
  if not img then return nil end
  local w = img.attributes['width'] or '100%'
  local frac = tonumber((w:gsub('%%',''))) / 100
  return raw(string.format(
    '\\begin{figure}[H]\\centering\\caption{%s}\\includegraphics[width=%.2f\\linewidth]{%s}\\end{figure}',
    cap, frac, img.src))
end

function Para(p)
  local first = p.content[1]
  if first and first.t == 'Str' and first.text == 'Fonte:' then
    local out = { pandoc.RawInline('latex', '\\noindent{\\footnotesize ') }
    for _, x in ipairs(p.content) do table.insert(out, x) end
    table.insert(out, pandoc.RawInline('latex', '}\\vspace{4pt}'))
    return pandoc.Para(out)
  end
  if in_refs then
    return p
  end
end

-- Tabelas curtas não se partem entre páginas: reserva espaço antes delas.
function Table(t)
  local rows = 0
  for _, body in ipairs(t.bodies) do rows = rows + #body.body end
  local need = math.min(rows * 2 + 5, 14)
  return { raw(string.format('\\needspace{%d\\baselineskip}', need)), t }
end

function Pandoc(doc)
  if in_refs then
    table.insert(doc.blocks, raw('\\endgroup'))
  end
  return doc
end
