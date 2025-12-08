" Vim syntax file
" Language: T-Ruby (Typed Ruby)
" Maintainer: T-Ruby Team
" Latest Revision: 2024

if exists("b:current_syntax")
  finish
endif

" Include Ruby syntax as base
runtime! syntax/ruby.vim
unlet b:current_syntax

" T-Ruby specific keywords
syn keyword tRubyKeyword type interface contained
syn keyword tRubyBuiltinType String Integer Boolean Array Hash Symbol void nil contained

" Type alias definition: type AliasName = TypeDefinition
syn match tRubyTypeAlias "^\s*type\s\+\w\+" contains=tRubyKeyword,tRubyTypeName
syn match tRubyTypeName "\<[A-Z]\w*\>" contained

" Interface definition
syn region tRubyInterface start="^\s*interface\s\+\w\+" end="^\s*end\>" contains=tRubyKeyword,tRubyTypeName,tRubyInterfaceMember,rubyComment fold
syn match tRubyInterfaceMember "^\s*\w\+\s*:\s*.*$" contained contains=tRubyBuiltinType,tRubyTypeName,tRubyTypeOperator

" Type annotations in function definitions
syn match tRubyTypeAnnotation ":\s*[A-Z]\w*\(<[^>]*>\)\?" contained contains=tRubyBuiltinType,tRubyTypeName,tRubyGenericType
syn match tRubyReturnType "):\s*[A-Z]\w*\(<[^>]*>\)\?" contains=tRubyBuiltinType,tRubyTypeName,tRubyGenericType

" Generic types: Array<String>, Map<K, V>
syn match tRubyGenericType "\<[A-Z]\w*<[^>]*>" contains=tRubyBuiltinType,tRubyTypeName

" Union types: String | Integer
syn match tRubyTypeOperator "|" contained
syn match tRubyTypeOperator "&" contained

" Parameter type annotations
syn match tRubyParamType "\w\+\s*:\s*[A-Z][^,)]*" contained contains=tRubyBuiltinType,tRubyTypeName,tRubyTypeOperator

" Highlighting
hi def link tRubyKeyword Keyword
hi def link tRubyBuiltinType Type
hi def link tRubyTypeName Type
hi def link tRubyTypeAlias Statement
hi def link tRubyInterface Structure
hi def link tRubyInterfaceMember Identifier
hi def link tRubyTypeAnnotation Type
hi def link tRubyReturnType Type
hi def link tRubyGenericType Type
hi def link tRubyTypeOperator Operator
hi def link tRubyParamType Type

let b:current_syntax = "truby"
