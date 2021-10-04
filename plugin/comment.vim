"#################################################################################
"
"
let s:MSWIN = has("win16") || has("win32")   || has("win64")    || has("win95")
let s:UNIX	= has("unix")  || has("macunix") || has("win32unix")
"
let s:installation					= '*undefined*'
let s:plugin_dir						= ''
"
let s:C_LocalTemplateFile		= ''
let s:C_LocalTemplateDir		= ''
let maplocalleader  = ','

if	s:MSWIN
  " ==========  MS Windows  ======================================================
	" change '\' to '/' to avoid interpretation as escape character
		" USER INSTALLATION ASSUMED
		let s:installation					= 'local'
		let s:plugin_dir  					= substitute( expand('<sfile>:p:h:h'), '\', '/', 'g' )
		let s:C_LocalTemplateFile		= s:plugin_dir.'/templates/Templates'
		let s:C_LocalTemplateDir		= fnamemodify( s:C_LocalTemplateFile, ":p:h" ).'/'
else
  " ==========  Linux/Unix  ======================================================
		let s:installation					= 'local'
		let s:plugin_dir 						= expand('<sfile>:p:h:h')
		let s:C_LocalTemplateFile		= s:plugin_dir.'/templates/Templates'
		let s:C_LocalTemplateDir		= fnamemodify( s:C_LocalTemplateFile, ":p:h" ).'/'
endif
"
"
"  Modul global variables (with default values) which can be overridden. {{{1
"
"
let s:C_FormatDate						= '%x'
let s:C_FormatTime						= '%X'
let s:C_FormatYear						= '%Y'
"
"------------------------------------------------------------------------------
"
"------------------------------------------------------------------------------
"  Control variables (not user configurable)
"------------------------------------------------------------------------------
let s:Attribute                = { 'below':'', 'above':'', 'start':'', 'append':'', 'insert':'' }
let s:C_Attribute              = {}
let s:C_FileVisited            = []
"
let s:C_MacroNameRegex         = '\([a-zA-Z][a-zA-Z0-9_]*\)'
let s:C_MacroLineRegex				 = '^\s*|'.s:C_MacroNameRegex.'|\s*=\s*\(.*\)'
let s:C_MacroCommentRegex			 = '^\$'
let s:C_ExpansionRegex				 = '|?'.s:C_MacroNameRegex.'\(:\a\)\?|'
let s:C_NonExpansionRegex			 = '|'.s:C_MacroNameRegex.'\(:\a\)\?|'
"
let s:C_TemplateNameDelimiter  = '-+_,\. '
let s:C_TemplateLineRegex			 = '^==\s*\([a-zA-Z][0-9a-zA-Z'.s:C_TemplateNameDelimiter
let s:C_TemplateLineRegex			.= ']\+\)\s*==\s*\([a-z]\+\s*==\)\?'
let s:C_TemplateIf						 = '^==\s*IF\s\+|STYLE|\s\+IS\s\+'.s:C_MacroNameRegex.'\s*=='
let s:C_TemplateEndif					 = '^==\s*ENDIF\s*=='
"
"
let s:C_ExpansionCounter       = {}
let s:C_Macro                  = {}
let s:C_ActualStyle					   = 'default'
let s:C_Template               = { 'default' : {} }
let s:C_TemplatesLoaded			   = 'no'


"
"------------------------------------------------------------------------------
"
"------------------------------------------------------------------------------
function! C_Input ( promp, text, ... )
	echohl Search																					" highlight prompt
	call inputsave()																			" preserve typeahead
	if a:0 == 0 || empty(a:1)
		let retval	=input( a:promp, a:text )
	else
		let retval	=input( a:promp, a:text, a:1 )
	endif
	call inputrestore()																		" restore typeahead
	echohl None																						" reset highlighting
	let retval  = substitute( retval, '^\s\+', "", "" )		" remove leading whitespaces
	let retval  = substitute( retval, '\s\+$', "", "" )		" remove trailing whitespaces
	return retval
endfunction    " ----------  end of function C_Input ----------
"
"
"=====================================================================================
"
"------------------------------------------------------------------------------
"  C_RereadTemplates     {{{1
"  rebuild commands and the menu from the (changed) template file
"------------------------------------------------------------------------------
function! C_RereadTemplates ( msg )
	let s:style						= 'default'
	let s:C_Template     	= { 'default' : {} }
	let s:C_FileVisited  	= []
	let	messsage					= ''
	"
        "-------------------------------------------------------------------------------
        " local installation
        "-------------------------------------------------------------------------------
        if filereadable( s:C_LocalTemplateFile )
                call C_ReadTemplates( s:C_LocalTemplateFile )
                let	messsage	= "Templates read from '".s:C_LocalTemplateFile."'"
        else
                echomsg "Local template file '".s:C_LocalTemplateFile."' not readable." 
                return
        endif
        "
	if a:msg == 'yes'
		echomsg messsage.'.'
	endif

endfunction    " ----------  end of function C_RereadTemplates  ----------
"
"------------------------------------------------------------------------------
"  C_BrowseTemplateFiles     {{{1
"------------------------------------------------------------------------------
function! C_BrowseTemplateFiles ( type )
	let	templatefile	= eval( 's:C_'.a:type.'TemplateFile' )
	let	templatedir		= eval( 's:C_'.a:type.'TemplateDir' )
	if isdirectory( templatedir )
				let	l:templatefile	= ''
				let	l:templatefile	= input("edit a template file [tab compl.]: ", templatedir, "file" )
		if !empty(l:templatefile)
			:execute "update! | split | edit ".l:templatefile
		endif
	else
		echomsg "Template directory '".templatedir."' does not exist."
	endif
endfunction    " ----------  end of function C_BrowseTemplateFiles  ----------

"------------------------------------------------------------------------------
"  C_ReadTemplates     {{{1
"  read the template file(s), build the macro and the template dictionary
"
"------------------------------------------------------------------------------
let	s:style			= 'default'

function! C_ReadTemplates ( templatefile )

  if !filereadable( a:templatefile )
    echohl WarningMsg
    echomsg "C/C++ template file '".a:templatefile."' does not exist or is not readable"
    echohl None
    return
  endif
	let	skipmacros	= 0
  let s:C_FileVisited  += [a:templatefile]

  "------------------------------------------------------------------------------
  "  read template file, start with an empty template dictionary
  "------------------------------------------------------------------------------

  let item  = ''
	let	skipline	= 0
  for line in readfile( a:templatefile )
		" if not a comment :
    if line !~ s:C_MacroCommentRegex
      "
			"-------------------------------------------------------------------------------
			" IF |STYLE| IS ...
			"-------------------------------------------------------------------------------
      "
      let string  = matchlist( line, s:C_TemplateIf )
      if !empty(string) 
				if !has_key( s:C_Template, string[1] )
					" new s:style
					let	s:style	= string[1]
					let	s:C_Template[s:style]	= {}
					continue
				endif
			endif
			"
			"-------------------------------------------------------------------------------
			" ENDIF
			"-------------------------------------------------------------------------------
      "
      let string  = matchlist( line, s:C_TemplateEndif )
      if !empty(string)
				let	s:style	= 'default'
				continue
			endif
      "
      " macros and file includes
      "
      let string  = matchlist( line, s:C_MacroLineRegex )
      if !empty(string) && skipmacros == 0
        let key = '|'.string[1].'|'
        let val = string[2]
        let val = substitute( val, '\s\+$', '', '' )
        let val = substitute( val, "[\"\']$", '', '' )
        let val = substitute( val, "^[\"\']", '', '' )
        "
        if key == '|includefile|' && count( s:C_FileVisited, val ) == 0
					let path   = fnamemodify( a:templatefile, ":p:h" )
          call C_ReadTemplates( path.'/'.val )    " recursive call
        else
          let s:C_Macro[key] = escape( val, '&' )
        endif
        continue                                            " next line
      endif
      "
      " template header
      "
      let name  = matchstr( line, s:C_TemplateLineRegex )
      "
      if !empty(name)
        let part  = split( name, '\s*==\s*')
        let item  = part[0]
        if has_key( s:C_Template[s:style], item ) && s:C_TemplateOverriddenMsg == 'yes'
          echomsg "existing C/C++ template '".item."' overwritten"
        endif
        let s:C_Template[s:style][item] = ''
				let skipmacros	= 1
        "
        let s:C_Attribute[item] = 'below'
        if has_key( s:Attribute, get( part, 1, 'NONE' ) )
          let s:C_Attribute[item] = part[1]
        endif
      else
        if !empty(item)
          let s:C_Template[s:style][item] .= line."\n"
        endif
      endif
    endif
		"
  endfor	" ---------  read line  ---------

endfunction    " ----------  end of function C_ReadTemplates  ----------

"------------------------------------------------------------------------------
"  C_InsertTemplate     {{{1
"  insert a template from the template dictionary
"  do macro expansion
"------------------------------------------------------------------------------
function! C_InsertTemplate ( key, ... )

	if s:C_TemplatesLoaded == 'no'
		call C_RereadTemplates('no')        
		let s:C_TemplatesLoaded	= 'yes'
	endif

	if !has_key( s:C_Template[s:C_ActualStyle], a:key ) &&
	\  !has_key( s:C_Template['default'], a:key )
		echomsg "style '".a:key."' / template '".a:key
	\        ."' not found. Please check your template file in '"
		return
	endif

	if &foldenable 
		let	foldmethod_save	= &foldmethod
		set foldmethod=manual
	endif

	" use internal formatting to avoid conficts when using == below
	"
	let	equalprg_save	= &equalprg
	set equalprg=

  let mode  = s:C_Attribute[a:key]

	" remove <SPLIT> and insert the complete macro
	"
	if a:0 == 0
		let val = C_ExpandUserMacros (a:key)
		if empty(val)
			return
		endif
		let val	= C_ExpandSingleMacro( val, '<SPLIT>', '' )

		if mode == 'below'
			let pos1  = line(".")+1
			put  =val
			let pos2  = line(".")
			" proper indenting
			exe ":".pos1
			let ins	= pos2-pos1+1
			exe "normal ".ins."=="
			"
		elseif mode == 'above'
			let pos1  = line(".")
			put! =val
			let pos2  = line(".")
			" proper indenting
			exe ":".pos1
			let ins	= pos2-pos1+1
			exe "normal ".ins."=="
			"
		elseif mode == 'start'
			normal gg
			let pos1  = 1
			put! =val
			let pos2  = line(".")
			" proper indenting
			exe ":".pos1
			let ins	= pos2-pos1+1
			exe "normal ".ins."=="
			"
		elseif mode == 'append'
			if &foldenable && foldclosed(".") >= 0
				echohl WarningMsg | echomsg s:MsgInsNotAvail  | echohl None
				exe "set foldmethod=".foldmethod_save
				return
			else
				let pos1  = line(".")
				put =val
				let pos2  = line(".")-1
				exe ":".pos1
				:join!
			endif
			"
		elseif mode == 'insert'
			if &foldenable && foldclosed(".") >= 0
				echohl WarningMsg | echomsg s:MsgInsNotAvail  | echohl None
				exe "set foldmethod=".foldmethod_save
				return
			else
				let val   = substitute( val, '\n$', '', '' )
				let currentline	= getline( "." )
				let pos1  = line(".")
				let pos2  = pos1 + count( split(val,'\zs'), "\n" )
				" assign to the unnamed register "" :
				exe 'normal! a'.val
				" reformat only multiline inserts and previously empty lines
				if pos2-pos1 > 0 || currentline =~ ''
					exe ":".pos1
					let ins	= pos2-pos1+1
					exe "normal ".ins."=="
				endif
			endif
			"
		endif
		"
	else
		"
		" =====  visual mode  ===============================
		"
		if  a:1 == 'v'
			let val = C_ExpandUserMacros (a:key)
			if empty(val)
				return
			endif

			if match( val, '<SPLIT>\s*\n' ) >= 0
				let part	= split( val, '<SPLIT>\s*\n' )
			else
				let part	= split( val, '<SPLIT>' )
			endif

			if len(part) < 2
				let part	= [ "" ] + part
				echomsg 'SPLIT missing in template '.a:key
			endif
			"
			" 'visual' and mode 'insert':
			"   <part0><marked area><part1>
			" part0 and part1 can consist of several lines
			"
			if mode == 'insert'
				let pos1  = line(".")
				let pos2  = pos1
			" windows: recover area of the visual mode and yank, puts the selected area in the buffer
    		normal gvy
				let string	= eval('@"')
				let replacement	= part[0].string.part[1]
				" remove trailing '\n'
				let replacement   = substitute( replacement, '\n$', '', '' )
				exe ':s/'.string.'/'.replacement.'/'
			endif
			"
			" 'visual' and mode 'below':
			"   <part0>
			"   <marked area>
			"   <part1>
			" part0 and part1 can consist of several lines
			"
			if mode == 'below'

				:'<put! =part[0]
				:'>put  =part[1]

				let pos1  = line("'<") - len(split(part[0], '\n' ))
				let pos2  = line("'>") + len(split(part[1], '\n' ))
				""			echo part[0] part[1] pos1 pos2
				"			" proper indenting
				exe ":".pos1
				let ins	= pos2-pos1+1
				exe "normal ".ins."=="
			endif
			"
		endif		" ---------- end visual mode
	endif

	" restore formatter programm
	let &equalprg	= equalprg_save

  "------------------------------------------------------------------------------
  "  position the cursor
  "------------------------------------------------------------------------------
  exe ":".pos1
  let mtch = search( '<CURSOR>\|{CURSOR}', 'c', pos2 )
	if mtch != 0
		let line	= getline(mtch)
		if line =~ '<CURSOR>$\|{CURSOR}$'
			call setline( mtch, substitute( line, '<CURSOR>\|{CURSOR}', '', '' ) )
			if  a:0 != 0 && a:1 == 'v' && getline(".") =~ '^\s*$'
				normal J
			else
				:startinsert!
			endif
		else
			call setline( mtch, substitute( line, '<CURSOR>\|{CURSOR}', '', '' ) )
			:startinsert
		endif
	else
		" to the end of the block; needed for repeated inserts
		if mode == 'below'
			exe ":".pos2
		endif
  endif
endfunction    " ----------  end of function C_InsertTemplate  ----------


"------------------------------------------------------------------------------
"  C_ExpandUserMacros     {{{1
"------------------------------------------------------------------------------
function! C_ExpandUserMacros ( key )

	if has_key( s:C_Template[s:C_ActualStyle], a:key )
		let template 								= s:C_Template[s:C_ActualStyle][ a:key ]
	else
		let template 								= s:C_Template['default'][ a:key ]
	endif
	let	s:C_ExpansionCounter		= {}										" reset the expansion counter

  "------------------------------------------------------------------------------
  "  look for replacements
  "------------------------------------------------------------------------------
	while match( template, s:C_ExpansionRegex ) != -1
		let macro				= matchstr( template, s:C_ExpansionRegex )
		let replacement	= substitute( macro, '?', '', '' )
		let template		= substitute( template, macro, replacement, "g" )

		let match	= matchlist( macro, s:C_ExpansionRegex )

		if !empty( match[1] )
			let macroname	= '|'.match[1].'|'
			"
			" notify flag action, if any
			let flagaction	= ''
			"
			" ask for a replacement
			if has_key( s:C_Macro, macroname )
				let	name	= C_Input( match[1].flagaction.' : ', s:C_Macro[macroname])
			else
				let	name	= C_Input( match[1].flagaction.' : ', '' )
			endif
			if empty(name)
				return ""
			endif
			"
			" keep the modified name
			let s:C_Macro[macroname]  			= name
		endif
	endwhile

  "------------------------------------------------------------------------------
  "  do the actual macro expansion
	"  loop over the macros found in the template
  "------------------------------------------------------------------------------
	while match( template, s:C_NonExpansionRegex ) != -1

		let macro			= matchstr( template, s:C_NonExpansionRegex )
		let match			= matchlist( macro, s:C_NonExpansionRegex )

		if !empty( match[1] )
			let macroname	= '|'.match[1].'|'

			if has_key( s:C_Macro, macroname )
				"-------------------------------------------------------------------------------
				"   check for recursion
				"-------------------------------------------------------------------------------
				if has_key( s:C_ExpansionCounter, macroname )
					let	s:C_ExpansionCounter[macroname]	+= 1
				else
					let	s:C_ExpansionCounter[macroname]	= 0
				endif
				"-------------------------------------------------------------------------------
				"   replace
				"-------------------------------------------------------------------------------
				let replacement = s:C_Macro[macroname]
				let replacement = escape( replacement, '&' )
				let template 		= substitute( template, macro, replacement, "g" )
			else
				"
				" macro not yet defined
				let s:C_Macro['|'.match[1].'|']  		= ''
			endif
		endif

	endwhile

  return template
endfunction    " ----------  end of function C_ExpandUserMacros  ----------

"
"------------------------------------------------------------------------------
"  C_ExpandSingleMacro     {{{1
"------------------------------------------------------------------------------
function! C_ExpandSingleMacro ( val, macroname, replacement )
  return substitute( a:val, escape(a:macroname, '$' ), a:replacement, "g" )
endfunction    " ----------  end of function C_ExpandSingleMacro  ----------

"------------------------------------------------------------------------------
"  insert date and time     {{{1
"------------------------------------------------------------------------------
function! C_InsertDateAndTime ( format )
	if &foldenable && foldclosed(".") >= 0
		echohl WarningMsg | echomsg s:MsgInsNotAvail  | echohl None
		return ""
	endif
	if col(".") > 1
		exe 'normal a'.C_DateAndTime(a:format)
	else
		exe 'normal i'.C_DateAndTime(a:format)
	endif
endfunction    " ----------  end of function C_InsertDateAndTime  ----------

"------------------------------------------------------------------------------
"  generate date and time     {{{1
"------------------------------------------------------------------------------
function! C_DateAndTime ( format )
	if a:format == 'd'
		return strftime( s:C_FormatDate )
	elseif a:format == 't'
		return strftime( s:C_FormatTime )
	elseif a:format == 'dt'
		return strftime( s:C_FormatDate ).' '.strftime( s:C_FormatTime )
	elseif a:format == 'y'
		return strftime( s:C_FormatYear )
	endif
endfunction    " ----------  end of function C_DateAndTime  ----------


let s:C_Macro['|BASENAME|']	= toupper(expand("%:t:r"))
let s:C_Macro['|DATE|']  		= C_DateAndTime('d')
let s:C_Macro['|FILENAME|'] = expand("%:t")
let s:C_Macro['|PATH|']  		= expand("%:p:h")
let s:C_Macro['|SUFFIX|'] 	= expand("%:e")
let s:C_Macro['|TIME|']  		= C_DateAndTime('t')
let s:C_Macro['|YEAR|']  		= C_DateAndTime('y')

"===  FUNCTION  ================================================================
"          NAME:  CreateAdditionalMaps     {{{1
"   DESCRIPTION:  create additional maps
"    PARAMETERS:  -
"       RETURNS:  
"===============================================================================
	"
	"
	noremap    <buffer>  <silent>  <LocalLeader>cfr        :call C_InsertTemplate("comment.frame")<CR>
	noremap    <buffer>  <silent>  <LocalLeader>cfu        :call C_InsertTemplate("comment.function")<CR>
	noremap    <buffer>  <silent>  <LocalLeader>cfe        :call C_InsertTemplate("comment.method")<CR>
	noremap    <buffer>  <silent>  <LocalLeader>cfc        :call C_InsertTemplate("comment.class")<CR>
	noremap    <buffer>  <silent>  <LocalLeader>cfm        :call C_InsertTemplate("comment.modify")<CR>
	noremap    <buffer>  <silent>  <LocalLeader>cfi        :call C_InsertTemplate("comment.file-description")<CR>
	noremap    <buffer>  <silent>  <LocalLeader>cfh        :call C_InsertTemplate("comment.file-description-header")<CR>

	inoremap   <buffer>  <silent>  <LocalLeader>cfr   <Esc>:call C_InsertTemplate("comment.frame")<CR>
	inoremap   <buffer>  <silent>  <LocalLeader>cfu   <Esc>:call C_InsertTemplate("comment.function")<CR>
	inoremap   <buffer>  <silent>  <LocalLeader>cfe   <Esc>:call C_InsertTemplate("comment.method")<CR>
	inoremap   <buffer>  <silent>  <LocalLeader>cfc   <Esc>:call C_InsertTemplate("comment.class")<CR>
	inoremap   <buffer>  <silent>  <LocalLeader>cfm   <Esc>:call C_InsertTemplate("comment.modify")<CR>
	inoremap   <buffer>  <silent>  <LocalLeader>cfi   <Esc>:call C_InsertTemplate("comment.file-description")<CR>
	inoremap   <buffer>  <silent>  <LocalLeader>cfh   <Esc>:call C_InsertTemplate("comment.file-description-header")<CR>

	noremap    <buffer>  <silent>  <LocalLeader>cd    <Esc>:call C_InsertDateAndTime('d')<CR>
	inoremap   <buffer>  <silent>  <LocalLeader>cd    <Esc>:call C_InsertDateAndTime('d')<CR>a
	vnoremap   <buffer>  <silent>  <LocalLeader>cd   s<Esc>:call C_InsertDateAndTime('d')<CR>a
	noremap    <buffer>  <silent>  <LocalLeader>ct    <Esc>:call C_InsertDateAndTime('dt')<CR>
	inoremap   <buffer>  <silent>  <LocalLeader>ct    <Esc>:call C_InsertDateAndTime('dt')<CR>a
	vnoremap   <buffer>  <silent>  <LocalLeader>ct   s<Esc>:call C_InsertDateAndTime('dt')<CR>a
	" 

"=====================================================================================
" vim: tabstop=2 shiftwidth=2 foldmethod=marker
