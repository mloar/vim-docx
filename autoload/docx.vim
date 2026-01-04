fun! s:loadPart(fn, part)
  return json_decode(system('unzip -p '.shellescape(a:fn).' '.shellescape(a:part).' | xsltproc xml-to-json.xsl - | sed -z "s/\n/\\n/g;s/‽/\\\\\"/g"'))
endf

fun! docx#Load()
  let b:fn = expand("%:p")

  setlocal undolevels=-1 noswapfile
  call docx#Read() | $d | 0d
  sil exe 'keepalt file '.fnameescape(b:fn)

  let insertions =  matchbufline("%", '‼\(\d\+\)‼\(\_.\{-}\)‼\1\+‼', 1, "$", {"submatches": v:true})
  if len(insertions) > 0
    call prop_type_add('insertion', {'highlight': 'DiffAdd'})
    for ins in insertions
      call prop_add(ins['lnum'], ins['byteidx'] + 7 + len(ins['submatches'][0]), {'length': len(ins['submatches'][1]), 'type': 'insertion', 'id': ins['submatches'][0]})
    endfor
    %s/‼\d\+‼//g
  endif
  let deletions =  matchbufline("%", '‽\(\d\+\)‽\(\_.\{-}\)‽\1\+‽', 1, "$", {"submatches": v:true})
  if len(deletions) > 0
    call prop_type_add('deletion', {'highlight': 'DiffDelete'})
    for rm in deletions
      call prop_add(rm['lnum'], rm['byteidx'] + 7 + len(rm['submatches'][0]), {'length': len(rm['submatches'][1]), 'type': 'deletion', 'id': rm['submatches'][0]})
    endfor
    %s/‽\d\+‽//g
  endif
  let comments =  matchbufline("%", '‾\(\d\+\)‾\(\_.\{-}\)‾\1\+‾', 1, "$", {"submatches": v:true})
  if len(comments) > 0
    call prop_type_add('comment', {'highlight': 'Underlined'})
    for comment in comments
      call prop_add(comment['lnum'], comment['byteidx'] + 7 + len(comment['submatches'][0]), {'length': len(comment['submatches'][1]), 'type': 'comment', 'id': comment['submatches'][0]})
    endfor
    %s/‾\d\+‾//g
  endif

  let bufnr = bufadd('Styles')
  call setbufvar(bufnr, 'fn', b:fn)
  call setbufvar(bufnr, 'bufnr', bufnr)
  exe 'au BufReadCmd <buffer='.bufnr.'> call s:loadStyles()'
  let bufnr = bufadd('Comments')
  call setbufvar(bufnr, 'fn', b:fn)
  call setbufvar(bufnr, 'bufnr', bufnr)
  exe 'au BufReadCmd <buffer='.bufnr.'> call s:loadComments()'

  au BufReadCmd <buffer> call docx#Read()
  au BufWriteCmd <buffer> call docx#Write()
  setlocal nomod buftype=acwrite undolevels=-123456
  run! syntax/markdown.vim

  normal gg
endf

fun! docx#Read()
  let docx_document = s:loadPart(b:fn, 'word/document.xml')
  for node in filter(docx_document['children'][0]['children'], "v:val['tag'] == 'w:p'")
    call s:doParagraph(node)
  endfor
endfun

fun! docx#Write()
  let curdir= getcwd()
  let tmpdir= tempname()
  if tmpdir =~ '\.'
   let tmpdir= substitute(tmpdir,'\.[^.]*$','','e')
  endif
  call mkdir(tmpdir.'/word','p')

  exe 'balt '.tmpdir.'/word/document.xml'
  exe bufload('#')
  exe setbufline('#', 1, '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
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
        \ }, 'children': [
        \ {'tag': 'w:body', 'attributes': {}, 'children': []}
        \ ]}
  let body = document['children'][0]
  for line in range(1,line('$'))
    let text = getline(line)
    if match(text, '##### ') == 0
      if !s:isEmptyParagraph(body)
        let body['children'] = body['children'] + [s:makeParagraph()]
      endif
      let body['children'][-1]['children'][0]['children'] = [
            \ {'tag': 'w:pStyle', 'attributes': {'w:val': 'Heading5'}, 'children': []}
            \ ]
      let text = text[6:]
    elseif match(text, '#### ') == 0
      if !s:isEmptyParagraph(body)
        let body['children'] = body['children'] + [s:makeParagraph()]
      endif
      let body['children'][-1]['children'][0]['children'] = [
            \ {'tag': 'w:pStyle', 'attributes': {'w:val': 'Heading4'}, 'children': []}
            \ ]
      let text = text[5:]
    elseif match(text, '### ') == 0
      if !s:isEmptyParagraph(body)
        let body['children'] = body['children'] + [s:makeParagraph()]
      endif
      let body['children'][-1]['children'][0]['children'] = [
            \ {'tag': 'w:pStyle', 'attributes': {'w:val': 'Heading3'}, 'children': []}
            \ ]
      let text = text[4:]
    elseif match(text, '## ') == 0
      if !s:isEmptyParagraph(body)
        let body['children'] = body['children'] + [s:makeParagraph()]
      endif
      let body['children'][-1]['children'][0]['children'] = [
            \ {'tag': 'w:pStyle', 'attributes': {'w:val': 'Heading2'}, 'children': []}
            \ ]
      let text = text[3:]
    elseif match(text, '# ') == 0
      if !s:isEmptyParagraph(body)
        let body['children'] = body['children'] + [s:makeParagraph()]
      endif
      let body['children'][-1]['children'][0]['children'] = [
            \ {'tag': 'w:pStyle', 'attributes': {'w:val': 'Heading1'}, 'children': []}
            \ ]
      let text = text[2:]
    elseif match(text, '* ') == 0
      if !s:isEmptyParagraph(body)
        let body['children'] = body['children'] + [s:makeParagraph()]
      endif
      let body['children'][-1]['children'][0]['children'] = [
            \ {'tag': 'w:pStyle', 'attributes': {'w:val': 'ListParagraph'}, 'children': []}
            \ ]
      let text = text[2:]
    endif
    if text == ''
      let body['children'] = body['children'] + [s:makeParagraph()]
    else
      let last_pos = 0
      let matches =  matchbufline('%', '\*\*\?\*\?\([^*]\{-1,}\)\*\*\?\*\?', line, line, {'submatches': v:true})
      if len(matches) > 0
        for thing in matches
          if last_pos < thing['byteidx']
            let body['children'][-1]['children'] = body['children'][-1]['children'] + [
                  \ {'tag': 'w:r', 'attributes': {}, 'children': [
                  \ {'tag': 'w:t', 'attributes': {'xml:space': 'preserve'}, 'innerText': getline(line)[last_pos:thing['byteidx']-1] }
                  \ ]}
                  \ ]
          endif
          let last_pos = thing['byteidx'] + len(thing['text'])
          if match(thing['text'], '\*\*\*') >= 0
            let body['children'][-1]['children'] = body['children'][-1]['children'] + [
                  \ {'tag': 'w:r', 'attributes': {}, 'children': [
                  \ {'tag': 'w:rPr', 'attributes': {}, 'children': [
                  \ {'tag': 'w:b', 'attributes': {}, 'children': [] },
                  \ {'tag': 'w:i', 'attributes': {}, 'children': [] }
                  \ ]},
                  \ {'tag': 'w:t', 'attributes': {'xml:space': 'preserve'}, 'innerText': thing['submatches'][0] },
                  \ ]}
                  \ ]
          elseif match(thing['text'], '\*\*') >= 0
            let body['children'][-1]['children'] = body['children'][-1]['children'] + [
                  \ {'tag': 'w:r', 'attributes': {}, 'children': [
                  \ {'tag': 'w:rPr', 'attributes': {}, 'children': [
                  \ {'tag': 'w:b', 'attributes': {}, 'children': [] },
                  \ ]},
                  \ {'tag': 'w:t', 'attributes': {'xml:space': 'preserve'}, 'innerText': thing['submatches'][0] },
                  \ ]}
                  \ ]
          elseif match(thing['text'], '\*') >= 0
            let body['children'][-1]['children'] = body['children'][-1]['children'] + [
                  \ {'tag': 'w:r', 'attributes': {}, 'children': [
                  \ {'tag': 'w:rPr', 'attributes': {}, 'children': [
                  \ {'tag': 'w:i', 'attributes': {}, 'children': [] },
                  \ ]},
                  \ {'tag': 'w:t', 'attributes': {'xml:space': 'preserve'}, 'innerText': thing['submatches'][0] },
                  \ ]}
                  \ ]
          endif
        endfor
        let text = text[last_pos:]
      endif
      if match(text, '  $') >= 0
        let text = substitute(text, ' *$', '', '')
        let body['children'][-1]['children'] = body['children'][-1]['children'] + [
              \ {'tag': 'w:r', 'attributes': {}, 'children': [
              \ {'tag': 'w:t', 'attributes': {'xml:space': 'preserve'}, 'innerText': text },
              \ {'tag': 'w:br', 'attributes': {}, 'children': [] }
              \ ]}
              \ ]
      elseif len(text) > 0
        let body['children'][-1]['children'] = body['children'][-1]['children'] + [
              \ {'tag': 'w:r', 'attributes': {}, 'children': [
              \ {'tag': 'w:t', 'attributes': {'xml:space': 'preserve'}, 'innerText': text }
              \ ]}
              \ ]
      endif
    endif
  endfor
  if s:isEmptyParagraph(body)
    unlet body['children'][-1]
  endif
  exe appendbufline('#', '$', s:doElement(document))

  hide b #
  sil w
  b #
  let olddir = chdir(tmpdir)
  sil exe '!zip -qf '.shellescape(expand("%:p"))
  call chdir(olddir)
  setlocal nomodified
endf

fun! s:doElement(elem)
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
    let xml = xml.s:doElement(child)
  endfor
  return xml.'</'.a:elem['tag'].'>'
endf

fun! s:makeParagraph()
  return {'tag': 'w:p', 'attributes': {}, 'children': [
        \ {'tag': 'w:pPr', 'attributes': {}, 'children': [] }
        \ ]}
endf

fun! s:isEmptyParagraph(body)
  return len(a:body['children']) > 0 && a:body['children'][-1]['tag'] == 'w:p' && len(a:body['children'][-1]['children']) == 1 && len(a:body['children'][-1]['children'][0]['children']) == 0
endf

fun! ToggleComments()
  if len(b:comment_ids) > 0
    for id in b:comment_ids
      call popup_close(id)
    endfor
  else
    let b:comment_ids = []
    for comment in b:comments
      let b:comment_ids = b:comment_ids + [popup_create(comment['submatches'][0], #{ pos: 'botleft', textprop: 'comment', textpropid: comment['submatches'][0], border: [], padding: [0,1,0,1], close: 'click'})]
        endfor
  endif
endf

fun! s:doParagraph(container)
  let start = 0
  let lines = ['']
  if a:container['children'][0]['tag'] == 'w:pPr'
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
        endif
      endif
    endfor
    let start = 1
  endif
  let lines = s:doRuns(lines, a:container['children'][start:])
  for line in lines
    call appendbufline('%', '$', line)
  endfor
  call appendbufline('%', '$', '')
endf

fun! s:doRuns(lines, container)
  let ret = a:lines
  for node in a:container
    if node['tag'] == 'w:r'
      let ret = s:doRun(ret, node)
    elseif node['tag'] == 'w:ins'
      let ret[-1] = ret[-1].'‼'.node['attributes']['w:id'].'‼'
      let ret = s:doRuns(ret, node['children'])
      let ret[-1] = ret[-1].'‼'.node['attributes']['w:id'].'‼'
    elseif node['tag'] == 'w:del'
      let ret[-1] = ret[-1].'‽'.node['attributes']['w:id'].'‽'
      let ret = s:doRuns(ret, node['children'])
      let ret[-1] = ret[-1].'‽'.node['attributes']['w:id'].'‽'
    elseif node['tag'] == 'w:commentRangeStart'
    elseif node['tag'] == 'w:commentRangeEnd'
    elseif node['tag'] == 'w:moveTo'
      let ret = s:doRuns(ret, node['children'])
    endif
  endfor
  return ret
endf

fun! s:doRun(lines, container)
  let ret = a:lines
  for t in a:container['children']
    if t['tag'] == 'w:t'
      let ret[-1] = ret[-1].t['innerText']
    elseif t['tag'] == 'w:delText'
      let ret[-1] = ret[-1].t['innerText']
    elseif t['tag'] == 'w:br'
      let ret[-1] = ret[-1].'  '
      let ret = ret + ['']
    endif
  endfor
  return ret
endf

fun! s:loadStyles()
  call setbufvar(b:bufnr, '&swapfile', 0)
  call setbufvar(b:bufnr, '&buftype', 'acwrite')
  call setbufvar(b:bufnr, '&undolevels', -1)

  let styles = s:loadPart(b:fn, 'word/styles.xml')
  call setbufline(b:bufnr, 1, 'styles:')
  for node in filter(styles['children'], "v:val['tag'] == 'w:style'")
    call s:doStyle(node, b:bufnr)
  endfor
  call setbufvar(b:bufnr, '&mod', 0)
  call setbufvar(b:bufnr, '&undolevels', -123456)
endf

fun! s:doStyle(node, bufnr)
  call appendbufline(a:bufnr, '$', '  '.a:node['attributes']['w:styleId'].':')
  call appendbufline(a:bufnr, '$', '    type: '.a:node['attributes']['w:type'])
  call appendbufline(a:bufnr, '$', '    custom: '.a:node['attributes']->get('w:customStyle'))
  for child in a:node['children']
    if has_key(child['attributes'], 'w:val')
      call appendbufline(a:bufnr, '$', '    '.child['tag'].': '.child['attributes']['w:val'])
    else
      call appendbufline(a:bufnr, '$', '    '.child['tag'].':')
      for subchild in child['children']
        if has_key(subchild['attributes'], 'w:val')
          call appendbufline(a:bufnr, '$', '      '.subchild['tag'].': '.subchild['attributes']['w:val'])
        endif
      endfor
    endif
  endfor
endf

fun! s:loadComments()
  call setbufvar(b:bufnr, '&swapfile', 0)
  call setbufvar(b:bufnr, '&buftype', 'acwrite')
  call setbufvar(b:bufnr, '&undolevels', -1)

  let comments = s:loadPart(b:fn, 'word/comments.xml')
  call setbufline(b:bufnr, 1, 'comments:')
  for node in filter(comments['children'], "v:val['tag'] == 'w:comment'")
    call s:doComment(node, b:bufnr)
  endfor
  call setbufvar(b:bufnr, '&mod', 0)
  call setbufvar(b:bufnr, '&undolevels', -123456)
endf

fun! s:doComment(node, bufnr)
endf
