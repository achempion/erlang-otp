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
%%     $Id$
%%
-module(ms_transform).

-export([format_error/1,transform_from_shell/3,parse_transform/2]).

%% Error codes.
-define(ERROR_BASE_GUARD,0).
-define(ERROR_BASE_BODY,100).
-define(ERR_NOFUN,1).
-define(ERR_ETS_HEAD,2).
-define(ERR_DBG_HEAD,3).
-define(ERR_HEADMATCH,4).
-define(ERR_SEMI_GUARD,5).
-define(ERR_UNBOUND_VARIABLE,6).
-define(ERR_HEADBADREC,7).
-define(ERR_HEADBADFIELD,8).
-define(ERR_HEADMULTIFIELD,9).
-define(ERR_HEADDOLLARATOM,10).
-define(ERR_HEADBINMATCH,11).
-define(ERR_GENMATCH,16).
-define(ERR_GENLOCALCALL,17).
-define(ERR_GENELEMENT,18).
-define(ERR_GENBADFIELD,19).
-define(ERR_GENBADREC,20).
-define(ERR_GENMULTIFIELD,21).
-define(ERR_GENREMOTECALL,22).
-define(ERR_GENBINCONSTRUCT,23).
-define(ERR_GENDISALLOWEDOP,24).
-define(ERR_GUARDMATCH,?ERR_GENMATCH+?ERROR_BASE_GUARD).
-define(ERR_BODYMATCH,?ERR_GENMATCH+?ERROR_BASE_BODY).
-define(ERR_GUARDLOCALCALL,?ERR_GENLOCALCALL+?ERROR_BASE_GUARD).
-define(ERR_BODYLOCALCALL,?ERR_GENLOCALCALL+?ERROR_BASE_BODY).
-define(ERR_GUARDELEMENT,?ERR_GENELEMENT+?ERROR_BASE_GUARD).
-define(ERR_BODYELEMENT,?ERR_GENELEMENT+?ERROR_BASE_BODY).
-define(ERR_GUARDBADFIELD,?ERR_GENBADFIELD+?ERROR_BASE_GUARD).
-define(ERR_BODYBADFIELD,?ERR_GENBADFIELD+?ERROR_BASE_BODY).
-define(ERR_GUARDBADREC,?ERR_GENBADREC+?ERROR_BASE_GUARD).
-define(ERR_BODYBADREC,?ERR_GENBADREC+?ERROR_BASE_BODY).
-define(ERR_GUARDMULTIFIELD,?ERR_GENMULTIFIELD+?ERROR_BASE_GUARD).
-define(ERR_BODYMULTIFIELD,?ERR_GENMULTIFIELD+?ERROR_BASE_BODY).
-define(ERR_GUARDREMOTECALL,?ERR_GENREMOTECALL+?ERROR_BASE_GUARD).
-define(ERR_BODYREMOTECALL,?ERR_GENREMOTECALL+?ERROR_BASE_BODY).
-define(ERR_GUARDBINCONSTRUCT,?ERR_GENBINCONSTRUCT+?ERROR_BASE_GUARD).
-define(ERR_BODYBINCONSTRUCT,?ERR_GENBINCONSTRUCT+?ERROR_BASE_BODY).
-define(ERR_GUARDDISALLOWEDOP,?ERR_GENDISALLOWEDOP+?ERROR_BASE_GUARD).
-define(ERR_BODYDISALLOWEDOP,?ERR_GENDISALLOWEDOP+?ERROR_BASE_BODY).

%%
%% Called by compiler or ets/dbg:fun2ms when errors occur
%%
format_error(?ERR_NOFUN) ->	    
    "Parameter of ets/dbg:fun2ms/1 is not a literal fun";
format_error(?ERR_ETS_HEAD) ->	    
    "ets:fun2ms requires fun with single variable or tuple parameter";
format_error(?ERR_DBG_HEAD) ->	    
    "dbg:fun2ms requires fun with single variable or list parameter";
format_error(?ERR_HEADMATCH) ->	    
    "in fun head, only matching (=) on toplevel can be translated into match_spec";
format_error(?ERR_SEMI_GUARD) ->	    
    "fun with semicolon (;) in guard cannot be translated into match_spec";
format_error(?ERR_GUARDMATCH) ->	    
    "fun with guard matching ('=' in guard) is illegal as match_spec as well";
format_error({?ERR_GUARDLOCALCALL, Name, Arithy}) ->	    
    lists:flatten(io_lib:format("fun containing the local function call "
				"'~w/~w' (called in guard) "
				"cannot be translated into match_spec",
				[Name, Arithy]));
format_error({?ERR_GUARDREMOTECALL, Module, Name, Arithy}) ->	    
    lists:flatten(io_lib:format("fun containing the remote function call "
				"'~w:~w/~w' (called in guard) "
				"cannot be translated into match_spec",
				[Module,Name,Arithy]));
format_error({?ERR_GUARDELEMENT, Str}) ->
    lists:flatten(
      io_lib:format("the language element ~s (in guard) cannot be translated "
		    "into match_spec", [Str]));
format_error({?ERR_GUARDBINCONSTRUCT, Var}) ->
    lists:flatten(
      io_lib:format("bit syntax construction with variable ~w (in guard) "
		    "cannot be translated "
		    "into match_spec", [Var]));
format_error({?ERR_GUARDDISALLOWEDOP, Operator}) ->
    lists:flatten(
      io_lib:format("the operator ~w is not allowed in guards", [Operator]));
format_error(?ERR_BODYMATCH) ->	    
    "fun with body matching ('=' in body) is illegal as match_spec";
format_error({?ERR_BODYLOCALCALL, Name, Arithy}) ->	    
    lists:flatten(io_lib:format("fun containing the local function "
				"call '~w/~w' (called in body) "
				"cannot be translated into match_spec",
				[Name,Arithy]));
format_error({?ERR_BODYREMOTECALL, Module, Name, Arithy}) ->	    
    lists:flatten(io_lib:format("fun containing the remote function call "
				"'~w:~w/~w' (called in body) "
				"cannot be translated into match_spec",
				[Module,Name,Arithy]));
format_error({?ERR_BODYELEMENT, Str}) ->
    lists:flatten(
      io_lib:format("the language element ~s (in body) cannot be translated "
		    "into match_spec", [Str]));
format_error({?ERR_BODYBINCONSTRUCT, Var}) ->
    lists:flatten(
      io_lib:format("bit syntax construction with variable ~w (in body) "
		    "cannot be translated "
		    "into match_spec", [Var]));
format_error({?ERR_BODYDISALLOWEDOP, Operator}) -> 
    %% This will probably never happen, Are there op's that are allowed in 
    %% guards but not in bodies? Not at time of writing anyway...
    lists:flatten(
      io_lib:format("the operator ~w is not allowed in function bodies", 
		    [Operator]));

format_error({?ERR_UNBOUND_VARIABLE, Str}) ->
    lists:flatten(
      io_lib:format("the variable ~s is unbound, cannot translate "
		    "into match_spec", [Str]));
format_error({?ERR_HEADBADREC,Name}) ->	    
    lists:flatten(
      io_lib:format("fun head contains unknown record type ~w",[Name]));
format_error({?ERR_HEADBADFIELD,RName,FName}) ->	    
    lists:flatten(
      io_lib:format("fun head contains reference to unknown field ~w in "
		    "record type ~w",[FName, RName]));
format_error({?ERR_HEADMULTIFIELD,RName,FName}) ->	    
    lists:flatten(
      io_lib:format("fun head contains already defined field ~w in "
		    "record type ~w",[FName, RName]));
format_error({?ERR_HEADDOLLARATOM,Atom}) ->	    
    lists:flatten(
      io_lib:format("fun head contains atom ~w, which conflics with reserved "
		    "atoms in match_spec heads",[Atom]));
format_error({?ERR_HEADBINMATCH,Atom}) ->	    
    lists:flatten(
      io_lib:format("fun head contains bit syntax matching of variable ~w, "
		    "which cannot be translated into match_spec", [Atom]));
format_error({?ERR_GUARDBADREC,Name}) ->	    
    lists:flatten(
      io_lib:format("fun guard contains unknown record type ~w",[Name]));
format_error({?ERR_GUARDBADFIELD,RName,FName}) ->	    
    lists:flatten(
      io_lib:format("fun guard contains reference to unknown field ~w in "
		    "record type ~w",[FName, RName]));
format_error({?ERR_GUARDMULTIFIELD,RName,FName}) ->	    
    lists:flatten(
      io_lib:format("fun guard contains already defined field ~w in "
		    "record type ~w",[FName, RName]));
format_error({?ERR_BODYBADREC,Name}) ->	    
    lists:flatten(
      io_lib:format("fun body contains unknown record type ~w",[Name]));
format_error({?ERR_BODYBADFIELD,RName,FName}) ->	    
    lists:flatten(
      io_lib:format("fun body contains reference to unknown field ~w in "
		    "record type ~w",[FName, RName]));
format_error({?ERR_BODYMULTIFIELD,RName,FName}) ->	    
    lists:flatten(
      io_lib:format("fun body contains already defined field ~w in "
		    "record type ~w",[FName, RName]));
format_error(Else) ->
    lists:flatten(io_lib:format("Unknown error code ~w",[Else])).

%%
%% Called when translating in shell
%%
transform_from_shell(Dialect, Clauses, BoundEnvironment) ->
    SaveFilename = setup_filename(),
    case catch ms_clause_list(1,Clauses,Dialect) of
	{'EXIT',Reason} ->
	    cleanup_filename(SaveFilename),
	    exit(Reason);
	{error,Line,R} ->
	    {error, [{cleanup_filename(SaveFilename),
		      [{Line, ?MODULE, R}]}], []};
	Else ->
            case (catch fixup_environment(Else,BoundEnvironment)) of
                {error,Line1,R1} ->
                    {error, [{cleanup_filename(SaveFilename),
                             [{Line1, ?MODULE, R1}]}], []}; 
                Else1 ->
		    Ret = normalise(Else1),
                    cleanup_filename(SaveFilename),
		    Ret
            end
    end.
    

%%
%% Called when translating during compiling
%%
parse_transform(Forms, _Options) ->
    SaveFilename = setup_filename(),
    case catch forms(Forms) of
	{'EXIT',Reason} ->
	    cleanup_filename(SaveFilename),
	    exit(Reason);
	{error,Line,R} ->
	    {error, [{cleanup_filename(SaveFilename),
		      [{Line, ?MODULE, R}]}], []};
	Else ->
	    cleanup_filename(SaveFilename),
	    Else
    end.

setup_filename() ->
    {erase(filename),erase(records)}.

put_filename(Name) ->
    put(filename,Name).

put_records(R) ->
    put(records,R),
    ok.
get_records() ->
    case get(records) of
	undefined ->
	    [];
	Else ->
	    Else
    end.
cleanup_filename({Old,OldRec}) ->
    Ret = case erase(filename) of
	      undefined ->
		  "TOP_LEVEL";
	      X ->
		  X
	  end,
    case OldRec of
	undefined ->
	    erase(records);
	Rec ->
	    put(records,Rec)
    end,
    case Old of
	undefined ->
	    Ret;
	Y ->
	    put(filename,Y),
	    Ret
    end.

add_record_definition({Name,FieldList}) ->
    {KeyList,_} = lists:foldl(
		    fun({record_field,_,{atom,Line0,FieldName}},{L,C}) ->
			    {[{FieldName,C,{atom,Line0,undefined}}|L],C+1};
		       ({record_field,_,{atom,_,FieldName},Def},{L,C}) ->
			    {[{FieldName,C,Def}|L],C+1}
		    end,
		    {[],2},
		    FieldList),
    put_records([{Name,KeyList}|get_records()]).

forms([F0|Fs0]) ->
    F1 = form(F0),
    Fs1 = forms(Fs0),
    [F1|Fs1];
forms([]) -> [].

form({attribute,_,file,{Filename,_}}=Form) ->
    put_filename(Filename),
    Form;
form({attribute,_,record,Definition}=Form) -> 
    add_record_definition(Definition),
    Form;
form({function,Line,Name0,Arity0,Clauses0}) ->
    {Name,Arity,Clauses} = function(Name0, Arity0, Clauses0),
    {function,Line,Name,Arity,Clauses};
form(AnyOther) ->
    AnyOther.
function(Name, Arity, Clauses0) ->
    Clauses1 = clauses(Clauses0),
    {Name,Arity,Clauses1}.
clauses([C0|Cs]) ->
    C1 = clause(C0),
    [C1|clauses(Cs)];
clauses([]) -> [].
clause({clause,Line,H0,G0,B0}) ->
    B1 = copy(B0),
    {clause,Line,H0,G0,B1}.

copy({call,Line,{remote,_Line2,{atom,_Line3,ets},{atom,_Line4,fun2ms}},
      As0}) ->
    transform_call(ets,Line,As0);
copy({call,Line,{remote,_Line2,{atom,_Line3,dbg},{atom,_Line4,fun2ms}},
      As0}) ->
    transform_call(dbg,Line,As0);
copy(T) when is_tuple(T) ->
    list_to_tuple(copy_list(tuple_to_list(T)));
copy(L) when is_list(L) ->
    copy_list(L);
copy(AnyOther) ->
    AnyOther.

copy_list([H|T]) ->
    [copy(H)|copy_list(T)];
copy_list([]) ->
    [].

transform_call(Type,_Line,[{'fun',Line2,{clauses, ClauseList}}]) ->
    ms_clause_list(Line2, ClauseList,Type);
transform_call(_Type,Line,_NoAbstractFun) ->
    throw({error,Line,?ERR_NOFUN}).

% Fixup semicolons in guards
ms_clause_expand({clause, Line, Parameters, Guard = [_,_|_], Body}) ->
    [ {clause, Line, Parameters, [X], Body} || X <- Guard ];
ms_clause_expand(_Other) ->
    false.

ms_clause_list(Line,[H|T],Type) ->
    case ms_clause_expand(H) of
	NewHead when is_list(NewHead) ->
	    ms_clause_list(Line,NewHead ++ T, Type);
	false ->
	    {cons, Line, ms_clause(H,Type), ms_clause_list(Line, T,Type)}
    end;
ms_clause_list(Line,[],_) ->
    {nil,Line}.
ms_clause({clause, Line, Parameters, Guards, Body},Type) ->
    check_type(Line,Parameters,Type),
    {MSHead,Bindings} = transform_head(Parameters),
    MSGuards = transform_guards(Line, Guards, Bindings),
    MSBody = transform_body(Line,Body,Bindings),
    {tuple, Line, [MSHead,MSGuards,MSBody]}.


check_type(_,[{var,_,_}],_) ->
    ok;
check_type(_,[{tuple,_,_}],ets) ->
    ok;
check_type(_,[{record,_,_,_}],ets) ->
    ok;
check_type(_,[{cons,_,_,_}],dbg) ->
    ok;
check_type(Line0,[{match,_,{var,_,_},X}],Any) ->
    check_type(Line0,[X],Any);
check_type(Line0,[{match,_,X,{var,_,_}}],Any) ->
    check_type(Line0,[X],Any);
check_type(Line,_Type,ets) ->
    throw({error,Line,?ERR_ETS_HEAD});
check_type(Line,_,dbg) ->
    throw({error,Line,?ERR_DBG_HEAD}).

-record(tgd,{ b, %Bindings 
	      p, %Part of spec
	      eb %Error code base, 0 for guards, 100 for bodies
	     }).

transform_guards(Line,[],_Bindings) ->
    {nil,Line};
transform_guards(Line,[G],Bindings) ->
    B = #tgd{b = Bindings, p = guard, eb = ?ERROR_BASE_GUARD},
    tg0(Line,G,B);
transform_guards(Line,_,_) ->
    throw({error,Line,?ERR_SEMI_GUARD}).
    
transform_body(Line,Body,Bindings) ->
    B = #tgd{b = Bindings, p = body, eb = ?ERROR_BASE_BODY},
    tg0(Line,Body,B).
    

guard_top_trans({call,Line0,{atom,Line1,OldTest},Params}) ->
    case old_bool_test(OldTest,length(Params)) of
	undefined ->
	    {call,Line0,{atom,Line1,OldTest},Params};
	Trans ->
	    {call,Line0,{atom,Line1,Trans},Params}
    end;
guard_top_trans(Else) ->
    Else.

tg0(Line,[],_) ->
    {nil,Line};
tg0(Line,[H0|T],B) when B#tgd.p =:= guard ->
    H = guard_top_trans(H0),
    {cons,Line, tg(H,B), tg0(Line,T,B)};
tg0(Line,[H|T],B) ->
    {cons,Line, tg(H,B), tg0(Line,T,B)}.
    

tg({match,Line,_,_},B) -> 
    throw({error,Line,?ERR_GENMATCH+B#tgd.eb});
tg({op, Line, Operator, O1, O2}, B) ->
    case {B#tgd.p,disallowed_in_guard(Operator,2)} of
	{guard, true} ->
	   throw({error,Line,{?ERR_GUARDDISALLOWEDOP,Operator}});
	_ ->
	    {tuple, Line, [{atom, Line, Operator}, tg(O1,B), tg(O2,B)]}
    end;
tg({op, Line, Operator, O1}, B) ->
    {tuple, Line, [{atom, Line, Operator}, tg(O1,B)]};
tg({call, _Line, {atom, Line2, bindings},[]},_B) ->
    	    {atom, Line2, '$*'};
tg({call, _Line, {atom, Line2, object},[]},_B) ->
    	    {atom, Line2, '$_'};
tg({call, Line, {atom, _, is_record}=Call,[Object, {atom,Line3,RName}=R]},B) ->
    MSObject = tg(Object,B),
    RDefs = get_records(),
    case lists:keysearch(RName,1,RDefs) of
	{value, {RName, FieldList}} ->
	    RSize = length(FieldList)+1,
	    {tuple, Line, [Call, MSObject, R, {integer, Line3, RSize}]};
	_ ->
	    throw({error,Line3,{?ERR_GENBADREC+B#tgd.eb,RName}})
    end;
tg({call, Line, {atom, Line2, FunName},ParaList},B) ->
    case is_ms_function(FunName,length(ParaList), B#tgd.p) of
	true ->
	    {tuple, Line, [{atom, Line2, FunName} | 
			   lists:map(fun(X) -> tg(X,B) end, ParaList)]};
	_ ->
	    throw({error,Line,{?ERR_GENLOCALCALL+B#tgd.eb,
			       FunName,length(ParaList)}}) 
    end;
tg({call, Line, {remote,_,{atom,_,erlang},{atom, Line2, FunName}},ParaList},
   B) ->
    L = length(ParaList),
    case is_imported_from_erlang(FunName,L,B#tgd.p) of
	true ->
	    case is_operator(FunName,L,B#tgd.p) of
		false ->
		    tg({call, Line, {atom, Line2, FunName},ParaList},B);
		true ->
		    tg(list_to_tuple([op,Line2,FunName | ParaList]),B)
		end;
	_ ->
	    throw({error,Line,{?ERR_GENREMOTECALL+B#tgd.eb,erlang,
			       FunName,length(ParaList)}}) 
    end;
tg({call, Line, {remote,_,{atom,_,ModuleName},
		 {atom, _, FunName}},_ParaList},B) ->
    throw({error,Line,{?ERR_GENREMOTECALL+B#tgd.eb,ModuleName,FunName}});
tg({cons,Line, H, T},B) -> 
    {cons, Line, tg(H,B), tg(T,B)};
tg({nil, Line},_B) ->
    {nil, Line};
tg({tuple,Line,L},B) ->
    {tuple,Line,[{tuple,Line,lists:map(fun(X) -> tg(X,B) end, L)}]};
tg({integer,Line,I},_) ->
    {integer,Line,I};
tg({char,Line,C},_) ->
    {char,Line,C};
tg({float, Line,F},_) ->
    {float,Line,F};
tg({atom,Line,A},_) ->
    case atom_to_list(A) of
	[$$|_] ->
	   {tuple, Line,[{atom, Line, 'const'},{atom,Line,A}]};
	_ ->
	    {atom,Line,A}
    end;
tg({string,Line,S},_) ->
    {string,Line,S};
tg({var,Line,VarName},B) ->
    case lkup_bind(VarName, B#tgd.b) of
	undefined ->
	    {tuple, Line,[{atom, Line, 'const'},{var,Line,VarName}]};
	AtomName ->
	    {atom, Line, AtomName}
    end;
tg({record_field,Line,Object,RName,{atom,_Line1,KeyName}},B) ->
    RDefs = get_records(),
    case lists:keysearch(RName,1,RDefs) of
	{value, {RName, FieldList}} ->
	    case lists:keysearch(KeyName,1, FieldList) of
		{value, {KeyName,Position,_}} ->
		    NewObject = tg(Object,B),
		    {tuple, Line, [{atom, Line, 'element'}, 
				   {integer, Line, Position}, NewObject]};
		_ ->
		    throw({error,Line,{?ERR_GENBADFIELD+B#tgd.eb, RName, 
				       KeyName}})
	    end;
	_ ->
	    throw({error,Line,{?ERR_GENBADREC+B#tgd.eb,RName}})
    end;

tg({record,Line,RName,RFields},B) ->
    RDefs = get_records(),
    KeyList0 = lists:foldl(fun({record_field,_,{atom,_,Key},Value},
				     L) ->
					 NV = tg(Value,B),
					 [{Key,NV}|L];
				    ({record_field,_,{var,_,'_'},Value},
				     L) ->
					 NV = tg(Value,B),
					 [{{default},NV}|L];
				    (_,_) ->
					 throw({error,Line,
						{?ERR_GENBADREC+B#tgd.eb,
						 RName}})
				 end,
				 [],
				 RFields),
    DefValue = case lists:keysearch({default},1,KeyList0) of
		   {value,{{default},OverriddenDefValue}} ->
		       {true,OverriddenDefValue};
		   _ ->
		       false
	       end,
    KeyList = lists:keydelete({default},1,KeyList0),
    case lists:keysearch({default},1,KeyList) of
	{value,{{default},_}} ->
	    throw({error,Line,{?ERR_GENMULTIFIELD+B#tgd.eb,RName,'_'}});
	_ ->
	    ok
    end,
    case lists:keysearch(RName,1,RDefs) of
	{value, {RName, FieldList0}} ->
	    FieldList1 = lists:foldl(
			   fun({FN,_,Def},Acc) ->
				   El = case lists:keysearch(FN,1,KeyList) of
					    {value, {FN, X0}} ->
						X0;
					    _ ->
						case DefValue of 
						    {true,Overridden} ->
							Overridden;
						    false ->
							Def
						end
					end,
				   [El | Acc]
			   end,
			   [],
			   FieldList0),
	    check_multi_field(RName,Line,KeyList,
				 ?ERR_GENMULTIFIELD+B#tgd.eb),
	    check_undef_field(RName,Line,KeyList,FieldList0,
			      ?ERR_GENBADFIELD+B#tgd.eb),
	    {tuple,Line,[{tuple,Line,[{atom,Line,RName}|FieldList1]}]};
	_ ->
	    throw({error,Line,{?ERR_GENBADREC+B#tgd.eb,RName}})
    end;

tg({record_index,Line,RName,{atom,Line2,KeyName}},B) ->
    RDefs = get_records(), 
    case lists:keysearch(RName,1,RDefs) of
	{value, {RName, FieldList}} ->
	    case lists:keysearch(KeyName,1, FieldList) of
		{value, {KeyName,Position,_}} ->
		    {integer, Line2, Position};
		_ ->
		    throw({error,Line2,{?ERR_GENBADFIELD+B#tgd.eb, RName, 
				       KeyName}})
	    end;
	_ ->
	    throw({error,Line,{?ERR_GENBADREC+B#tgd.eb,RName}})
    end;

tg({record,Line,{var,Line2,_VName}=AVName, RName,RFields},B) ->
    RDefs = get_records(),
    MSVName = tg(AVName,B),
    KeyList = lists:foldl(fun({record_field,_,{atom,_,Key},Value},
				     L) ->
					 NV = tg(Value,B),
					 [{Key,NV}|L];
				    (_,_) ->
					 throw({error,Line,?ERR_HEADBADREC})
				 end,
				 [],
				 RFields),
    case lists:keysearch(RName,1,RDefs) of
	{value, {RName, FieldList0}} ->
	    FieldList1 = lists:foldl(
			   fun({FN,Pos,_},Acc) ->
				   El = case lists:keysearch(FN,1,KeyList) of
					    {value, {FN, X0}} ->
						X0;
					    _ ->
						{tuple, Line2, 
						 [{atom, Line2, element},
						  {integer, Line2, Pos},
						  MSVName]}
					end,
				   [El | Acc]
			   end,
			   [],
			   FieldList0),
	    check_multi_field(RName,Line,KeyList,
				 ?ERR_GENMULTIFIELD+B#tgd.eb),
	    check_undef_field(RName,Line,KeyList,FieldList0,
			      ?ERR_GENBADFIELD+B#tgd.eb),
	    {tuple,Line,[{tuple,Line,[{atom,Line,RName}|FieldList1]}]};
	_ ->
	    throw({error,Line,{?ERR_GENBADREC+B#tgd.eb,RName}})
    end;

tg({bin_element,_Line0,{var, Line, A},_,_} = Whole,B) ->
    case lkup_bind(A, B#tgd.b) of
	undefined ->
	    Whole; % exists in environment hopefully
	_AtomName ->
	    throw({error,Line,{?ERR_GENBINCONSTRUCT+B#tgd.eb,A}})
    end;    
tg(default,_B) ->
    default;
tg({bin_element,Line,X,Y,Z},B) ->
    {bin_element, Line, tg(X,B), tg(Y,B), Z};

tg({bin,Line,List},B) ->
    {bin,Line,[tg(X,B) || X <- List]};
    
tg(T,B) when is_tuple(T), size(T) >= 2 ->
    Element = element(1,T),
    Line = element(2,T),
    throw({error,Line,{?ERR_GENELEMENT+B#tgd.eb,
		       translate_language_element(Element)}}); 
tg(Other,B) ->
    Element = io_lib:format("unknown element ~w", [Other]),
    throw({error,unknown,{?ERR_GENELEMENT+B#tgd.eb,Element}}).

transform_head([V]) ->
    Bind = cre_bind(),
    {NewV,NewBind} = toplevel_head_match(V,Bind),
    th(NewV,NewBind).


toplevel_head_match({match,_,{var,_,VName},Expr},B) ->
    {Expr,new_bind({VName,'$_'},B)};
toplevel_head_match({match,_,Expr,{var,_,VName}},B) ->
    {Expr,new_bind({VName,'$_'},B)};
toplevel_head_match(Other,B) ->
    {Other,B}.

th({record,Line,RName,RFields},B) ->
    % youch...
    RDefs = get_records(),
    {KeyList0,NewB} = lists:foldl(fun({record_field,_,{atom,_,Key},Value},
				     {L,B0}) ->
					 {NV,B1} = th(Value,B0),
					 {[{Key,NV}|L],B1};
				    ({record_field,_,{var,_,'_'},Value},
				     {L,B0}) ->
					 {NV,B1} = th(Value,B0),
					 {[{{default},NV}|L],B1};
				    (_,_) ->
					 throw({error,Line,{?ERR_HEADBADREC,
							    RName}})
				 end,
				 {[],B},
				 RFields),
    DefValue = case lists:keysearch({default},1,KeyList0) of
		   {value,{{default},OverriddenDefValue}} ->
		       OverriddenDefValue;
		   _ ->
		       {atom,Line,'_'}
	       end,
    KeyList = lists:keydelete({default},1,KeyList0),
    case lists:keysearch({default},1,KeyList) of
	{value,{{default},_}} ->
	    throw({error,Line,{?ERR_HEADMULTIFIELD,RName,'_'}});
	_ ->
	    ok
    end,
    case lists:keysearch(RName,1,RDefs) of
	{value, {RName, FieldList0}} ->
	    FieldList1 = lists:foldl(
			   fun({FN,_,_},Acc) ->
				   El = case lists:keysearch(FN,1,KeyList) of
					    {value, {FN, X0}} ->
						X0;
					    _ ->
						DefValue
					end,
				   [El | Acc]
			   end,
			   [],
			   FieldList0),
	    check_multi_field(RName,Line,KeyList,
				 ?ERR_HEADMULTIFIELD),
	    check_undef_field(RName,Line,KeyList,FieldList0,
			      ?ERR_HEADBADFIELD),
	    {{tuple,Line,[{atom,Line,RName}|FieldList1]},NewB};
	_ ->
	    throw({error,Line,{?ERR_HEADBADREC,RName}})
    end;

th({match,Line,_,_},_) -> 
    throw({error,Line,?ERR_HEADMATCH});
th({atom,Line,A},B) ->
    case atom_to_list(A) of
	[$$|NL] ->
	    case (catch list_to_integer(NL)) of
		N when is_integer(N) ->
		    throw({error,Line,{?ERR_HEADDOLLARATOM,A}});
		_ ->
		    {{atom,Line,A},B}
	    end;
	_ ->
	    {{atom,Line,A},B}
    end;
th({bin_element,_Line0,{var, Line, A},_,_},_) ->
    throw({error,Line,{?ERR_HEADBINMATCH,A}});

th({var,Line,Name},B) ->
    case lkup_bind(Name,B) of
	undefined ->
	    NewB = new_bind(Name,B),
	    {{atom,Line,lkup_bind(Name,NewB)},NewB};
	Trans ->
	    {{atom,Line,Trans},B}
    end;
th([H|T],B) ->
    {NH,NB} = th(H,B),
    {NT,NNB} = th(T,NB),
    {[NH|NT],NNB};
th(T,B) when is_tuple(T) ->
    {L,NB} = th(tuple_to_list(T),B),
    {list_to_tuple(L),NB};
th(Nonstruct,B) ->
    {Nonstruct,B}.
% Could be more efficient...
check_multi_field(_,_,[],_) ->
    ok;
check_multi_field(RName, Line, [{Key,_}|T], ErrCode) ->
    case lists:keysearch(Key,1,T) of
	{value,_} ->
	    throw({error,Line,{ErrCode,RName,Key}});
	_ ->
	    check_multi_field(RName, Line, T, ErrCode)
    end.
check_undef_field(_,_,[],_,_) ->
    ok;
check_undef_field(RName, Line, [{Key,_}|T], FieldList, ErrCode) ->
    case lists:keysearch(Key,1,FieldList) of
	{value,_} ->
	    check_undef_field(RName, Line, T, FieldList, ErrCode); 
	_ ->
	    throw({error,Line,{ErrCode,RName,Key}})
    end.

cre_bind() ->
    {1,[{'_','_'}]}.
lkup_bind(Name,{_,List}) ->
    case lists:keysearch(Name,1,List) of
	{value, {Name, Trans}} ->
	    Trans;
	_ ->
	    undefined
    end.
new_bind({Name,Trans},{Next,L}) ->
    {Next,[{Name,Trans}|L]};
new_bind(Name,{Next,L}) ->
    Trans = list_to_atom([$$|integer_to_list(Next)]),
    {Next+1,[{Name,Trans}|L]}.

translate_language_element(Atom) ->
    Transtab = [
		{lc,"list comprehension"},
		{block, "begin/end block"},
		{'if', "if"},
		{'case', "case"},
		{'receive', "receive"},
		{'try', "try"},
		{'catch', "catch"},
		{'match', "match (=)"},
		{remote, "external function call"}
	       ],
    case lists:keysearch(Atom,1,Transtab) of
	{value,{Atom, String}} ->
	    String;
	_ ->
	    atom_to_list(Atom)
    end.

old_bool_test(atom,1) -> is_atom;
old_bool_test(constant,1) -> is_constant;
old_bool_test(float,1) -> is_float;
old_bool_test(integer,1) -> is_integer;
old_bool_test(list,1) -> is_list;
old_bool_test(number,1) -> is_number;
old_bool_test(pid,1) -> is_pid;
old_bool_test(port,1) -> is_port;
old_bool_test(reference,1) -> is_reference;
old_bool_test(tuple,1) -> is_tuple;
old_bool_test(binary,1) -> is_binary;
old_bool_test(function,1) -> is_function;
old_bool_test(record,2) -> is_record;
old_bool_test(_,_) -> undefined.

bool_test(is_atom,1) -> true;
bool_test(is_constant,1) -> true;
bool_test(is_float,1) -> true;
bool_test(is_integer,1) -> true;
bool_test(is_list,1) -> true;
bool_test(is_number,1) -> true;
bool_test(is_pid,1) -> true;
bool_test(is_port,1) -> true;
bool_test(is_reference,1) -> true;
bool_test(is_tuple,1) -> true;
bool_test(is_binary,1) -> true;
bool_test(is_function,1) -> true;
bool_test(is_record,2) -> true;
bool_test(is_seq_trace,0) -> true;
bool_test(_,_) -> false.

real_guard_function(abs,1) -> true;
real_guard_function(element,2) -> true;
real_guard_function(hd,1) -> true;
real_guard_function(length,1) -> true;
real_guard_function(node,0) -> true;
real_guard_function(node,1) -> true;
real_guard_function(round,1) -> true;
real_guard_function(size,1) -> true;
real_guard_function(tl,1) -> true;
real_guard_function(trunc,1) -> true;
real_guard_function(self,0) -> true;
real_guard_function(_,_) -> false.

pseudo_guard_function(get_tcw,0) -> true;
pseudo_guard_function(_,_) -> false.

guard_function(X,A) ->
    real_guard_function(X,A) or pseudo_guard_function(X,A).

action_function(set_seq_token,2) -> true;
action_function(get_seq_token,0) -> true;
action_function(message,1) -> true;
action_function(return_trace,0) -> true;
action_function(process_dump,0) -> true;
action_function(enable_trace,1) -> true;
action_function(enable_trace,2) -> true;
action_function(disable_trace,1) -> true;
action_function(disable_trace,2) -> true;
action_function(display,1) -> true;
action_function(caller,0) -> true;
action_function(set_tcw,1) -> true;
action_function(silent,1) -> true;
action_function(_,_) -> false.

bool_operator('and',2) ->
    true;
bool_operator('or',2) ->
    true;
bool_operator('xor',2) ->
    true;
bool_operator('not',1) ->
    true;
bool_operator('andalso',2) ->
    true;
bool_operator('orelse',2) ->
    true;
bool_operator(_,_) ->
    false.

disallowed_in_guard('andalso',2) ->
    true;
disallowed_in_guard('orelse',2) ->
    true;
disallowed_in_guard(_,_) ->
    false.

arith_operator('+',1) ->
    true;
arith_operator('+',2) ->
    true;
arith_operator('-',1) ->
    true;
arith_operator('-',2) ->
    true;
arith_operator('*',2) ->
    true;
arith_operator('/',2) ->
    true;
arith_operator('div',2) ->
    true;
arith_operator('rem',2) ->
    true;
arith_operator('band',2) ->
    true;
arith_operator('bor',2) ->
    true;
arith_operator('bxor',2) ->
    true;
arith_operator('bnot',1) ->
    true;
arith_operator('bsl',2) ->
    true;
arith_operator('bsr',2) ->
    true;
arith_operator(_,_) ->
    false.

cmp_operator('>',2) ->
    true;
cmp_operator('>=',2) ->
    true;
cmp_operator('<',2) ->
    true;
cmp_operator('=<',2) ->
    true;
cmp_operator('==',2) ->
    true;
cmp_operator('=:=',2) ->
    true;
cmp_operator('/=',2) -> 
    true;
cmp_operator('=/=',2) ->
    true;
cmp_operator(_,_) ->
    false.

is_operator(X,A,_) ->
    bool_operator(X,A) or arith_operator(X,A) or cmp_operator(X,A).

is_imported_from_erlang(X,A,_) ->
    real_guard_function(X,A) or bool_test(X,A) or bool_operator(X,A) or
    arith_operator(X,A) or cmp_operator(X,A).

is_ms_function(X,A,body) ->
    action_function(X,A) or guard_function(X,A) or bool_test(X,A);

is_ms_function(X,A,guard) ->
    guard_function(X,A) or bool_test(X,A).

fixup_environment(L,B) when is_list(L) ->    
    lists:map(fun(X) ->
		      fixup_environment(X,B) 
	      end,
	      L);
fixup_environment({var,Line,Name},B) ->
    case lists:keysearch(Name,1,B) of
	{value,{Name,Value}} -> 
	    freeze(Line,Value);
	_ ->
	    throw({error,Line,{?ERR_UNBOUND_VARIABLE,atom_to_list(Name)}})
    end;
fixup_environment(T,B) when is_tuple(T) ->
    list_to_tuple(
      lists:map(fun(X) ->
			fixup_environment(X,B) 
		end,
		tuple_to_list(T)));
fixup_environment(Other,_B) ->
    Other.
    
freeze(Line,Term) ->
    {frozen,Line,Term}.

% Most of this is bluntly stolen from erl_parse.

normalise({frozen,_,Term}) ->
    Term;
normalise({char,_,C}) -> C;
normalise({integer,_,I}) -> I;
normalise({float,_,F}) -> F;
normalise({atom,_,A}) -> A;
normalise({string,_,S}) -> S;
normalise({nil,_}) -> [];
normalise({bin,_,Fs}) ->
    {value, B, _} =
	eval_bits:expr_grp(Fs, [],
			   fun(E, _) ->
				   {value, normalise(E), []}
			   end, [], true),
    B;
normalise({cons,_,Head,Tail}) ->
    [normalise(Head)|normalise(Tail)];
normalise({tuple,_,Args}) ->
    list_to_tuple(normalise_list(Args));
%% Special case for unary +/-.
normalise({op,_,'+',{char,_,I}}) -> I;
normalise({op,_,'+',{integer,_,I}}) -> I;
normalise({op,_,'+',{float,_,F}}) -> F;
normalise({op,_,'-',{char,_,I}}) -> -I;		%Weird, but compatible!
normalise({op,_,'-',{integer,_,I}}) -> -I;
normalise({op,_,'-',{float,_,F}}) -> -F.

normalise_list([H|T]) ->
    [normalise(H)|normalise_list(T)];
normalise_list([]) ->
    [].

