%% ``The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved via the world wide web at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% The Initial Developer of the Original Code is Ericsson Utvecklings AB.
%% Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
%% AB. All Rights Reserved.''
%% 
%%     $Id $
%%
-module(erl_pp).

%%% Pretty printer for Erlang code in the same format as returned from
%%% the parser. It does not always produce pretty code.

-export([form/1,form/2,
	 attribute/1,attribute/2,function/1,function/2,rule/1,rule/2,
	 guard/1,guard/2,exprs/1,exprs/2,exprs/3,expr/1,expr/2,expr/3,expr/4]).

%% The following exports are here for backwards compatibility.
-export([seq/1,seq/2]).
-deprecated([{seq,1},{seq,2}]).

-import(lists, [append/1,foldr/3,map/2,mapfoldl/3,reverse/1,reverse/2]).
-import(io_lib, [write/1,format/2,write_char/1,write_string/1]).
-import(erl_parse, [inop_prec/1,preop_prec/1,func_prec/0,max_prec/0]).

-define(MAXLINE, 72).

%%%
%%% Exported functions
%%%

seq(Es) ->
    exprs(Es).

seq(Es, Hook) ->
    exprs(Es, Hook).

form(Thing) ->
    form(Thing, none).

form(Thing, Hook) ->
    frmt(lform(Thing, Hook)).

attribute(Thing) ->
    attribute(Thing, none).

attribute(Thing, Hook) ->
    frmt(lattribute(Thing, Hook)).

function(F) ->
    function(F, none).

function(F, Hook) ->
    frmt(lfunction(F, Hook)).

rule(R) ->
    rule(R, none).

rule(R, Hook) ->
    frmt(lrule(R, Hook)).

guard(Gs) ->
    guard(Gs, none).

guard(Gs, Hook) ->
    frmt(lguard(Gs, Hook)).

exprs(Es) ->
    exprs(Es, 0, none).

exprs(Es, Hook) ->
    exprs(Es, 0, Hook).

exprs(Es, I, Hook) ->
    map(fun(Item) -> frmt(Item, I) end, lexprs(Es, Hook)).

expr(E) ->
    frmt(lexpr(E, 0, none)).

expr(E, Hook) ->
    frmt(lexpr(E, 0, Hook)).

expr(E, I, Hook) ->
    frmt(lexpr(E, 0, Hook), I).

expr(E, I, P, Hook) ->
    frmt(lexpr(E, P, Hook), I).

%%%
%%% Local functions
%%%

lform({attribute,Line,Name,Arg}, Hook) ->
    lattribute({attribute,Line,Name,Arg}, Hook);
lform({function,Line,Name,Arity,Clauses}, Hook) ->
    lfunction({function,Line,Name,Arity,Clauses}, Hook);
lform({rule,Line,Name,Arity,Clauses}, Hook) ->
    lrule({rule,Line,Name,Arity,Clauses}, Hook);
%% These are specials to make it easier for the compiler.
lform({error,E}, _Hook) ->
    leaf(format("~p\n", [{error,E}]));
lform({warning,W}, _Hook) ->
    leaf(format("~p\n", [{warning,W}]));
lform({eof,_Line}, _Hook) ->
    $\n.

lattribute({attribute,_Line,Name,Arg}, Hook) ->
    [lattribute(Name, Arg, Hook),leaf(".\n")].

lattribute(module, {M,Vs}, _Hook) ->
    attr("module",[{var,0,pname(M)},
                   foldr(fun(V, C) -> {cons,0,{var,0,V},C} 
                         end, {nil,0}, Vs)]);
lattribute(module, M, _Hook) ->
    attr("module", [{var,0,pname(M)}]);
lattribute(export, Falist, _Hook) ->
    call({var,0,"-export"}, [falist(Falist)], 0, none);
lattribute(import, Name, _Hook) when is_list(Name) ->
    attr("import", [{var,0,pname(Name)}]);
lattribute(import, {From,Falist}, _Hook) ->
    attr("import",[{var,0,pname(From)},falist(Falist)]);
lattribute(file, {Name,Line}, _Hook) ->
    attr("file", [{var,0,format("~p", [Name])},{integer,0,Line}]);
lattribute(record, {Name,Is}, Hook) ->
    Nl = leaf(format("-record(~w,", [Name])),
    [{first,Nl,record_fields(Is, Hook)},$)];
lattribute(Name, Arg, _Hook) ->
    attr(write(Name), [erl_parse:abstract(Arg)]).

attr(Name, Args) ->
    call({var,0,format("-~s", [Name])}, Args, 0, none).

pname(['' | As]) ->
    [$. | pname(As)];
pname([A]) ->
    write(A);
pname([A | As]) ->
    [write(A),$.|pname(As)];
pname(A) when is_atom(A) ->
    write(A).

falist([]) ->
    {nil,0};
falist([{Name,Arity}|Falist]) ->
    {cons,0,{var,0,format("~w/~w", [Name,Arity])},falist(Falist)}.

lfunction({function,_Line,Name,_Arity,Cs}, Hook) ->
    Cll = nl_clauses(fun (C, H) -> func_clause(Name, C, H) end, $;, Hook, Cs),
    [Cll,leaf(".\n")].

func_clause(Name, {clause,Line,Head,Guard,Body}, Hook) ->
    Hl = call({atom,Line,Name}, Head, 0, Hook),
    Gl = guard_when(Hl, Guard, Hook),
    Bl = body(Body, Hook),
    {step,Gl,Bl}.

lrule({rule,_Line,Name,_Arity,Cs}, Hook) ->
    Cll = nl_clauses(fun (C, H) -> rule_clause(Name, C, H) end, $;, Hook, Cs),
    [Cll,leaf(".\n")].

rule_clause(Name, {clause,Line,Head,Guard,Body}, Hook) ->
    Hl = call({atom,Line,Name}, Head, 0, Hook),
    Gl = guard_when(Hl, Guard, Hook, leaf(" :-")),
    Bl = rule_body(Body, Hook),
    {step,Gl,Bl}.

rule_body(Es, Hook) ->
    lc_quals(Es, Hook).

guard_when(Before, Guard, Hook) ->
    guard_when(Before, Guard, Hook, ' ->').

guard_when(Before, Guard, Hook, After) ->
    Gl = lguard(Guard, Hook),
    [{list,[{step,Before,Gl}]},After].

lguard([E|Es], Hook) when is_list(E) ->
    {list,[{step,'when',expr_list([E|Es], [$;], fun guard0/2, Hook)}]};
lguard([E|Es], Hook) -> % before R6
    lguard([[E|Es]], Hook);
lguard([], _) ->
    [].

guard0(Es, Hook) ->
    expr_list(Es, [$,], fun lexpr/2, Hook).

%% body(Before, Es, Hook) -> [Char].

body([E], Hook) ->
    lexpr(E, Hook);
body(Es, Hook) ->
    {prefer_nl,[$,],lexprs(Es, Hook)}.

lexpr(E, Hook) ->
    lexpr(E, 0, Hook).

lexpr({var,_,V}, _, _) when is_integer(V) ->	%Special hack for Robert
    leaf(format("_~w", [V]));
lexpr({var,_,V}, _, _) -> leaf(format("~s", [V]));
lexpr({char,_,C}, _, _) -> leaf(write_char(C));
lexpr({integer,_,N}, _, _) -> leaf(write(N));
lexpr({float,_,F}, _, _) -> leaf(write(F));
lexpr({atom,_,A}, _, _) -> leaf(write(A));
lexpr({string,_,S}, _, _) -> {string,S};
lexpr({nil,_}, _, _) -> '[]';
lexpr({cons,_,H,T}, _, Hook) ->
    list(T, [H], Hook);
lexpr({lc,_,E,Qs}, _Prec, Hook) ->
    Lcl = {list,[{step,[lexpr(E, Hook),leaf(" ||")],lc_quals(Qs, Hook)}]},
    {seq,$[,$],[],[Lcl]};
lexpr({tuple,_,Elts}, _, Hook) ->
    tuple(Elts, Hook);
%%lexpr({struct,_,Tag,Elts}, _, Hook) ->
%%  {first,format("~w", [Tag]),tuple(Elts, Hook)};
lexpr({record_index, _, Name, F}, Prec, Hook) ->
    {P,R} = preop_prec('#'),
    Nl = leaf(format("#~w", [Name])),
    El = [Nl,$.,lexpr(F, R, Hook)],
    maybe_paren(P, Prec, El);
lexpr({record, _, Name, Fs}, Prec, Hook) ->
    {P,_R} = preop_prec('#'),
    Nl = leaf(format("#~w", [Name])),
    El = {first,Nl,record_fields(Fs, Hook)},
    maybe_paren(P, Prec, El);
lexpr({record_field, _, Rec, Name, F}, Prec, Hook) ->
    {L,P,R} = inop_prec('#'),
    Rl = lexpr(Rec, L, Hook),
    Nl = leaf(format("#~w.", [Name])),
    El = [Rl,Nl,lexpr(F, R, Hook)],
    maybe_paren(P, Prec, El);
lexpr({record, _, Rec, Name, Fs}, Prec, Hook) ->
    {L,P,_R} = inop_prec('#'),
    Rl = lexpr(Rec, L, Hook),
    Nl = leaf(format("#~w", [Name])),
    El = {first,[Rl,Nl],record_fields(Fs, Hook)},
    maybe_paren(P, Prec, El);
lexpr({record_field, _, {atom,_,''}, F}, Prec, Hook) ->
    {_L,P,R} = inop_prec('.'),
    El = [$.,lexpr(F, R, Hook)],
    maybe_paren(P, Prec, El);
lexpr({record_field, _, Rec, F}, Prec, Hook) ->
    {L,P,R} = inop_prec('.'),
    El = [lexpr(Rec, L, Hook),$.,lexpr(F, R, Hook)],
    maybe_paren(P, Prec, El);
lexpr({block,_,Es}, _, Hook) ->
    {list,[{step,'begin',body(Es, Hook)},'end']};
lexpr({'if',_,Cs}, _, Hook) ->
    {list,[{step,'if',if_clauses(Cs, Hook)},'end']};
lexpr({'case',_,Expr,Cs}, _, Hook) ->
    {list,[{step,{list,[{step,'case',lexpr(Expr, Hook)},'of']},
            cr_clauses(Cs, Hook)},
           'end']};
lexpr({'cond',_,Cs}, _, Hook) ->
    {list,[{step,leaf("cond"),cond_clauses(Cs, Hook)},'end']};
lexpr({'receive',_,Cs}, _, Hook) ->
    {list,[{step,'receive',cr_clauses(Cs, Hook)},'end']};
lexpr({'receive',_,Cs,To,ToOpt}, _, Hook) ->
    Al = {list,[{step,[lexpr(To, Hook),' ->'],body(ToOpt, Hook)}]},
    {list,[{step,'receive',cr_clauses(Cs, Hook)},
           {step,'after',Al},
           'end']};
lexpr({'fun',_,{function,F,A}}, _Prec, _Hook) ->
    leaf(format("fun ~w/~w", [F,A]));
lexpr({'fun',_,{function,F,A},Extra}, _Prec, _Hook) ->
    {force_nl,fun_info(Extra),leaf(format("fun ~w/~w", [F,A]))};
lexpr({'fun',_,{function,M,F,A}}, _Prec, _Hook) ->
    leaf(format("fun ~w:~w/~w", [M,F,A]));
lexpr({'fun',_,{clauses,Cs}}, _Prec, Hook) ->
    {list,[{first,'fun',fun_clauses(Cs, Hook)},'end']};
lexpr({'fun',_,{clauses,Cs},Extra}, _Prec, Hook) ->
    {force_nl,fun_info(Extra),
     {list,[{first,'fun',fun_clauses(Cs, Hook)},'end']}};
lexpr({'query',_,Lc}, _Prec, Hook) ->
    {list,[{step,leaf("query"),lexpr(Lc, 0, Hook)},'end']};
lexpr({call,_,{remote,_,{atom,_,M},{atom,_,F}=N}=Name,Args}, Prec, Hook) ->
    case erl_internal:bif(M, F, length(Args)) of
        true ->
            call(N, Args, Prec, Hook);
        false ->
            call(Name, Args, Prec, Hook)
    end;
lexpr({call,_,Name,Args}, Prec, Hook) ->
    call(Name, Args, Prec, Hook);
lexpr({'try',_,Es,Scs,Ccs,As}, _, Hook) ->
    {list,[if
               Scs =:= [] ->
                   {step,'try',body(Es, Hook)};
               true ->
                   {step,{list,[{step,'try',body(Es, Hook)},'of']},
                    cr_clauses(Scs, Hook)}
           end,
           if
               Ccs =:= [] ->
                   [];
               true ->
                   {step,'catch',try_clauses(Ccs, Hook)}
           end,
           if
               As =:= [] ->
                   [];
               true ->
                   {step,'after',body(As, Hook)}
           end,
           'end']};
lexpr({'catch',_,Expr}, Prec, Hook) ->
    {P,R} = preop_prec('catch'),
    El = {list,[{step,'catch',lexpr(Expr, R, Hook)}]},
    maybe_paren(P, Prec, El);
lexpr({match,_,Lhs,Rhs}, Prec, Hook) ->
    {L,P,R} = inop_prec('='),
    Pl = lexpr(Lhs, L, Hook),
    Rl = lexpr(Rhs, R, Hook),
    El = {list,[{cstep,[Pl,' ='],Rl}]},
    maybe_paren(P, Prec, El);
lexpr({op,_,Op,Arg}, Prec, Hook) ->
    {P,R} = preop_prec(Op),
    Ol = leaf(format("~s ", [Op])),
    El = [Ol,lexpr(Arg, R, Hook)],
    maybe_paren(P, Prec, El);
lexpr({op,_,Op,Larg,Rarg}, Prec, Hook) ->
    {L,P,R} = inop_prec(Op),
    Ll = lexpr(Larg, L, Hook),
    Ol = leaf(format("~s", [Op])),
    Lr = lexpr(Rarg, R, Hook),
    El = {list,[Ll,Ol,Lr]},
    maybe_paren(P, Prec, El);
%% Special expressions which are not really legal everywhere.
lexpr({remote,_,M,F}, Prec, Hook) ->
    {L,P,R} = inop_prec(':'),
    NameItem = lexpr(M, L, Hook),
    CallItem = lexpr(F, R, Hook),
    maybe_paren(P, Prec, [NameItem,$:,CallItem]);
%% BIT SYNTAX:
lexpr({bin,_,Fs}, _, Hook) ->
    bit_grp(Fs, Hook);
%% Special case for straight values.
lexpr({value,_,Val}, _,_) ->
    leaf(write(Val));
%% Now do the hook.
lexpr(Other, _Precedence, none) ->
    leaf(format("INVALID-FORM:~w:",[Other]));
lexpr(HookExpr, Precedence, {Mod,Func,Eas}) when Mod =/= 'fun' ->
    {ehook,HookExpr,Precedence,{Mod,Func,Eas}};
lexpr(HookExpr, Precedence, Func) ->
    {hook,HookExpr,Precedence,Func}.

call(Name, Args, Prec, Hook) ->
    {F,P} = func_prec(),
    Item = {first,lexpr(Name, F, Hook),args(Args, Hook)},
    maybe_paren(P, Prec, Item).

fun_info(Extra) ->
    leaf(format("% fun-info: ~p", [Extra])).

%% BITS:

bit_grp(Fs, Hook) ->
    append([['<<'],
            [try
                 true = Fs =/= [],
                 S = bin_string(Fs),
                 true = io_lib:printable_list(S),
                 {string,S}
             catch _:_ ->
                 bit_elems(Fs, Hook)
            end],
            ['>>']]).

bin_string([]) ->
    [];
bin_string([{bin_element,_,{char,_,C},_,_}|Bin]) ->
    [C | bin_string(Bin)].

bit_elems(Es, Hook) ->
    expr_list(Es, $,, fun bit_elem/2, Hook).

bit_elem({bin_element,_,Expr,Sz,Types}, Hook) ->
    P = max_prec(),
    VChars = lexpr(Expr, P, Hook),
    SChars = if
                 Sz =/= default ->
                     [VChars,$:,lexpr(Sz, P, Hook)];
                 true ->
                     VChars
             end,
    if
        Types =/= default ->
            [SChars,$/|bit_elem_types(Types)];
        true ->
	    SChars
    end.

bit_elem_types([T]) ->
    [bit_elem_type(T)];
bit_elem_types([T | Rest]) ->
    [bit_elem_type(T), $-|bit_elem_types(Rest)].

bit_elem_type({A,B}) ->
    [lexpr(erl_parse:abstract(A), none),
     $:,
     lexpr(erl_parse:abstract(B), none)];
bit_elem_type(T) ->
    lexpr(erl_parse:abstract(T), none).

%% end of BITS

record_fields(Fs, Hook) ->
    tuple(Fs, fun record_field/2, Hook).

record_field({record_field,_,F,Val}, Hook) ->
    {L,_P,R} = inop_prec('='),
    Fl = lexpr(F, L, Hook),
    Vl = lexpr(Val, R, Hook),
    {list,[{cstep,[Fl,' ='],Vl}]};
record_field({record_field,_,F}, Hook) ->
    lexpr(F, 0, Hook).

list({cons,_,H,T}, Es, Hook) ->
    list(T, [H|Es], Hook);
list({nil,_}, Es, Hook) ->
    proper_list(reverse(Es), Hook);
list(Other, Es, Hook) ->
    improper_list(reverse(Es, [Other]), Hook).

%% if_clauses(Clauses, Hook) -> [Char].
%%  Print 'if' clauses.

if_clauses(Cs, Hook) ->
    clauses(fun if_clause/2, Hook, Cs).

if_clause({clause,_,[],G,B}, Hook) ->
    Gl = [guard_no_when(G, Hook),' ->'],
    {step,Gl,body(B, Hook)}.

guard_no_when([E|Es], Hook) when is_list(E) ->
    expr_list([E|Es], $;, fun guard0/2, Hook);
guard_no_when([E|Es], Hook) -> % before R6
    guard_no_when([[E|Es]], Hook);
guard_no_when([], _) -> % cannot happen
    leaf("true").

%% cr_clauses(Clauses, Hook) -> [Char].
%%  Print 'case'/'receive' clauses.

cr_clauses(Cs, Hook) ->
    clauses(fun cr_clause/2, Hook, Cs).

cr_clause({clause,_,[T],G,B}, Hook) ->
    El = lexpr(T, 0, Hook),
    Gl = guard_when(El, G, Hook),
    Bl = body(B, Hook),
    {step,Gl,Bl}.

%% try_clauses(Clauses, Hook) -> [Char].
%%  Print 'try' clauses.

try_clauses(Cs, Hook) ->
    clauses(fun try_clause/2, Hook, Cs).

try_clause({clause,_,[{tuple,_,[{atom,_,throw},V,S]}],G,B}, Hook) ->
    El = lexpr(V, 0, Hook),
    Sl = stack_backtrace(S, [El], Hook),
    Gl = guard_when(Sl, G, Hook),
    Bl = body(B, Hook),
    {step,Gl,Bl};
try_clause({clause,_,[{tuple,_,[C,V,S]}],G,B}, Hook) ->
    Cs = lexpr(C, 0, Hook),
    El = lexpr(V, 0, Hook),
    CsEl = [Cs,$:,El],
    Sl = stack_backtrace(S, CsEl, Hook),
    Gl = guard_when(Sl, G, Hook),
    Bl = body(B, Hook),
    {step,Gl,Bl}.

stack_backtrace({var,_,'_'}, El, _Hook) ->
    El;
stack_backtrace(S, El, Hook) ->
    El++[$:,lexpr(S, 0, Hook)].

%% fun_clauses(Clauses, Hook) -> [Char].
%%  Print 'fun' clauses.

fun_clauses(Cs, Hook) ->
    nl_clauses(fun fun_clause/2, [$;], Hook, Cs).

fun_clause({clause,_,A,G,B}, Hook) ->
    El = args(A, Hook),
    Gl = guard_when(El, G, Hook),
    Bl = body(B, Hook),
    {step,Gl,Bl}.

%% cond_clauses(Clauses, Hook) -> [Char].
%%  Print 'cond' clauses.

cond_clauses(Cs, Hook) ->
    clauses(fun cond_clause/2, Hook, Cs).

cond_clause({clause,_,[],[[E]],B}, Hook) ->
    {step,[lexpr(E, Hook),' ->'],body(B, Hook)}.

%% nl_clauses(Type, Hook, Clauses) -> [Char].
%%  Generic clause printing function (always breaks lines).

nl_clauses(Type, Sep, Hook, Cs) ->
    {prefer_nl,Sep,lexprs(Cs, Type, Hook)}.

%% clauses(Type, Hook, Clauses) -> [Char].
%%  Generic clause printing function.

clauses(Type, Hook, Cs) ->
    expr_list(Cs, [$;], Type, Hook).

%% lc_quals(Qualifiers, After, Hook)
%% List comprehension qualifiers

lc_quals(Qs, Hook) ->
    {seq,[],[],[$,],lexprs(Qs, fun lc_qual/2, Hook)}.

lc_qual({generate,_,Pat,E}, Hook) ->
    Pl = lexpr(Pat, 0, Hook),
    {list,[{step,[Pl,leaf(" <-")],lexpr(E, 0, Hook)}]};
lc_qual(Q, Hook) ->
    lexpr(Q, 0, Hook).

proper_list(Es, Hook) ->
    {seq,$[,$],$,,lexprs(Es, Hook)}.

improper_list(Es, Hook) ->
    {seq,$[,$],{$,,$|},lexprs(Es, Hook)}.

tuple(L, Hook) ->
    tuple(L, fun lexpr/2, Hook).

tuple(Es, F, Hook) ->
    {seq,${,$},$,,lexprs(Es, F, Hook)}.

args(As, Hook) ->
    {seq,$(,$),[$,],lexprs(As, Hook)}.

expr_list(Es, Sep, F, Hook) ->
    {seq,[],[],Sep,lexprs(Es, F, Hook)}.

lexprs(Es, Hook) ->
    lexprs(Es, fun lexpr/2, Hook).

lexprs(Es, F, Hook) ->
    map(fun(E) -> F(E, Hook) end, Es).

maybe_paren(P, Prec, Expr) when P < Prec ->
    [$(,Expr,$)];
maybe_paren(_P, _Prec, Expr) ->
    Expr.

leaf(S) ->
    {leaf,iolist_size(S),S}.

%%% Do the formatting. Currently nothing fancy. Could probably have
%%% done it in one single pass.

frmt(Item) ->
    frmt(Item, 0).

frmt(Item, I) ->
    ST = spacetab(),
    WT = wordtable(),
    {Chars,_Length} = f(Item, I, ST, WT),
    [Chars].

%%% What the tags mean:
%%% - C: a character
%%% - [I|Is]: Is follow after I without newline or space
%%% - {list,IPs}: try to put all IPs on one line, if that fails newlines
%%%   and indentation are inserted between IPs.
%%% - {first,I,IP2}: IP2 follows after I, and is output with an indentation
%%%   updated with the width of I.
%%% - {seq,Before,After,Separator,IPs}: a sequence of Is separated by 
%%%   Separator. Before is output before IPs, and the indentation of IPs 
%%%   is updated with the width of Before. After follows after IPs.
%%% - {force_el,ExtraInfo,I}: fun-info (a comment) forces linebreak before I.
%%% - {prefer_nl,Sep,IPs}: forces linebreak between Is unlesss negative
%%%   indentation.
%%% - {string,S}: a string.
%%% - {hook,...}, {ehook,...}: hook expressions.
%%% 
%%% list, first, seq, force_nl, and prefer_nl all accept IPs, where each
%%% element is either an item or a tuple {step|cstep,I1,I2}. step means
%%% that I2 is output after linebreak and an incremented indentation.
%%% cstep works similarly, but no linebreak is the width of I1 is less
%%% than the indentation (this is for "A = <expression over several lines>).

f([]=Nil, _I0, _ST, _WT) ->
    {Nil,0};
f(C, _I0, _ST, _WT) when is_integer(C) ->
    {C,1};
f({leaf,Length,Chars}, _I0, _ST, _WT) ->
    {Chars,Length};
f([Item|Items], I0, ST, WT) ->
    consecutive(Items, f(Item, I0, ST, WT), I0, ST, WT);
f({list,Items}, I0, ST, WT) ->
    f({seq,[],[],[],Items}, I0, ST, WT);
f({first,E,Item}, I0, ST, WT) ->
    f({seq,E,[],[],[Item]}, I0, ST, WT);
f({seq,Before,After,Sep,LItems}, I0, ST, WT) ->
    BCharsSize = f(Before, I0, ST, WT),
    I = indent(BCharsSize, I0),
    CharsSizeL = fl(LItems, Sep, I, After, ST, WT),
    {CharsL,SizeL} = unz(CharsSizeL),
    {BCharsL,BSizeL} = unz1([BCharsSize]),
    Sizes = BSizeL ++ SizeL,
    NSepChars = if 
                    is_list(Sep) -> lists:max([0,length(CharsL)-1]);
                    true -> 0
                end,
    case same_line(I0, Sizes, NSepChars) of
        {yes,Size} ->
            Chars = if
                        NSepChars > 0 -> insert_sep(CharsL, $\s);
                        true -> CharsL
                    end,
            {BCharsL++Chars,Size};
        no ->
            {BCharsL++insert_newlines(CharsSizeL, I, ST),
             nsz(lists:last(Sizes), I0)}
    end;
f({force_nl,_ExtraInfoItem,Item}, I, ST, WT) when I < 0 ->
    %% Extra info is a comment; cannot have that on the same line
    f(Item, I, ST, WT);
f({force_nl,ExtraInfoItem,Item}, I, ST, WT) ->
    f({prefer_nl,[],[ExtraInfoItem,Item]}, I, ST, WT);
f({prefer_nl,Sep,LItems}, I, ST, WT) when I < 0 ->
    f({seq,[],[],Sep,LItems}, I, ST, WT);
f({prefer_nl,Sep,LItems}, I0, ST, WT) ->
    CharsSize2L = fl(LItems, Sep, I0, [], ST, WT),
    {_CharsL,Sizes} = unz(CharsSize2L),
    {insert_newlines(CharsSize2L, I0, ST),nsz(lists:last(Sizes), I0)};
f({string,S}, I, ST, WT) ->
    f(write_a_string(S, I), I, ST, WT);
f({hook,HookExpr,Precedence,Func}, I, _ST, _WT) ->
    Chars = Func(HookExpr, I, Precedence, Func),
    {Chars,indentation(Chars, I)};
f({ehook,HookExpr,Precedence,{Mod,Func,Eas}=ModFuncEas}, I, _ST, _WT) ->
    Chars = apply(Mod, Func, [HookExpr,I,Precedence,ModFuncEas|Eas]),
    {Chars,indentation(Chars, I)};
f(WordName, _I, _ST, WT) -> % when is_atom(WordName)
    word(WordName, WT).

-define(IND, 4).

%% fl(ListItems, I0, ST, WT) -> [[CharsSize1,CharsSize2]]
%% ListItems = [{Item,Items}|Item]
fl([], _Sep, I0, After, ST, WT) ->
    [[f(After, I0, ST, WT),{[],0}]];
fl(CItems, Sep0, I0, After, ST, WT) ->
    F = fun({step,Item1,Item2}, S) ->
                [f(Item1, I0, ST, WT),f([Item2,S], incr(I0, ?IND), ST, WT)];
           ({cstep,Item1,Item2}, S) ->
                {_,Sz1} = CharSize1 = f(Item1, I0, ST, WT),
                if
                    is_integer(Sz1), Sz1 < ?IND ->
                        Item2p = [leaf("\s"),Item2,S],
                        [consecutive(Item2p, CharSize1, I0, ST, WT),{[],0}];
                    true ->
                        [CharSize1,f([Item2,S], incr(I0, ?IND), ST, WT)]
                end;
           (Item, S) ->
                [f([Item,S], I0, ST, WT),{[],0}]
        end,
    {Sep,LastSep}  = case Sep0 of {_,_} -> Sep0; _ -> {Sep0,Sep0} end,
    fl1(CItems, F, Sep, LastSep, After).

fl1([CItem], F, _Sep, _LastSep, After) ->
    [F(CItem,After)];
fl1([CItem1,CItem2], F, _Sep, LastSep, After) ->
    [F(CItem1, LastSep),F(CItem2, After)];
fl1([CItem|CItems], F, Sep, LastSep, After) ->
    [F(CItem, Sep)|fl1(CItems, F, Sep, LastSep, After)].

consecutive(Items, CharSize1, I0, ST, WT) ->
    {CharsSizes,_Length} =
        mapfoldl(fun(Item, Len) ->
                         CharsSize = f(Item, Len, ST, WT),
                         {CharsSize,indent(CharsSize, Len)}
                 end, indent(CharSize1, I0), Items),
    {CharsL,SizeL} = unz1([CharSize1|CharsSizes]),
    {CharsL,line_size(SizeL)}.

unz(CharsSizesL) ->
    unz1(append(CharsSizesL)).

unz1(CharSizes) ->
    lists:unzip(nonzero(CharSizes)).

nonzero(CharSizes) ->
    lists:filter(fun({_,Sz}) -> Sz =/= 0 end, CharSizes).

insert_newlines(CharsSizesL, I, ST) when I >= 0 ->
    insert_nl(foldr(fun([{_C1,0},{_C2,0}], A) ->
                            A;
                       ([{C1,_Sz1},{_C2,0}], A) ->
                            [C1|A];
                       ([{C1,_Sz1},{C2,Sz2}], A) when Sz2 > 0 ->
                            [insert_nl([C1,C2], I+?IND, ST)|A]
                    end, [], CharsSizesL), I, ST).


insert_nl(CharsL, I, ST) ->
    insert_sep(CharsL, nl_indent(I, ST)).

insert_sep([Chars1 | CharsL], Sep) ->
    [Chars1 | map(fun(Chars) -> [Sep,Chars] end, CharsL)].

nl_indent(0, _T) ->
    $\n;
nl_indent(I, T) when I > 0 ->
    [$\n|spaces(I, T)].

same_line(I0, SizeL, NSepChars) ->
    try 
        Size = lists:sum(SizeL) + NSepChars,
        true = incr(I0, Size) =< ?MAXLINE,
        {yes,Size}
    catch _:_ ->
        no
    end.

line_size(SizeL) ->
    line_size(SizeL, 0, false).

line_size([], Size, false) ->
    Size;
line_size([], Size, true) ->
    {line,Size};
line_size([{line,Len}|SizeL], _, _) ->
    line_size(SizeL, Len, true);
line_size([Sz|SizeL], SizeSoFar, LF) ->
    line_size(SizeL, SizeSoFar+Sz, LF).

nsz({line,_Len}=Sz, _I) ->
    Sz;
nsz(Size, I) when I >= 0 ->
    {line,Size+I}.

indent({_Chars,{line,Len}}, _I) ->
    Len;
indent({_Chars,Size}, I) ->
    incr(I, Size).

incr(I, _Incr) when I < 0 ->
    I;
incr(I, Incr) ->
    I+Incr.

indentation(E, I) when I < 0 ->
    iolist_size(E);
indentation(E, I0) ->
    I = io_lib_format:indentation(E, I0),
    case has_nl(E) of
        true -> {line,I};
        false -> I
    end.

has_nl([$\n|_]) ->
    true;
has_nl([C|Cs]) when is_integer(C) ->
    has_nl(Cs);
has_nl([C|Cs]) ->
    has_nl(C) orelse has_nl(Cs);
has_nl([]) ->
    false.

-define(MIN_SUBSTRING, 5).

write_a_string(S, I) when I < 0; S =:= [] ->
    leaf(write_string(S));
write_a_string(S, I) ->
    Len = lists:max([?MAXLINE-I,?MIN_SUBSTRING]),
    {list,write_a_string(S, Len, Len)}.

write_a_string([], _N, _Len) ->
    [];
write_a_string(S, N, Len) ->
    SS = string:sub_string(S, 1, N),
    Sl = write_string(SS),
    case (iolist_size(Sl) > Len) and (N > ?MIN_SUBSTRING) of
        true ->
            write_a_string(S, N-1, Len);
        false ->
            [leaf(Sl)|write_a_string(lists:nthtail(length(SS), S), Len, Len)]
    end.

%%
%% Utilities
%%

-define(N_SPACES, 30).

spacetab() ->
    {[_|L],_} = mapfoldl(fun(_, A) -> {A,[$\s|A]} 
                         end, [], lists:seq(0, ?N_SPACES)),
    list_to_tuple(L).    

spaces(N, T) when N =< ?N_SPACES ->
    element(N, T);
spaces(N, T) ->
    [element(?N_SPACES, T)|spaces(N-?N_SPACES, T)].

wordtable() ->
    L = [begin {leaf,Sz,S} = leaf(W), {S,Sz} end || 
            W <- [" ->"," =","<<",">>","[]","after","begin","case","catch",
                  "end","fun","if","of","receive","try","when"]],
    list_to_tuple(L).

word(' ->', WT) -> element(1, WT);
word(' =', WT) -> element(2, WT);
word('<<', WT) -> element(3, WT);
word('>>', WT) -> element(4, WT);
word('[]', WT) -> element(5, WT);
word('after', WT) -> element(6, WT);
word('begin', WT) -> element(7, WT);
word('case', WT) -> element(8, WT);
word('catch', WT) -> element(9, WT);
word('end', WT) -> element(10, WT);
word('fun', WT) -> element(11, WT);
word('if', WT) -> element(12, WT);
word('of', WT) -> element(13, WT);
word('receive', WT) -> element(14, WT);
word('try', WT) -> element(15, WT);
word('when', WT) -> element(16, WT).
