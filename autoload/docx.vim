fun! s:listParts(fn)
  return system('unzip -qql '.shellescape(a:fn)." | awk -F' ' '{print $4;}'")
endf

fun! s:loadPart(fn, part)
  return json_decode(system('unzip -p '.shellescape(a:fn).' '.shellescape(a:part).' | xsltproc '.expand('<script>:h:h').'/xml-to-json.xsl - | sed -z "s/\n/\\n/g;s/‽/\\\\\"/g"'))
endf

fun! docx#Load()
  let fn = expand("%:p")

  let b:parts = s:listParts(fn)

  setlocal undolevels=-1 noswapfile
  call docx#Read() | $d | 0d
  sil exe 'keepalt file '.fnameescape(fn)

  let bufnr = bufadd('Styles')
  call setbufvar(bufnr, 'fn', fn)
  exe 'au BufReadCmd <buffer='.bufnr.'> call s:loadStyles()'

  if match(b:parts, 'word/comments.xml') >= 0
    let bufnr = bufadd('Comments')
    call setbufvar(bufnr, 'fn', fn)
    exe 'au BufReadCmd <buffer='.bufnr.'> call s:loadComments()'
    exe 'au BufWriteCmd <buffer='.bufnr.'> call s:writeComments()'
    map <F6> :40vs Comments<CR>
    map <F7> :call docx#MakeComment()<CR>
  endif

  au BufReadCmd <buffer> call docx#Read()
  au BufWriteCmd <buffer> call docx#Write()
  setlocal nomod buftype=acwrite undolevels=-123456
  run! syntax/markdown.vim

  normal gg
endf

fun! docx#Read()
  let docx_document = s:loadPart(expand('%'), 'word/document.xml')
  call prop_type_add('insertion', {'bufnr': bufnr(), 'highlight': 'DiffAdd'})
  call prop_type_add('deletion', {'bufnr': bufnr(), 'highlight': 'DiffDelete'})
  call prop_type_add('comment', {'bufnr': bufnr()})
  call prop_type_add('current-comment', {'bufnr': bufnr(), 'highlight': 'Underlined'})
  let b:modifications = {}
  for node in docx_document['children'][0]['children']
    if node['tag'] == 'w:p'
      for line in s:readParagraph(node)
        call appendbufline('%', '$', line)
      endfor
      call appendbufline('%', '$', '')
    elseif node['tag'] == 'w:tbl'
      call s:doTable(node)
    endif
  endfor
  for [key, mod] in items(b:modifications)
    call prop_add(mod['sline'], mod['scol'], {'end_lnum': mod['end_lnum'], 'end_col': mod['end_col'], 'type': mod['type'], 'id': key})
  endfor
endfun

fun! s:writePart(fn, name, content)
  let curdir= getcwd()
  let tmpdir= tempname()
  if tmpdir =~ '\.'
   let tmpdir= substitute(tmpdir,'\.[^.]*$','','e')
  endif
  call mkdir(tmpdir.'/word','p')

  exe 'balt '.tmpdir.'/word/'.a:name.'.xml'
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
  call s:writePart(expand('%:p'), 'document', document)
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

fun! s:compareProp(a, b)
  if a:a['type'] == 'comment' && a:b['type'] != 'comment'
    if a:a['start'] == 0
      return 1
    else
      return -1
    endif
  elseif a:a['type'] != 'comment' && a:b['type'] == 'comment'
    if a:a['start'] == 0
      return -1
    else
      return 1
    endif
  endif
  return 0
endf

fun! s:comparePropStart(a, b)
  return a:a['start'] - a:b['start']
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

    let runs = s:calculateRuns(getline(line), props)

    for run in runs
      echo run['start']
      echo props
      let run_props = sort(filter(copy(props), "v:val['col'] == run['start']"), function("s:comparePropStart"))
      echo run_props
      if len(run_props) > 0
        for prop in run_props
          if prop['start'] == v:true
            if prop['type'] == 'insertion'
              let container = s:createElement('w:ins', {'w:id': prop['id']})
              let body['children'][-1]['children'] = body['children'][-1]['children'] + [container]
            elseif prop['type'] == 'deletion'
              let container = s:createElement('w:del', {'w:id': prop['id']})
              let body['children'][-1]['children'] = body['children'][-1]['children'] + [container]
            else
              let body['children'][-1]['children'] = body['children'][-1]['children']
                    \ + [s:createElement('w:commentRangeStart', { 'w:id': prop['id'] })]
            endif
          elseif prop['col'] + prop['length'] <= run['end']
            "echo 'closing '.prop['type'].' with id '.prop['id']
            if prop['type'] == 'insertion' || prop['type'] == 'deletion'
              let container = body['children'][-1]
            else
              let body['children'][-1]['children'] = body['children'][-1]['children']
                    \ + [s:createElement('w:commentRangeEnd', {'w:id': prop['id']})]
            endif
          endif
        endfor
      endif
      call s:writeRun(container, text[run['start']-1:run['end']-1])
      let run_props = filter(copy(props), "v:val['col'] + v:val['length'] == run['end']")
      if len(run_props) > 0
        for prop in run_props
          if prop['start'] == v:true
            if prop['type'] == 'insertion'
              let container = s:createElement('w:ins', {'w:id': prop['id']})
              let body['children'][-1]['children'] = body['children'][-1]['children'] + [container]
            elseif prop['type'] == 'deletion'
              let container = s:createElement('w:del', {'w:id': prop['id']})
              let body['children'][-1]['children'] = body['children'][-1]['children'] + [container]
            else
              let body['children'][-1]['children'] = body['children'][-1]['children']
                    \ + [s:createElement('w:commentRangeStart', { 'w:id': prop['id'] })]
            endif
          else
            "echo 'closing '.prop['type'].' with id '.prop['id']
            if prop['type'] == 'insertion' || prop['type'] == 'deletion'
              let container = body['children'][-1]
            else
              let body['children'][-1]['children'] = body['children'][-1]['children']
                    \ + [s:createElement('w:commentRangeEnd', {'w:id': prop['id']})]
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
      let a:body['children'][-1]['children'] = [
          \ {'tag': 'w:pPr', 'attributes': {}, 'children': [
          \ {'tag': 'w:pStyle', 'attributes': {'w:val': a:style}, 'children': []}
          \ ]}] + a:body['children'][-1]['children']
    endif
  else
    if a:style is v:none
      let a:body['children'] = a:body['children'] + [{'tag': 'w:p', 'attributes': {}, 'children': []}]
    else
      let a:body['children'] = a:body['children'] + [{'tag': 'w:p', 'attributes': {}, 'children': [
            \ {'tag': 'w:pPr', 'attributes': {}, 'children': [
            \ {'tag': 'w:pStyle', 'attributes': {'w:val': a:style}, 'children': []}
            \ ]}
            \ ]}]
    endif
  endif
  return a:body['children'][-1]
endf

fun! s:writeRun(container, text)
  let text = a:text
  let textTag = a:container['tag'] == 'w:del' ? 'w:delText' : 'w:t'

  let last_pos = 0
  let matches =  matchstrlist([text], '\*\*\?\*\?\([^*]\{-1,}\)\*\*\?\*\?', {'submatches': v:true})
  if len(matches) > 0
    for thing in matches
      if last_pos < thing['byteidx']
        let a:container['children'] = a:container['children'] + [
              \ {'tag': 'w:r', 'attributes': {}, 'children': [
              \ {'tag': textTag, 'attributes': {'xml:space': 'preserve'}, 'innerText': text[last_pos:thing['byteidx']-1] }
              \ ]}
              \ ]
      endif
      let last_pos = thing['byteidx'] + len(thing['text'])

      if match(thing['text'], '\*\*\*') >= 0
        let a:container['children'] = a:container['children'] + [
              \ {'tag': 'w:r', 'attributes': {}, 'children': [
              \ {'tag': 'w:rPr', 'attributes': {}, 'children': [
              \ {'tag': 'w:b', 'attributes': {}, 'children': [] },
              \ {'tag': 'w:i', 'attributes': {}, 'children': [] }
              \ ]},
              \ {'tag': textTag, 'attributes': {'xml:space': 'preserve'}, 'innerText': thing['submatches'][0] },
              \ ]}
              \ ]
      elseif match(thing['text'], '\*\*') >= 0
        let a:container['children'] = a:container['children'] + [
              \ {'tag': 'w:r', 'attributes': {}, 'children': [
              \ {'tag': 'w:rPr', 'attributes': {}, 'children': [
              \ {'tag': 'w:b', 'attributes': {}, 'children': [] },
              \ ]},
              \ {'tag': textTag, 'attributes': {'xml:space': 'preserve'}, 'innerText': thing['submatches'][0] },
              \ ]}
              \ ]
      elseif match(thing['text'], '\*') >= 0
        let a:container['children'] = a:container['children'] + [
              \ {'tag': 'w:r', 'attributes': {}, 'children': [
              \ {'tag': 'w:rPr', 'attributes': {}, 'children': [
              \ {'tag': 'w:i', 'attributes': {}, 'children': [] },
              \ ]},
              \ {'tag': textTag, 'attributes': {'xml:space': 'preserve'}, 'innerText': thing['submatches'][0] },
              \ ]}
              \ ]
      endif
    endfor
    let text = text[last_pos:]
  endif
  if match(text, '  $') >= 0
    let text = substitute(text, ' *$', '', '')
    let a:container['children'] = a:container['children'] + [
          \ {'tag': 'w:r', 'attributes': {}, 'children': [
          \ {'tag': textTag, 'attributes': {'xml:space': 'preserve'}, 'innerText': text },
          \ {'tag': 'w:br', 'attributes': {}, 'children': [] }
          \ ]}
          \ ]
  elseif len(text) > 0
    let a:container['children'] = a:container['children'] + [
          \ {'tag': 'w:r', 'attributes': {}, 'children': [
          \ {'tag': textTag, 'attributes': {'xml:space': 'preserve'}, 'innerText': text }
          \ ]}
          \ ]
  endif
endf

fun! s:writeParagraph(body, line)
  let text = getline(a:line)
  let col = 1

  let body = a:body
  let [class, trim] = s:getParagraphClass(text)
  call s:addParagraph(body, class)
  let col = col + trim
  let text = text[trim:]

  if text == ''
    call s:addParagraph(body)
    return body
  endif

  if len(body['children']) == 0
    call s:addParagraph(body)
  endif

  let props = prop_list(a:line, {'types': ['insertion', 'deletion', 'comment']})
  if len(props) == 0
    call s:writeRun(body['children'][-1], text)
    return body
  endif

  let runs = s:calculateRuns(getline(a:line))

  let bobby = getline(a:line)
  for run in runs
    echo filter(props, "v:val['col'] == run['start']")
    if len(props) == 0 || run['end'] < props[0]['col']
      call s:writeRun(body['children'][-1], bobby[run['start']-1:run['end']-1])
    else
      if props[0]['type'] == 'insertion'
        let body['children'][-1]['children'] = body['children'][-1]['children'] + [{'tag': 'w:ins', 'attributes': {'w:id': props[0]['id']}, 'children': []}]
        call s:writeRun(body['children'][-1]['children'][-1], bobby[run['start']-1:run['end']-1])
      elseif props[0]['type'] == 'deletion'
        let body['children'][-1]['children'] = body['children'][-1]['children'] + [{'tag': 'w:del', 'attributes': {'w:id': props[0]['id']}, 'children': []}]
        call s:writeRun(body['children'][-1]['children'][-1], bobby[run['start']-1:run['end']-1])
      elseif props[0]['type'] == 'comment'
        let body['children'][-1]['children'] = body['children'][-1]['children'] + [{'tag': 'w:commentRangeStart', 'attributes': {'w:id': props[0]['id']}, 'children': []}]
        call s:writeRun(body['children'][-1], bobby[run['start']-1:run['end']-1])
        let body['children'][-1]['children'] = body['children'][-1]['children'] + [{'tag': 'w:commentRangeEnd', 'attributes': {'w:id': props[0]['id']}, 'children': []}]
      endif

      let props = props[1:]
    endif
  endfor

  return body
endf

fun! s:createElement(tag, attributes = {}, children = [])
  return {'tag': a:tag, 'attributes': a:attributes, 'children': a:children}
endf

fun! s:writeElement(elem)
  let xml = '<'.a:elem['tag']
  for attribute in keys(a:elem['attributes'])
    let xml = xml.' '.attribute.'="'.a:elem['attributes'][attribute].'"'
  endfor

  if has_key(a:elem, 'innerText')
    return xml.'>'.a:elem['innerText'].'</'.a:elem['tag'].'>'
  endif

  if len(a:elem['children']) == 0
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
      let b:comment_ids = b:comment_ids + [popup_create(key, #{ pos: 'botleft', textprop: 'comment', textpropid: key, border: [], padding: [0,1,0,1], close: 'click'})]
        endfor
  endif
endf

fun! s:readParagraph(container)
  let start = 0
  let lines = ['']
  if len(a:container['children']) == 0
    return []
  elseif a:container['children'][0]['tag'] == 'w:pPr'
    for prop in a:container['children'][0]['children']
      if prop['tag'] == 'w:pStyle'
        if prop['attributes']['w:val'] == 'ListParagraph'
          let lines[-1] = '* '
        elseif prop['attributes']['w:val'] == 'Heading1'
          let lines[-1] = '# '
        elseif prop['attributes']['w:val'] == 'Heading2'
          let lines[-1] = '## '
        elseif prop['attributes']['w:val'] == 'Heading3'
          let lines[-1] = '### '
        elseif prop['attributes']['w:val'] == 'Heading4'
          let lines[-1] = '#### '
        elseif prop['attributes']['w:val'] == 'Heading5'
          let lines[-1] = '##### '
        else
          let lines[-1] = '#('.prop['attributes']['w:val'].') '
        endif
      endif
    endfor
    let start = 1
  endif
  return s:readRuns(lines, a:container['children'][start:])
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
        for line in s:readParagraph(child)
          call appendbufline('%', '$', line)
        endfor
        call appendbufline('%', '$', '')
      endfor
    endif
  endfor
endf

fun! s:readRuns(lines, container)
  let ret = a:lines
  for node in a:container
    if node['tag'] == 'w:r'
      let ret = s:readRun(ret, node)
    elseif node['tag'] == 'w:ins'
      let sline = line('$') + len(ret)
      let scol = len(ret[-1]) + 1
      let ret = s:readRuns(ret, node['children'])
      let b:modifications[node['attributes']['w:id']] = {'sline': sline, 'scol': scol, 'end_lnum': line('$') + len(ret), 'end_col': len(ret[-1]) + 1, 'type': 'insertion'}
    elseif node['tag'] == 'w:del'
      let sline = line('$') + len(ret)
      let scol = len(ret[-1]) + 1
      let ret = s:readRuns(ret, node['children'])
      let b:modifications[node['attributes']['w:id']] = {'sline': sline, 'scol': scol, 'end_lnum': line('$') + len(ret), 'end_col': len(ret[-1]) + 1, 'type': 'deletion'}
    elseif node['tag'] == 'w:commentRangeStart'
      let b:modifications[node['attributes']['w:id']] = {'sline': line('$') + len(ret), 'scol': len(ret[-1]) + 1, 'type': 'comment'}
    elseif node['tag'] == 'w:commentRangeEnd'
      let b:modifications[node['attributes']['w:id']]['end_lnum'] = line('$') + len(ret)
      let b:modifications[node['attributes']['w:id']]['end_col'] = len(ret[-1]) + 1
    elseif node['tag'] == 'w:moveTo'
      let ret = s:readRuns(ret, node['children'])
    endif
  endfor
  return ret
endf

fun! s:readRun(lines, container)
  let ret = a:lines
  let bold = v:false
  let italic = v:false
  for t in a:container['children']
    if t['tag'] == 'w:rPr'
      for prop in t['children']
        if prop['tag'] == 'w:b'
          let bold = v:true
          let ret[-1] = ret[-1].'**'
        elseif prop['tag'] == 'w:i'
          let italic = v:true
          let ret[-1] = ret[-1].'*'
        endif
      endfor
    elseif t['tag'] == 'w:t'
      let ret[-1] = ret[-1].t['innerText']
    elseif t['tag'] == 'w:delText'
      let ret[-1] = ret[-1].t['innerText']
    elseif t['tag'] == 'w:br'
      let ret[-1] = ret[-1].'  '
      let ret = ret + ['']
    endif
  endfor
  if bold
    let ret[-1] = ret[-1].'**'
  endif
  if italic
    let ret[-1] = ret[-1].'*'
  endif
  return ret
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

  let comments = s:loadPart(b:fn, 'word/comments.xml')
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
        \ 'mc:Ignorable': "w14 w15 w16se w16 cid w16 w16cex w16sdtdh w16sdtfl w16du wp14"}, 'children': []}

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
      let comment = s:writeParagraph(comment, para)
    endfor
    if s:isEmptyParagraph(comment)
      unlet comment['children'][-1]
    endif
    let comments['children'] = comments['children'] + [comment]
    let line = line2 + 1
  endwhile
  call s:writePart(b:fn, 'comments', comments)
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
    for line in s:readParagraph(node)
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
        let runs = runs + [{'start': bob + 0}]
      endif
    endfor
    let runs[-1]['end'] = len(a:text)
    return runs
endf
