" testutils.vim
" Author: Ted Tibbetts
" License: Licensed under the same terms as Vim itself.
" Various utilities to facilitate unit and functional testing.

" a:spec is a Dictionary.  Its values can be either Lists or Dictionaries.
"   Lists are taken to be the contents of a file with the name of the key.
"   Dictionaries are taken to be subdirectories.
" The root directory can be passed as the second parameter.
"   If a root directory is not passed, the current directory is used.
function! testutils#CreateDirectoryStructure(spec, ...) abort
  let dirname = a:0 ? a:1 : getcwd()

  for basename in keys(a:spec)
    if len(g:path#path.Split('a' . basename . 'a')) > 1
      throw printf('FileError: path %s contains directory separator.',
            \      string(basename))
    endif

    if basename == '.' || basename == '..'
      throw printf("FileError: Cannot use '.' or '..' as file names.")
    endif

    if basename == ''
      throw printf("FileError: Cannot use empty file name.")
    endif

    let fullpath = g:path#path.Join([dirname, basename])
    let contents = a:spec[basename]

    if type(contents) == type([])
      call writefile(contents, fullpath)
    elseif type(contents) == type({})
      call mkdir(fullpath)
      call testutils#CreateDirectoryStructure(contents, fullpath)
    else
      throw printf('TypeError: Wrong type for {%s: %s}.',
            \      string(basename), string(value))
    endif

    unlet contents
  endfor
endfunction

" Traverses a directory's contents.
" Removes any files and directories which match the contents of a:spec.
" a:spec is a nested Dictionary structure;
"   see testutils#CreateDirectoryStructure for details.
" The root directory can be passed as the second parameter.
"   If a root directory is not passed, the current directory is used.
" May not work on exotic OSs.
" Should work under Windows and POSIX-ish systems.
" Will not remove unreadable non-directory files (throws FileError).
function! testutils#RemoveDirectoryStructure(spec, ...) abort
  let dirname = a:0 ? a:1 : getcwd()

  for basename in keys(a:spec)
    call g:path#path.ValidateFilename(basename)

    let fullpath = g:path#path.Join([dirname, basename])
    let contents = a:spec[basename]

    if type(contents) == type([])
      call delete(fullpath)
    elseif type(contents) == type({})
      call testutils#RemoveDirectoryStructure(contents, fullpath)
      call g:path#path.Rmdir(fullpath)
    else
      throw printf('TypeError: Wrong type for {%s: %s}',
            \      string(basename), string(value))
    endif

    unlet contents
  endfor
endfunction

" Recursively deserialize the contents of the current directory
" to a Dictionary like the one passed to CreateDirectoryStructure.
" Ignores any files not matched by `glob('*')`.
" TODO: Read all files except `.` and `..`.  Currently dot-files are ignored.
function! testutils#ReadDirectoryStructure(...)
  let dirname = a:0 ? a:1 : getcwd()
  let ret = {}

  for fullpath in split(glob(g:path#path.Join([dirname, '*'])), "\n")
    let basename = g:path#path.Split(fullpath)[-1]

    if isdirectory(fullpath)
      let ret[basename] = testutils#ReadDirectoryStructure(fullpath)
    elseif filereadable(fullpath)
      let ret[basename] = readfile(fullpath)
    else
      throw printf('FileError: found non-readable non-directory file %s.',
            \      string(file))
    endif
  endfor

  return ret
endfunction


" Returns true if the function call generates an exception
" matching a:exception_re.
" A List of arguments can be supplied; it defaults to [].
" A Dictionary can also be supplied; this defaults to {}.
" The function is invoked using |call()|,
" passing the arguments and dictionary.
" Using script-scoped functions (s:*) seems to require
" that a Funcref with the form '<SNR>\d\+_\w\+' be used.
" The author gathers that this is because
" Funcrefs are actually stored as Strings.
" See the testutils test suite for an example of how to do this.
function! testutils#Raises(exception_re, function, ...)
  let args = a:0 ? a:1 : []
  let dict = a:0 > 1 ? a:2 : {}
  let caught = 0

  try
    call call(a:function, args, dict)
  catch
    let caught = (match(v:exception, a:exception_re) != -1)
  endtry

  return caught
endfunction
