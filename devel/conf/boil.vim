" Vim syntax file
" Language:     Boilerplater

" To use this file, drop it into ~/.vim/syntax/ and add the following line 
" to your vimrc file:
"
"   autocmd BufNewFile,BufRead *.bp set syntax=boil

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

command! -nargs=+ BoilHiLink hi def link <args>

" keyword definitions
syn keyword boilConstant    NULL
syn keyword boilOperator    new init
syn keyword boilType		char byte short int long float double size_t
syn keyword boilType		bool_t i8_t i16_t i32_t i64_t u8_t u16_t u32_t u64_t
syn keyword boilType		bool_t int8_t int16_t int32_t int64_t 
syn keyword boilType		uint8_t uint16_t uint32_t uint64_t
syn keyword boilType		void
syn keyword boilStorageClass inert const volatile inline final incremented decremented
syn keyword boilBoolean		true false
syn keyword boilTodo        TODO XXX FIXME
syn keyword boilClassDecl	class inert extends cnick
syn keyword boilScopeDecl	public parcel private abstract

syn match   boilAnnotation      "@[_$a-zA-Z][_$a-zA-Z0-9_]*\>"
syn match   boilVarArg		"\.\.\."

" This cluster contains all boil groups except the contained ones.
syn cluster boilTop add=boilConstant,boilOperator,boilType,boilStorageClass,boilBoolean,boilTodo,boilClassDecl,boilScopeDecl,boilAnnotation,boilVarArg

" Comments
if exists("boil_comment_strings")
  syn region  boilCommentString    contained start=+"+ end=+"+ end=+$+ end=+\*/+me=s-1,he=s-1 contains=boilCommentStar,boilSpecialChar
  syn region  boilComment2String   contained start=+"+  end=+$\|"+ contains=boilSpecialChar
  syn match   boilCommentCharacter contained "'\\[^']\{1,6\}'" contains=boilSpecialChar
  syn match   boilCommentCharacter contained "'\\''" contains=boilSpecialChar
  syn match   boilCommentCharacter contained "'[^\\]'"
  syn cluster boilCommentSpecial add=boilCommentString,boilCommentCharacter,boilNumber
  syn cluster boilCommentSpecial2 add=boilComment2String,boilCommentCharacter,boilNumber
endif
syn region  boilComment		 start="/\*"  end="\*/" contains=@boilCommentSpecial,boilTodo
syn region  boilComment		 start="?|"  end="|?" contains=@boilCommentSpecial,boilTodo
syn match   boilCommentStar      contained "^\s*\*[^/]"me=e-1
syn match   boilCommentStar      contained "^\s*\*$"
syn match   boilLineComment      "??.*" contains=@boilCommentSpecial2,boilTodo
BoilHiLink boilCommentString boilString
BoilHiLink boilComment2String boilString
BoilHiLink boilCommentCharacter boilCharacter

syn cluster boilTop add=boilComment,boilLineComment

if !exists("boil_ignore_docucomment")
  syn region  boilDocComment    start="/\*\*"  end="\*/" keepend contains=boilCommentTitle,boilDocTags,boilTodo
  syn region  boilCommentTitle  contained matchgroup=boilDocComment start="/\*\*"   matchgroup=boilCommentTitle keepend end="\.$" end="\.[ \t\r<&]"me=e-1 end="[^{]@"me=s-2,he=s-1 end="\*/"me=s-1,he=s-1 contains=@boilCommentStar,boilTodo,boilDocTags

  syn match  boilDocTags         contained "@\(param\|return\)\s\+\S\+" contains=boilDocParam
  syn match  boilDocParam        contained "\s\S\+"
  syntax case match
endif

" Strings and constants
syn match   boilSpecialError     contained "\\."
syn match   boilSpecialCharError contained "[^']"
syn match   boilSpecialChar      contained "\\\([4-9]\d\|[0-3]\d\d\|[\"\\'ntbrf]\|u\x\{4\}\)"
syn region  boilString		start=+"+ end=+"+ end=+$+ contains=boilSpecialChar,boilSpecialError
syn match   boilCharacter	 "'[^']*'" contains=boilSpecialChar,boilSpecialCharError
syn match   boilCharacter	 "'\\''" contains=boilSpecialChar
syn match   boilCharacter	 "'[^\\]'"
syn match   boilNumber		 "\<\(0[0-7]*\|0[xX]\x\+\|\d\+\)[lL]\=\>"
syn match   boilNumber		 "\(\<\d\+\.\d*\|\.\d\+\)\([eE][-+]\=\d\+\)\=[fFdD]\="
"syn match   boilNumber		 "\<\d\+[eE][-+]\=\d\+[fFdD]\=\>"
"syn match   boilNumber		 "\<\d\+\([eE][-+]\=\d\+\)\=[fFdD]\>"

syn cluster boilTop add=boilString,boilCharacter,boilNumber

if !exists("boil_minlines")
  let boil_minlines = 10
endif
exec "syn sync ccomment boilComment minlines=" . boil_minlines

" The default highlighting.
if version >= 508 || !exists("did_boil_syn_inits")
  if version < 508
    let did_boil_syn_inits = 1
  endif
  BoilHiLink boilVarArg                 Function
  BoilHiLink boilStorageClass		StorageClass
  BoilHiLink boilClassDecl		boilStorageClass
  BoilHiLink boilScopeDecl		boilStorageClass
  BoilHiLink boilBoolean		Boolean
  BoilHiLink boilSpecialError		Error
  BoilHiLink boilSpecialCharError	Error
  BoilHiLink boilString			String
  BoilHiLink boilCharacter		Character
  BoilHiLink boilSpecialChar		SpecialChar
  BoilHiLink boilNumber			Number
  BoilHiLink boilOperator		Operator
  BoilHiLink boilComment		Comment
  BoilHiLink boilDocComment		Comment
  BoilHiLink boilLineComment		Comment
  BoilHiLink boilConstant		Constant
  BoilHiLink boilTodo			Todo
  BoilHiLink boilAnnotation             PreProc

  BoilHiLink boilCommentTitle		SpecialComment
  BoilHiLink boilDocTags		Special
  BoilHiLink boilDocParam		Function
  BoilHiLink boilCommentStar		boilComment

  BoilHiLink boilType			Type

  :syntax include @cBlock syntax/c.vim
  :syntax region cRegion start="^__C__" end="^__END_C__" contains=@cBlock

endif

delcommand BoilHiLink

let b:current_syntax = "boilerplater"

