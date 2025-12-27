if exists("b:docx_loaded")
  finish
endif
let b:docx_loaded = 1

call docx#Load()
