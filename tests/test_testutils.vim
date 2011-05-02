" Tests for testutils.vim
" Author: Ted Tibbetts
" License: Licensed under the same terms as Vim itself.
UTSuite Tests for the testutils addon.

function! s:TestDirectoryStructure()
  let dirs = {
        \ '2linefile': ['line1', 'line2'],
        \ 'emptydir': {},
        \ 'dir_with_subdirs': {
        \   'subdirwithfile': {
        \     '3linefile': ['line1', 'line2', 'line3'] },
        \   'emptysubdir': {},
        \   '4linefile': ['line1', 'line2', 'line3', 'line4'] },
        \ 'emptyfile': [] }

  let testdir = tempname()
  call mkdir(testdir)
  try
    let original_dir = getcwd()
    try
      exec 'cd' fnameescape(testdir)
      Assert! testdir == getcwd()
      call testutils#CreateDirectoryStructure(dirs)
      try
        Assert! readfile(g:path#path.Join(['dir_with_subdirs', '4linefile']))
              \ == dirs.dir_with_subdirs['4linefile']
        Assert! readfile('emptyfile') == []
        Assert! testutils#ReadDirectoryStructure() == dirs
      finally
        call testutils#RemoveDirectoryStructure(dirs)
      endtry
      Assert glob(g:path#path.Join([testdir, '*'])) == 0
    finally
      exec 'cd' fnameescape(original_dir)
    endtry
  finally
    call g:path#path.Rmdir(testdir)
  endtry
endfunction

" Functions to be used as test fodder by s:TestRaises().
function! s:ThrowTestError()
  throw 'TestError'
endfunction
function! s:Noop()
endfunction

let s:dict = {}
function! s:dict.ThrowTestError()
  throw 'TestError'
endfunction
function! s:dict.Noop()
endfunction

function! s:TestRaises()
  let Raises = function('testutils#Raises')

  Assert Raises('TestError', s:SFunction('ThrowTestError'))
  Assert Raises('^TestError', s:SFunction('ThrowTestError'))
  Assert Raises('^.\{4}Error', s:SFunction('ThrowTestError'))
  Assert Raises('Error$', s:SFunction('ThrowTestError'))
  Assert Raises('^TestError$', s:SFunction('ThrowTestError'))
  Assert Raises('^T.*', s:SFunction('ThrowTestError'))
  Assert !Raises('FAIL', s:SFunction('ThrowTestError'))
  Assert !Raises('TestError', s:SFunction('Noop'))
  Assert Raises('TestError', s:dict.ThrowTestError, [], s:dict)
  Assert Raises('TestError', s:dict.ThrowTestError, [])
  Assert !Raises('TestError', s:dict.Noop, [], s:dict)
  Assert !Raises('TestError', s:dict.Noop, [])
  Assert Raises('^Vim\%((\a\+)\)\=:E745', function('nr2char'), [[]])
endfunction


" Functions needed by TestRaises()
  " Acquired from |<SNR>|.
  function! s:SID()
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
  endfun

  " Get a globally-usable reference to a script function.
  " This can be called from within an external callback.
  " TODO: See if this can be defined in testutils#
  "       and declared with a command in test scripts that need it.
  function! s:SFunction(funcname)
    return function('<SNR>' . s:SID() . '_' . a:funcname)
  endfunction
