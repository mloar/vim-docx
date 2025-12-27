au BufReadCmd *.docx setf docx
au FileReadCmd *.docx call docx#Read(expand("<amatch>"))
