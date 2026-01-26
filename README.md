# vim-docx
Vim plugin for editing Word documents

## Requirements
* Vim 7.2 or later
* zip/unzip
* xsltproc, part of libxslt

## Install
Use your favorite Vim plugin manager, e.g., [vim-plug](https://github.com/junegunn/vim-plug):

    call plug#begin('~/.vim/plugged')
    Plug 'mloar/vim-docx', { 'branch': 'main' }
    call plug#end()

**Important:** You need to remove .docx from the list of extensions handled by the zip plugin. In your `.vimrc`:

    let g:zipPlugin_ext= '*.zip,*.jar,*.xpi,*.ja,*.war,*.ear,*.celzip,
           \ *.oxt,*.kmz,*.wsz,*.xap,*.potx,*.potm,
           \ *.ppsx,*.ppsm,*.pptx,*.pptm,*.ppam,*.sldx,*.thmx,*.xlam,*.xlsx,*.xlsm,
           \ *.xlsb,*.xltx,*.xltm,*.xlam,*.crtx,*.vdw,*.glox,*.gcsx,*.gqsx,*.epub'

Also set these for revisions/comments:

    let g:docx_author='Matt Loar'
    let g:docx_initials='ML'
