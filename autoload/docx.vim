fun! s:listParts(fn)
  return map(systemlist('unzip -qql '.shellescape(a:fn)), "v:val[30:]")
endf

fun! s:getPartRelationshipsName(part)
  return fnamemodify(a:part, ':h:s?$?/?:s?^\./??').'_rels/'.fnamemodify(a:part, ':t').'.rels'
endf

fun! s:loadPart(fn, part)
  return json_decode(system('unzip -p '.shellescape(a:fn).' '.shellescape(a:part).' | xsltproc '.expand('<script>:h:h').'/xml-to-json.xsl -'))
endf

fun! s:loadRelationships(fn, part = '')
  return json_decode(system('unzip -p '.shellescape(a:fn).' '.shellescape(s:getPartRelationshipsName(a:part)).' | xsltproc '.expand('<script>:h:h').'/xml-to-json.xsl -'))
endf

fun! s:getRelationships(type)
  return filter(copy(b:relationships['children']), $"v:val['attributes']['Type'] == '{a:type}'")
endf

fun! s:getDocumentRelationships(type = v:none)
  if a:type is v:none
    return copy(b:documentRelationships['children'])
  endif
  return filter(copy(b:documentRelationships['children']), $"v:val['attributes']['Type'] == '{a:type}'")
endf

fun! s:getDocumentPart()
  let candidates = s:getRelationships('http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument')

  if len(candidates) == 1
    return candidates[0]['attributes']['Target']
  endif

  return v:none
endf

fun! s:getCommentPart()
  let candidates = s:getDocumentRelationships('http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments')

  if len(candidates) == 1
    return fnamemodify(b:documentPart, ':h:s?$?/?:s?^\./??').candidates[0]['attributes']['Target']
  endif

  return v:none
endf

fun! docx#Load()
  let fn = expand("%:p")

  let b:parts = s:listParts(fn)
  let b:relationships = s:loadRelationships(fn)
  let b:documentPart = s:getDocumentPart()
  let b:documentRelationships = s:loadRelationships(fn, b:documentPart)

  setlocal undolevels=-1 noswapfile
  call docx#Read() | $d | 0d
  sil exe 'keepalt file '.fnameescape(fn)

  let bufnr = bufadd('Styles')
  call setbufvar(bufnr, 'fn', fn)
  exe 'au BufReadCmd <buffer='.bufnr.'> call s:loadStyles()'

  let b:commentsPart = s:getCommentPart()

  if b:commentsPart isnot v:none
    let bufnr = bufadd('Comments')
    call setbufvar(bufnr, 'fn', fn)
    call setbufvar(bufnr, 'part', b:commentsPart)
    exe 'au BufReadCmd <buffer='.bufnr.'> call s:loadComments()'
    exe 'au BufWriteCmd <buffer='.bufnr.'> call s:writeComments()'
    map <F6> :40vs Comments<CR>
    map <F7> :call docx#MakeComment()<CR>
  endif

  au BufReadCmd <buffer> call docx#Read()
  au BufWriteCmd <buffer> call docx#Write()
  setlocal nomod buftype=acwrite undolevels=-123456

  normal gg
endf

fun! s:shouldMergeParagraph(node)
  return len(a:node['children']) > 0 && a:node['children'][0]['tag'] == 'w:pPr' && a:node['children'][0]['children'][0]['tag'] == 'w:rPr' && a:node['children'][0]['children'][0]['children'][0]['tag'] == 'w:del'
endf

fun! docx#Read()
  let docx_document = s:loadPart(expand('%'), b:documentPart)
  call prop_type_add('insertion', {'bufnr': bufnr(), 'highlight': 'DiffAdd'})
  call prop_type_add('deletion', {'bufnr': bufnr(), 'highlight': 'DiffDelete'})
  call prop_type_add('comment', {'bufnr': bufnr()})
  call prop_type_add('current-comment', {'bufnr': bufnr(), 'highlight': 'Underlined'})
  let b:modifications = {}
  let lines = ['']
  for node in docx_document['children'][0]['children']
    if node['tag'] == 'w:p'
      call s:readParagraph(node, lines)
      if !s:shouldMergeParagraph(node)
        for line in lines
          call appendbufline('%', '$', line)
        endfor
        call appendbufline('%', '$', '')
        let lines = ['']
      endif
    elseif node['tag'] == 'w:tbl'
      call s:doTable(node)
    endif
  endfor
  for [key, mod] in items(b:modifications)
    call prop_add(mod['sline'], mod['scol'], {'end_lnum': mod['end_lnum'], 'end_col': mod['end_col'], 'type': mod['type'], 'id': key})
  endfor
endfun

fun! s:writePart(fn, part, content)
  let curdir= getcwd()
  let tmpdir= tempname()
  if tmpdir =~ '\.'
   let tmpdir= substitute(tmpdir,'\.[^.]*$','','e')
  endif
  call mkdir(tmpdir.'/'.fnamemodify(a:part, ':h'),'p')

  exe 'balt '.tmpdir.'/'.a:part
  exe bufload('#')
  exe setbufline('#', 1, '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
  exe appendbufline('#', '$', s:writeElement(a:content))

  hide b #
  sil w
  b #
  let olddir = chdir(tmpdir)
  sil exe '!zip -qf '.shellescape(a:fn)
  call chdir(olddir)
  setlocal nomodified
endf

fun! docx#Write()
  let document = {'tag': 'w:document', 'attributes': {
        \ 'xmlns:wpc': 'http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas',
        \ 'xmlns:cx': 'http://schemas.microsoft.com/office/drawing/2014/chartex',
        \ 'xmlns:cx2': 'http://schemas.microsoft.com/office/drawing/2015/10/21/chartex',
        \ 'xmlns:cx3': 'http://schemas.microsoft.com/office/drawing/2016/5/9/chartex',
        \ 'xmlns:cx4': 'http://schemas.microsoft.com/office/drawing/2016/5/10/chartex',
        \ 'xmlns:cx5': 'http://schemas.microsoft.com/office/drawing/2016/5/11/chartex',
        \ 'xmlns:cx6': 'http://schemas.microsoft.com/office/drawing/2016/5/12/chartex',
        \ 'xmlns:cx7': 'http://schemas.microsoft.com/office/drawing/2016/5/13/chartex',
        \ 'xmlns:cx8': 'http://schemas.microsoft.com/office/drawing/2016/5/14/chartex',
        \ 'xmlns:mc': 'http://schemas.openxmlformats.org/markup-compatibility/2006',
        \ 'xmlns:aink': 'http://schemas.microsoft.com/office/drawing/2016/ink',
        \ 'xmlns:am3d': 'http://schemas.microsoft.com/office/drawing/2017/model3d',
        \ 'xmlns:o': 'urn:schemas-microsoft-com:office:office',
        \ 'xmlns:oel': 'http://schemas.microsoft.com/office/2019/extlst',
        \ 'xmlns:r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
        \ 'xmlns:m': 'http://schemas.openxmlformats.org/officeDocument/2006/math',
        \ 'xmlns:v': 'urn:schemas-microsoft-com:vml',
        \ 'xmlns:wp14': 'http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing',
        \ 'xmlns:wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
        \ 'xmlns:w10': 'urn:schemas-microsoft-com:office:word',
        \ 'xmlns:w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        \ 'xmlns:w14': 'http://schemas.microsoft.com/office/word/2010/wordml',
        \ 'xmlns:w15': 'http://schemas.microsoft.com/office/word/2012/wordml',
        \ 'xmlns:w16cex': 'http://schemas.microsoft.com/office/word/2018/wordml/cex',
        \ 'xmlns:w16cid': 'http://schemas.microsoft.com/office/word/2016/wordml/cid',
        \ 'xmlns:w16': 'http://schemas.microsoft.com/office/word/2018/wordml',
        \ 'xmlns:w16du': 'http://schemas.microsoft.com/office/word/2023/wordml/word16du',
        \ 'xmlns:w16sdtdh': 'http://schemas.microsoft.com/office/word/2020/wordml/sdtdatahash',
        \ 'xmlns:w16sdtfl': 'http://schemas.microsoft.com/office/word/2024/wordml/sdtformatlock',
        \ 'xmlns:w16se': 'http://schemas.microsoft.com/office/word/2015/wordml/symex',
        \ 'xmlns:wpg': 'http://schemas.microsoft.com/office/word/2010/wordprocessingGroup',
        \ 'xmlns:wpi': 'http://schemas.microsoft.com/office/word/2010/wordprocessingInk',
        \ 'xmlns:wne': 'http://schemas.microsoft.com/office/word/2006/wordml',
        \ 'xmlns:wps': 'http://schemas.microsoft.com/office/word/2010/wordprocessingShape',
        \ 'mc:Ignorable': 'w14 w15 w16se w16cid w16 w16cex w16sdtdh w16sdtfl w16du wp14',
        \ }, 'children': []}
  let document['children'] = [s:writeBody(1, line('$'))]
  call s:writePart(expand('%:p'), b:documentPart, document)
  call s:writePart(expand('%:p'), s:getPartRelationshipsName(b:documentPart), b:documentRelationships)
endf

fun! s:getParagraphClass(text)
  let trim = 0
    if match(a:text, '\s*#\+ ') == 0
      let matches = matchlist(a:text, '\s*\(#\+\) ')
      return ['Heading'.len(matches[1]), len(matches[0])]
    elseif match(a:text, '\s*#(.\{-}) ') == 0
      let matches = matchlist(a:text, '\s*#(\(.\{-}\)) ')
      return [matches[1], len(matches[0])]
    elseif match(a:text, '\s*\* ') == 0
      let matches = matchlist(a:text, '\s*\* ')
      return ['ListParagraph', len(matches[0])]
    endif
    return [v:none, 0]
endf

fun! s:writeBody(start, end)
  let body = s:createElement('w:body')
  for line in range(a:start, a:end)
    let text = getline(line)

    let [class, trim] = s:getParagraphClass(text)
    if class isnot v:none
      let container = s:addParagraph(body, class)
    endif

    if text[trim:] == ''
      let container = s:addParagraph(body)
      continue
    endif

    if len(body['children']) == 0
      let container = s:addParagraph(body)
    endif

    let props = filter(prop_list(line,
          \ { 'types': ['insertion', 'deletion', 'comment']  }
          \ ), "v:val['end'] == v:true || v:val['start'] == v:true")

    if len(props) == 0
      call s:writeRun(container, text[trim:])
      continue
    endif

    let runs = s:calculateRuns(text, props)
    let run_props = s:translateProps(copy(props))

    for run in runs
      if run['end'] <= trim
        continue
      endif

      let start_props = get(run_props, run['start'], [])
      let end_props = get(run_props, run['end'], [])
      "echo printf("I am a run on line %d, starting at %d and ending at %d. I have start props [%s] and end props [%s].", line, run['start'], run['end'], join(start_props, ','), join(end_props, ','))
      if len(start_props) > 0
        for prop in start_props
          if prop['open'] == v:true
            if prop['type'] == 'insertion'
              let container = s:createElement('w:ins', {'w:id': prop['id'], 'w:author': b:modifications[prop['id']]['author'], 'w:date': b:modifications[prop['id']]['date'], 'w16du:dateUtc': b:modifications[prop['id']]['dateUtc'] })
              call add(body['children'][-1]['children'], container)
            elseif prop['type'] == 'deletion'
              let container = s:createElement('w:del', {'w:id': prop['id'], 'w:author': b:modifications[prop['id']]['author'], 'w:date': b:modifications[prop['id']]['date'], 'w16du:dateUtc': b:modifications[prop['id']]['dateUtc'] })
              call add(body['children'][-1]['children'], container)
            else
              call add(container['children'], s:createElement('w:commentRangeStart', { 'w:id': prop['id'] }))
            endif
          else
            if prop['type'] == 'insertion' || prop['type'] == 'deletion'
              let container = body['children'][-1]
            else
              call add(container['children'], s:createElement('w:commentRangeEnd', {'w:id': prop['id']}))
              call add(body['children'][-1]['children'], s:createElement('w:r', {}, [
                    \ s:createElement('w:rPr', {}, [
                    \ s:createElement('w:rStyle', {'w:val': 'CommentReference'}),
                    \ s:createElement('w:sz', {'w:val': '24'}),
                    \ s:createElement('w:szCs', {'w:val': '24'})
                    \ ]),
                    \ s:createElement('w:commentReference', {'w:id': prop['id']})
                    \ ]))
            endif
          endif
        endfor
      endif
      call s:writeRun(container, text[run['start']-1:run['end']-1])
      if len(end_props) > 0
        for prop in end_props
          if prop['open'] == v:true
            if prop['type'] == 'insertion'
              let container = s:createElement('w:ins', {'w:id': prop['id'], 'w:author': b:modifications[prop['id']]['author'], 'w:date': b:modifications[prop['id']]['date'], 'w16du:dateUtc': b:modifications[prop['id']]['dateUtc'] })
              call add(body['children'][-1]['children'], container)
            elseif prop['type'] == 'deletion'
              let container = s:createElement('w:del', {'w:id': prop['id'], 'w:author': b:modifications[prop['id']]['author'], 'w:date': b:modifications[prop['id']]['date'], 'w16du:dateUtc': b:modifications[prop['id']]['dateUtc'] })
              call add(body['children'][-1]['children'], container)
            else
              call add(body['children'][-1]['children'], s:createElement('w:commentRangeStart', { 'w:id': prop['id'] }))
            endif
          else
            if prop['type'] == 'insertion' || prop['type'] == 'deletion'
              let container = body['children'][-1]
            else
              call add(container['children'], s:createElement('w:commentRangeEnd', {'w:id': prop['id']}))
              call add(body['children'][-1]['children'], s:createElement('w:r', {}, [
                    \ s:createElement('w:rPr', {}, [
                    \ s:createElement('w:rStyle', {'w:val': 'CommentReference'}),
                    \ s:createElement('w:sz', {'w:val': '24'}),
                    \ s:createElement('w:szCs', {'w:val': '24'})
                    \ ]),
                    \ s:createElement('w:commentReference', {'w:id': prop['id']})
                    \ ]))
            endif
          endif
        endfor
      endif
    endfor
  endfor
  if s:isEmptyParagraph(body)
    unlet body['children'][-1]
  endif
  return body
endf

fun! s:addParagraph(body, style = v:none)
  if s:isEmptyParagraph(a:body)
    if a:style isnot v:none
      call insert(a:body['children'][-1]['children'], {'tag': 'w:pPr', 'attributes': {}, 'children': [
          \ {'tag': 'w:pStyle', 'attributes': {'w:val': a:style}, 'children': []}
          \ ]})
    endif
  else
    if a:style is v:none
      call add(a:body['children'], {'tag': 'w:p', 'attributes': {}, 'children': []})
    else
      call add(a:body['children'], {'tag': 'w:p', 'attributes': {}, 'children': [
            \ {'tag': 'w:pPr', 'attributes': {}, 'children': [
            \ {'tag': 'w:pStyle', 'attributes': {'w:val': a:style}, 'children': []}
            \ ]}
            \ ]})
    endif
  endif
  return a:body['children'][-1]
endf

fun! s:writeRun(container, text, preserve = 1)
  if match(a:text, "[[].*[]](.*)") >= 0
    let start = match(a:text, "[[].*[]](.*)")
    let end = start + len(matchstr(a:text, "[[].*[]](.*)"))

    if start > 0
      call s:writeRun(a:container, a:text[:start - 1], a:preserve)
    endif

    let href = a:text[match(a:text, "(") + 1:end - 2]
    let anchor = a:text[start + 1:match(a:text, "[]]") - 1]

    let candidates = filter(s:getDocumentRelationships('http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink'), $"v:val['attributes']['Target'] == '{href}'")
    if len(candidates) == 1
      let id = candidates[0]['attributes']['Id']
    else
      let rels = s:getDocumentRelationships()
      if len(rels) == 0
        let id = 'rId1'
      else
        let highId = sort(map(rels, "v:val['attributes']['Id']"))[-1]
        let id = 'rId' . (matchstr(highId, '\d\+') + 1)
      endif
      call add(b:documentRelationships['children'], s:createElement('Relationship', {'Id': id, 'TargetMode': 'External', 'Type': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink', 'Target': href}))
    endif

    let hyperlink = s:createElement('w:hyperlink', {'r:id': id}, [])
    call add(a:container['children'], hyperlink)
    call s:writeRun(hyperlink, anchor, a:preserve)

    if end < len(a:text)
      call s:writeRun(a:container, a:text[end:], a:preserve)
    endif
    return
  endif

  let text = a:text

  let textTag = a:container['tag'] == 'w:del' ? 'w:delText' : 'w:t'
  let textAttributes = a:preserve ? {'xml:space': 'preserve'} : {}

  let last_pos = 0
  let matches =  matchstrlist([text], '\*\*\?\*\?\([^*]\{-1,}\)\*\*\?\*\?', {'submatches': v:true})
  if len(matches) > 0
    for thing in matches
      if last_pos < thing['byteidx']
        call add(a:container['children'], s:createElement('w:r', {}, [
              \ s:createElement(textTag, textAttributes, [], text[last_pos:thing['byteidx']-1])
              \ ]))
      endif
      let last_pos = thing['byteidx'] + len(thing['text'])

      if match(thing['text'], '\*\*\*') >= 0
        call add(a:container['children'], s:createElement('w:r', {}, [
              \ s:createElement('w:rPr', {}, [
              \ s:createElement('w:b'),
              \ s:createElement('w:i'),
              \ ]),
              \ s:createElement(textTag, textAttributes, [], thing['submatches'][0] ),
              \ ]))
      elseif match(thing['text'], '\*\*') >= 0
        call add(a:container['children'], s:createElement('w:r', {}, [
              \ s:createElement('w:rPr', {}, [
              \ s:createElement('w:b'),
              \ ]),
              \ s:createElement(textTag, textAttributes, [], thing['submatches'][0] ),
              \ ]))
      elseif match(thing['text'], '\*') >= 0
        call add(a:container['children'], s:createElement('w:r', {}, [
              \ s:createElement('w:rPr', {}, [
              \ s:createElement('w:i')
              \ ]),
              \ s:createElement(textTag, textAttributes, [], thing['submatches'][0] ),
              \ ]))
      endif
    endfor
    let text = text[last_pos:]
  endif
  if match(text, '  $') >= 0
    let text = substitute(text, ' *$', '', '')
    call add(a:container['children'], s:createElement('w:r', {}, [
          \ s:createElement(textTag, textAttributes, [], text ),
          \ s:createElement('w:br')
          \ ]))
  elseif len(text) > 0
    call add(a:container['children'], s:createElement('w:r', {}, [
          \ s:createElement(textTag, textAttributes, [], text )
          \ ]))
  endif
  if a:container['tag'] ==# 'w:hyperlink'
    if a:container['children'][0]['children'][0]['tag'] != 'w:rPr'
      call insert(a:container['children'][0]['children'], s:createElement('w:rPr'))
    endif
    call insert(a:container['children'][0]['children'][0]['children'], s:createElement('w:rStyle', {'w:val': 'Hyperlink'}))
  endif
endf

fun! s:writeParagraph(body, line)
  let text = getline(a:line)

  let [class, trim] = s:getParagraphClass(text)
  if class isnot v:none
    let container = s:addParagraph(a:body, class)
  endif

  if text[trim:] == ''
    call s:addParagraph(a:body)
  else
    if len(a:body['children']) == 0
      let container = s:addParagraph(a:body)
    endif

    call s:writeRun(container, text[trim:], 0)
  endif
endf

fun! s:createElement(tag, attributes = {}, children = [], innerText = v:none)
  if a:innerText isnot v:none
    return {'tag': a:tag, 'attributes': a:attributes, 'innerText': a:innerText}
  endif

  return {'tag': a:tag, 'attributes': a:attributes, 'children': a:children}
endf

fun! s:writeElement(elem)
  let xml = '<'.a:elem['tag']

  for ns in keys(get(a:elem, 'namespaces', {}))
    if len(ns) > 0
      let xml = xml.' xmlns:'.ns.'="'.a:elem['namespaces'][ns].'"'
    else
      let xml = xml.' xmlns="'.a:elem['namespaces'][ns].'"'
    endif
  endfor

  for attribute in keys(get(a:elem, 'attributes', {}))
      let xml = xml.' '.attribute.'="'.a:elem['attributes'][attribute].'"'
  endfor

  if has_key(a:elem, 'innerText')
    return xml.'>'.a:elem['innerText'].'</'.a:elem['tag'].'>'
  endif

  if len(get(a:elem, 'children', [])) == 0
    return xml.'/>'
  endif

  let xml = xml.'>'
  for child in a:elem['children']
    let xml = xml.s:writeElement(child)
  endfor
  return xml.'</'.a:elem['tag'].'>'
endf

fun! s:isEmptyParagraph(body)
  return len(a:body['children']) > 0 && a:body['children'][-1]['tag'] == 'w:p' && len(a:body['children'][-1]['children']) == 0
endf

fun! docx#ToggleComments()
  let comment_ids = get(b:, 'comment_ids', [])
  if len(comment_ids) > 0
    for id in comment_ids
      call popup_close(id)
    endfor
  else
    let b:comment_ids = []
    for [key, comment] in filter(items(b:modifications), "v:val[1]['type'] == 'comment'")
      call add(b:comment_ids, popup_create(key, #{ pos: 'botleft', textprop: 'comment', textpropid: key, border: [], padding: [0,1,0,1], close: 'click'}))
        endfor
  endif
endf

fun! s:readParagraph(container, lines)
  let start = 0
  if len(a:container['children']) == 0
    return []
  elseif a:container['children'][0]['tag'] == 'w:pPr'
    for prop in a:container['children'][0]['children']
      if prop['tag'] == 'w:pStyle'
        if prop['attributes']['w:val'] == 'ListParagraph'
          let a:lines[-1] = '* '
        elseif prop['attributes']['w:val'] == 'Heading1'
          let a:lines[-1] = '# '
        elseif prop['attributes']['w:val'] == 'Heading2'
          let a:lines[-1] = '## '
        elseif prop['attributes']['w:val'] == 'Heading3'
          let a:lines[-1] = '### '
        elseif prop['attributes']['w:val'] == 'Heading4'
          let a:lines[-1] = '#### '
        elseif prop['attributes']['w:val'] == 'Heading5'
          let a:lines[-1] = '##### '
        else
          let a:lines[-1] = '#('.prop['attributes']['w:val'].') '
        endif
      endif
    endfor
    let start = 1
  endif
  call s:readRuns(a:lines, a:container['children'][start:])
endf

fun! s:doTable(container)
  call appendbufline('%', '$', '| | |')
  call appendbufline('%', '$', '| - | - |')
  for node in a:container['children']
    if node['tag'] == 'w:tr'
      call s:doTableRow(node)
    endif
  endfor
endf

fun! s:doTableRow(container)
  for node in a:container['children']
    if node['tag'] == 'w:tr'
      call s:doTableRow(node)
    elseif node['tag'] == 'w:tc'
      for child in filter(node['children'], "v:val['tag'] == 'w:p'")
        let lines = ['']
        call s:readParagraph(child, lines)
        for line in lines
          call appendbufline('%', '$', line)
        endfor
        call appendbufline('%', '$', '')
      endfor
    endif
  endfor
endf

fun! s:readRuns(lines, container)
  for node in a:container
    if node['tag'] == 'w:r'
      call s:readRun(a:lines, node)
    elseif node['tag'] == 'w:hyperlink'
      let a:lines[-1] = a:lines[-1].'['
      call s:readRuns(a:lines, get(node, 'children', []))
      let target = filter(s:getDocumentRelationships('http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink'), "v:val['attributes']['Id'] == '".node['attributes']['r:id']."'")[0]['attributes']['Target']
      let a:lines[-1] = a:lines[-1].']('.target.')'
    elseif node['tag'] == 'w:ins'
      let sline = line('$') + len(a:lines)
      let scol = len(a:lines[-1]) + 1
      call s:readRuns(a:lines, get(node, 'children', []))
      let b:modifications[node['attributes']['w:id']] = {'sline': sline, 'scol': scol, 'end_lnum': line('$') + len(a:lines), 'end_col': len(a:lines[-1]) + 1, 'type': 'insertion', 'author': node['attributes']['w:author'], 'date': node['attributes']['w:date'], 'dateUtc': node['attributes']['w16du:dateUtc']}
    elseif node['tag'] == 'w:del'
      let sline = line('$') + len(a:lines)
      let scol = len(a:lines[-1]) + 1
      call s:readRuns(a:lines, get(node, 'children', []))
      let b:modifications[node['attributes']['w:id']] = {'sline': sline, 'scol': scol, 'end_lnum': line('$') + len(a:lines), 'end_col': len(a:lines[-1]) + 1, 'type': 'deletion', 'author': node['attributes']['w:author'], 'date': node['attributes']['w:date'], 'dateUtc': node['attributes']['w16du:dateUtc']}
    elseif node['tag'] == 'w:commentRangeStart'
      let b:modifications[node['attributes']['w:id']] = {'sline': line('$') + len(a:lines), 'scol': len(a:lines[-1]) + 1, 'type': 'comment'}
    elseif node['tag'] == 'w:commentRangeEnd'
      let b:modifications[node['attributes']['w:id']]['end_lnum'] = line('$') + len(a:lines)
      let b:modifications[node['attributes']['w:id']]['end_col'] = len(a:lines[-1]) + 1
    elseif node['tag'] == 'w:moveTo'
      call s:readRuns(a:lines, get(node, 'children', []))
    endif
  endfor
endf

fun! s:readRun(lines, container)
  let bold = v:false
  let italic = v:false
  for t in a:container['children']
    if t['tag'] == 'w:rPr'
      for prop in t['children']
        if prop['tag'] == 'w:b'
          let bold = v:true
          let a:lines[-1] = a:lines[-1].'**'
        elseif prop['tag'] == 'w:i'
          let italic = v:true
          let a:lines[-1] = a:lines[-1].'*'
        endif
      endfor
    elseif t['tag'] == 'w:t'
      let a:lines[-1] = a:lines[-1].t['innerText']
    elseif t['tag'] == 'w:delText'
      let a:lines[-1] = a:lines[-1].t['innerText']
    elseif t['tag'] == 'w:br'
      let a:lines[-1] = a:lines[-1].'  '
      call add(a:lines, '')
    endif
  endfor
  if bold
    let a:lines[-1] = a:lines[-1].'**'
  endif
  if italic
    let a:lines[-1] = a:lines[-1].'*'
  endif
endf

fun! s:loadStyles()
  set noswapfile buftype=acwrite undolevels=-1

  let styles = s:loadPart(b:fn, 'word/styles.xml')
  call setbufline('%', 1, 'styles:')
  for node in filter(styles['children'], "v:val['tag'] == 'w:style'")
    call s:doStyle(node)
  endfor
  set nomod undolevels=-123456
endf

fun! s:doStyle(node)
  call appendbufline('%', '$', '  '.a:node['attributes']['w:styleId'].':')
  call appendbufline('%', '$', '    type: '.a:node['attributes']['w:type'])
  call appendbufline('%', '$', '    custom: '.a:node['attributes']->get('w:customStyle'))
  for child in a:node['children']
    if has_key(child['attributes'], 'w:val')
      call appendbufline('%', '$', '    '.child['tag'].': '.child['attributes']['w:val'])
    else
      call appendbufline('%', '$', '    '.child['tag'].':')
      for subchild in child['children']
        if has_key(subchild['attributes'], 'w:val')
          call appendbufline('%', '$', '      '.subchild['tag'].': '.subchild['attributes']['w:val'])
        endif
      endfor
    endif
  endfor
endf

fun! s:loadComments()
  set noswapfile buftype=acwrite undolevels=-1

  let comments = s:loadPart(b:fn, b:part)
  call setbufline('%', 1, 'comments:')
  for node in filter(comments['children'], "v:val['tag'] == 'w:comment'")
    call s:readComment(node)
  endfor
  au CursorMoved <buffer> call s:hiliteComment()
  au BufLeave <buffer> call prop_remove(#{bufnr: 1, type: 'current-comment', all: v:true})
  set nomod undolevels=-123456
endf

fun! s:writeComments()
  let comments = {'tag': 'w:comments', 'attributes': {
        \ 'xmlns:wpc': "http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas",
        \ 'xmlns:cx': "http://schemas.microsoft.com/office/drawing/2014/chartex",
        \ 'xmlns:cx1': "http://schemas.microsoft.com/office/drawing/2015/9/8/chartex",
        \ 'xmlns:cx2': "http://schemas.microsoft.com/office/drawing/2015/10/21/chartex",
        \ 'xmlns:cx3': "http://schemas.microsoft.com/office/drawing/2016/5/9/chartex",
        \ 'xmlns:cx4': "http://schemas.microsoft.com/office/drawing/2016/5/10/chartex",
        \ 'xmlns:cx5': "http://schemas.microsoft.com/office/drawing/2016/5/11/chartex",
        \ 'xmlns:cx6': "http://schemas.microsoft.com/office/drawing/2016/5/12/chartex",
        \ 'xmlns:cx7': "http://schemas.microsoft.com/office/drawing/2016/5/13/chartex",
        \ 'xmlns:cx8': "http://schemas.microsoft.com/office/drawing/2016/5/14/chartex",
        \ 'xmlns:mc': "http://schemas.openxmlformats.org/markup-compatibility/2006",
        \ 'xmlns:aink': "http://schemas.microsoft.com/office/drawing/2016/ink",
        \ 'xmlns:am3d': "http://schemas.microsoft.com/office/drawing/2017/model3d",
        \ 'xmlns:o': "urn:schemas-microsoft-com:office:office",
        \ 'xmlns:oel': "http://schemas.microsoft.com/office/2019/extlst",
        \ 'xmlns:r': "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
        \ 'xmlns:m': "http://schemas.openxmlformats.org/officeDocument/2006/math",
        \ 'xmlns:v': "urn:schemas-microsoft-com:vml",
        \ 'xmlns:wp14': "http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing",
        \ 'xmlns:wp': "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing",
        \ 'xmlns:w10': "urn:schemas-microsoft-com:office:word",
        \ 'xmlns:w': "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
        \ 'xmlns:w14': "http://schemas.microsoft.com/office/word/2010/wordml",
        \ 'xmlns:w15': "http://schemas.microsoft.com/office/word/2012/wordml",
        \ 'xmlns:w16cex': "http://schemas.microsoft.com/office/word/2018/wordml/cex",
        \ 'xmlns:w16cid': "http://schemas.microsoft.com/office/word/2016/wordml/cid",
        \ 'xmlns:w16': "http://schemas.microsoft.com/office/word/2018/wordml",
        \ 'xmlns:w16du': "http://schemas.microsoft.com/office/word/2023/wordml/word16du",
        \ 'xmlns:w16sdtdh': "http://schemas.microsoft.com/office/word/2020/wordml/sdtdatahash",
        \ 'xmlns:w16sdtfl': "http://schemas.microsoft.com/office/word/2024/wordml/sdtformatlock",
        \ 'xmlns:w16se': "http://schemas.microsoft.com/office/word/2015/wordml/symex",
        \ 'xmlns:wpg': "http://schemas.microsoft.com/office/word/2010/wordprocessingGroup",
        \ 'xmlns:wpi': "http://schemas.microsoft.com/office/word/2010/wordprocessingInk",
        \ 'xmlns:wne': "http://schemas.microsoft.com/office/word/2006/wordml",
        \ 'xmlns:wps': "http://schemas.microsoft.com/office/word/2010/wordprocessingShape",
        \ 'mc:Ignorable': "w14 w15 w16se w16cid w16 w16cex w16sdtdh w16sdtfl w16du wp14"}, 'children': []}

  let line = 2
  while line < line('$')
    for line2 in range(line + 1, line('$'))
      let text = getline(line2)
      if match(text, '  \d\+:') >= 0
        let line2 = line2 - 1
        break
      endif
    endfor
    let text = getline(line)
    let matches = matchlist(text, '  \(\d\+\):')
    let comment = {'tag': 'w:comment', 'attributes': {
          \ 'w:id': matches[1],
          \ }, 'children': []}
    for content in range(line, line2)
      let matches = matchlist(getline(content), '    \(\a\+\): \(.*\)')
      if len(matches) > 0
        let comment['attributes']['w:'.matches[1]] = matches[2]
      elseif match(getline(content), '    content:') == 0
        let content = content + 1
        break
      endif
    endfor
    for para in range(content, line2)
      call s:writeParagraph(comment, para)
    endfor
    if s:isEmptyParagraph(comment)
      unlet comment['children'][-1]
    endif
    call insert(comment['children'][0]['children'], s:createElement('w:r', {}, [
          \ s:createElement('w:rPr', {}, [
          \ s:createElement('w:rStyle', {'w:val': 'CommentReference'})
          \ ]),
          \ s:createElement('w:annotationRef')
          \ ]), 1)
    call add(comments['children'], comment)
    let line = line2 + 1
  endwhile
  call s:writePart(b:fn, b:part, comments)
endf

fun! s:hiliteComment()
  call prop_remove(#{bufnr: 1, type: 'current-comment', all: v:true})
  let line = line('.')
  while line > 0
    let matches = matchlist(getline(line), '^  \(\d\+\):$')
    if len(matches) > 0
      let start = prop_find(#{id: matches[1], type: 'comment', bufnr: 1, both: v:true, lnum: 1, col: 1})
      if empty(start)
        return
      endif
      if start['end'] == v:false
        let line = start['lnum']
        let end = []
        while len(end) == 0
          let line = line + 1
          let end = filter(prop_list(line, #{bufnr: 1, id: matches[1], type: 'comment'}), "v:val['end'] == v:true && v:val['type'] == 'comment' && v:val['id'] == ".matches[1])
        endwhile
        let props = [start['lnum'], start['col'], line, end[0]['length'] + 1]
      else
        let props = [start['lnum'], start['col'], start['lnum'], start['col'] + start['length']]
      endif
      call prop_add_list(#{bufnr: 1, id: matches[1], type: 'current-comment'}, [props])
      call win_execute(bufwinid(1), 'normal '.start['lnum'].'G')

      break
    else
      let line = line - 1
    endif
  endwhile
endf

fun! s:readComment(node)
  call appendbufline('%', '$', '  '.a:node['attributes']['w:id'].':')
  call appendbufline('%', '$', '    author: '.a:node['attributes']['w:author'])
  call appendbufline('%', '$', '    date: '.a:node['attributes']['w:date'])
  call appendbufline('%', '$', '    initials: '.a:node['attributes']['w:initials'])
  call appendbufline('%', '$', '    content:')
  for node in a:node['children']
    let lines = ['']
    call s:readParagraph(node, lines)
    for line in lines
      call appendbufline('%', '$', '      '.line)
    endfor
    call appendbufline('%', '$', '')
  endfor
endf

fun! docx#MakeComment()
  let [line_start, column_start] = getpos("'<")[1:2]
  let [line_end, column_end] = getpos("'>")[1:2]
  let column_end = column_end + (&selection ==# 'inclusive' ? 1 : 0)
  if (line2byte(line_start) + column_start) > (line2byte(line_end) + column_end)
    let [line_start, column_start, line_end, column_end] = [line_end, column_end, line_start, column_start]
  endif
  let ids = sort(keys(b:modifications), 'N')
  let id = ids[-1] + 1
  let b:modifications[id] = {'sline': line_start, 'scol': column_start, 'end_lnum': line_end, 'end_col': column_end, 'type': 'comment'}
  call prop_add(line_start, column_start, {'end_lnum': line_end, 'end_col': column_end, 'type': 'comment', 'id': id})
  set mod
  let buffy = bufnr('Comments')
  call bufload(buffy)
  call appendbufline(buffy, '$', '  '.id.':')
  call appendbufline(buffy, '$', '    author: '.get(g:, 'docx_author', 'Vim User'))
  call appendbufline(buffy, '$', '    date: '.strftime('%Y-%m-%dT%H:%M:00Z'))
  call appendbufline(buffy, '$', '    initials: '.get(g:, 'docx_initials', 'VU'))
  call appendbufline(buffy, '$', '    content:')
  call appendbufline(buffy, '$', '      #(CommentText) ')
  if len(win_findbuf(buffy)) == 0
    40 vs Comments
    normal G$
  endif
endf

fun! s:calculateRuns(text, props)
    let bobs = {'1': v:none}
    for prop in a:props
      let bobs[prop['col']] = v:none
      if prop['col'] + prop['length'] < len(a:text)
        let bobs[prop['col'] + prop['length']] = v:none
      endif
    endfor
    let runs = []
    for bob in sort(keys(bobs), 'N')
      if len(runs) > 0
        let runs[-1]['end'] = bob - 1
      endif
      if bob <= len(a:text)
        call add(runs, {'start': bob + 0})
      endif
    endfor
    let runs[-1]['end'] = len(a:text)
    return runs
endf

fun! s:compareProp(a, b)
  return a:a['open'] - a:b['open']
endf

fun! s:translateProps(props)
  let col_props = {}
  for prop in a:props
    if prop['start'] == 1
      let col_props[prop['col']] = get(col_props, prop['col'], []) + [{'open': v:true, 'type': prop['type'], 'id': prop['id']}]
    endif
    if prop['end'] == 1
      let start = max([prop['col'] + prop['length'] - 1, 1])
      let col_props[start] = get(col_props, start, []) + [{'open': v:false, 'type': prop['type'], 'id': prop['id']}]
    endif
  endfor
  for key in keys(col_props)
    let col_props[key] = sort(col_props[key], function("s:compareProp"))
  endfor
  return col_props
endf
