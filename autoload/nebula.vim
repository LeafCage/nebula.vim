if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:optiongetter = {}
function! s:new_optiongetter(elements)
  let optiongetter = copy(s:optiongetter)
  call extend(optiongetter, a:elements)
  return optiongetter
endfunction
function! s:optiongetter.get_augroup() "{{{
  let aucmd_vimenter = filter(self.autocmds, 'match(v:val.events, "^VimEnter$\\|^GUIEnter$")!=-1')
  if aucmd_vimenter==[]
    return {}
  endif
  return {'augroup': aucmd_vimenter[0].group}
endfunction
"}}}
function! s:optiongetter.get_unitesources() "{{{
  if self.unitesources==[]
    return {}
  endif
  return {'unite_sources': self.unitesources}
endfunction
"}}}
function! s:optiongetter.get_commands() "{{{
  if self.commands=={}
    return {}
  endif
  let commands = []
  for cmdname in keys(self.commands)
    if self.commands[cmdname].complete==''
      call add(commands, cmdname)
    else
      call add(commands, {'name': cmdname, 'complete': self.commands[cmdname].complete})
    endif
  endfor
  return {'commands': commands}
endfunction
"}}}
function! s:optiongetter.get_mappings(bundle) "{{{
  let textobjmappings = s:_fetch_textobj_mappings(a:bundle.path)
  if self.globalkeymappings=={} && textobjmappings==[]
    return {}
  endif
  let plugmappings = filter(keys(self.globalkeymappings), 'v:val=~"<Plug>"')
  let plugmapping_prefix = s:_get_plugmapping_prefix(plugmappings)
  let mappings = []
  let enable_modes = {'n':0, 'o':0, 'x':0, 'i':0, 'c':0, 's':0}
  for mapping in plugmappings
    let modes = filter(keys(self.globalkeymappings[mapping]), 'v:val!="common"')
    for m in modes
      let enable_modes[m] = 1
    endfor
    if match(modes, 'i\|c\|s') == -1
      call add(mappings, mapping)
    else
      call add(mappings, [join(modes, ''), mapping])
    endif
  endfor
  if plugmapping_prefix!=''
    let short_mapping = [join(keys(filter(enable_modes, 'v:val')), ''), plugmapping_prefix]
    return {'mappings': extend([short_mapping], textobjmappings, 0)}
  endif
  call extend(mappings, textobjmappings)
  return mappings==[] ? {} : {'mappings': mappings}
endfunction
"}}}
function! s:optiongetter.get_filetype() "{{{
  let aucmd_filetype = filter(self.autocmds, 'index(v:val.patterns, "FileType")!=-1')
  if aucmd_filetype==[]
    return {}
  endif
  return {'filetypes': aucmd_filetype[0].patterns}
endfunction
"}}}

"=============================================================================
"Main
function! nebula#put_lazy() "{{{
  let bundle = nebula#_get_bundle()
  if bundle == {}
    return {}
  endif
  let [nb_options, elements] = nebula#_fetch_options(bundle)
  let orig_name = bundle.orig_name
  let line = printf('NeoBundleLazy ''%s'', %s', orig_name, string(nb_options))
  call append('.', line)
  norm! +
  return elements
endfunction
"}}}
function! nebula#put_config(do_addlazy) "{{{
  let bundle = nebula#_get_bundle()
  if bundle == {}
    return {}
  endif
  let [nb_options, elements] = nebula#_fetch_options(bundle)
  if a:do_addlazy
    let nb_options.lazy = 1
  endif
  let line = printf('call neobundle#config(''%s'', %s)', bundle.name, string(nb_options))
  call append('.', line)
  norm! +
  return elements
endfunction
"}}}
function! nebula#yank_config(do_addlazy) "{{{
  let bundle = nebula#_get_bundle()
  if bundle == {}
    return {}
  endif
  let [nb_options, elements] = nebula#_fetch_options(bundle)
  if a:do_addlazy
    let nb_options.lazy = 1
  endif
  let line = printf('call neobundle#config(''%s'', %s)', bundle.name, string(nb_options))
  call setreg('"', line, 'V')
  ec 'Yanked : '. @"
  return elements
endfunction
"}}}
function! nebula#yank_options(do_addlazy) "{{{
  let bundle = nebula#_get_bundle()
  if bundle == {}
    return {}
  endif
  let [nb_options, elements] = nebula#_fetch_options(bundle)
  if a:do_addlazy
    let nb_options.lazy = 1
  endif
  let @" = string(nb_options)
  ec 'Yanked : '. @"
  return elements
endfunction
"}}}
function! nebula#put_from_clipboard() "{{{
  let line = printf('NeoBundle ''%s''', substitute(@+, '\_s', '', 'g'))
  call append('.', line)
  norm! +
endfunction
"}}}
function! nebula#yank_tap(append_folding, bundlename) "{{{
  if a:bundlename==''
    let bundle = nebula#_get_bundle()
    if bundle == {}
      return {}
    endif
    let bundlename = bundle.name
  else
    let bundlename = a:bundlename
  end
  let str = a:append_folding ? "if neobundle#tap('". bundlename. "') \"{{{\nendif\n\"}}}"
    \ : "if neobundle#tap('". bundlename. "')\nendif"
  call setreg('"', str, 'V')
  ec 'Yanked : '. strtrans(@")
endfunction
"}}}

function! nebula#_fetch_options(...) "{{{
  let bundle = a:0 ? a:1 : nebula#_get_bundle()
  if bundle == {}
    return {}
  endif
  let rootpath = bundle.path
  let elements = lib#vimelements#collect(rootpath, ['commands', 'keymappings', 'autocmds', 'unitesources'])
  let optiongetter = s:new_optiongetter(elements.elements)
  let nb_options = {}
  call extend(nb_options, optiongetter.get_augroup())
  let nb_options.autoload = {}
  call extend(nb_options.autoload, optiongetter.get_unitesources())
  call extend(nb_options.autoload, optiongetter.get_commands())
  call extend(nb_options.autoload, optiongetter.get_mappings(bundle))
  "call extend(nb_options.autoload, optiongetter.get_filetypes())
  if nb_options.autoload=={}
    unlet nb_options.autoload
  endif
  return [nb_options, elements]
endfunction
"}}}
function! nebula#_get_bundle() "{{{
  let bundlename = s:_get_bundlename()
  if !exists('*neobundle#get')
    echohl WarningMsg| echo 'neobundleが利用できません。'| echohl NONE
    return {}
  endif
  let bundle = neobundle#get(bundlename)
  if bundle =={}
    echohl WarningMsg| echo 'その名前のbundleは見つかりませんでした。'| echohl NONE
    return {}
  endif
  return bundle
endfunction
"}}}


"=============================================================================
"main
function! s:_get_bundlename() "{{{
  let origname = matchstr(getline('.'), 'NeoBundle\%(Lazy\)\?\s\+[''"]\zs\S\+\ze[''"]')
  let bundlename = fnamemodify(origname, ':t:s?\.git$??')
  return bundlename
endfunction
"}}}
"======================================
"optiongetter
"get_mappings()
function! s:_get_plugmapping_prefix(plugmappings) "{{{
  let THRESHOLD = 7
  let len = len(a:plugmappings)
  if len < 2
    return get(a:plugmappings, 0, '')
  endif
  let pat = a:plugmappings[1]
  let strlen = strlen(pat)
  let j = strlen/2
  let result = match(a:plugmappings[0], pat[:j])
  if result==-1
    while match(a:plugmappings[0], pat[:j])==-1 && j > THRESHOLD
      let j -= 1
    endwhile
  else
    while match(a:plugmappings[0], pat[:j])!=-1 && j < strlen-1
      let j += 1
    endwhile
    let j-=1
  endif
  if j <= THRESHOLD
    return ''
  endif
  let i = 1
  while i < len-1
    while match(a:plugmappings[i], a:plugmappings[i+1][:j])==-1 && j > THRESHOLD
      let j -= 1
    endwhile
    let i+=1
  endwhile
  return j<=THRESHOLD ? '' : a:plugmappings[0][:j]
endfunction
"}}}
function! s:_fetch_textobj_mappings(rootpath) "{{{
  let textobjpath = globpath(a:rootpath, '*/textobj/*.vim')
  let operatorpath = globpath(a:rootpath, '*/operator/*.vim')
  if textobjpath=='' && operatorpath==''
    return []
  endif
  let ret = []
  for path in split(textobjpath, '\n')
    let lines = readfile(path)
    let idx = match(lines, 'call\s\+textobj#user#plugin(')
    let objname = matchstr(lines[idx], 'textobj#user#plugin(\s*["'']\zs\a\+')
    if objname==''
      continue
    endif
    call add(ret, ['xo', '<Plug>(textobj-'. objname])
  endfor
  for path in split(operatorpath, '\n')
    let lines = readfile(path)
    let idx = match(lines, 'call\s\+operator#user#define')
    let objname = matchstr(lines[idx], 'operator#user#define\%(_ex_command\)\?(\s*["'']\zs\a\+')
    if objname==''
      continue
    endif
    call add(ret, ['nx', '<Plug>(operator-'. objname])
  endfor
  return ret
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
