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
%% Copyright 2006, Tobias Lindahl and Kostis Sagonas
%% 
%%     $Id$
%%

%%%-------------------------------------------------------------------
%%% File    : dialyzer_dep.erl
%%% Author  : Tobias Lindahl <tobiasl@it.uu.se>
%%%
%%% Description: A pretty limited but efficient escape/dependency
%%%              analysis of Core Erlang.
%%%
%%% Created : 28 Oct 2005 by Tobias Lindahl <tobiasl@it.uu.se>
%%%-------------------------------------------------------------------
-module(dialyzer_dep).

-define(NO_UNUSED, true).

-export([analyze/1]).
-ifndef(NO_UNUSED).
-export([test/1]).
-endif.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% analyze(CoreTree) -> {Deps, Esc, Calls}.
%%                
%% Deps =  a dict mapping labels of functions to a ordset of functions it calls.
%%
%% Esc =   a set (ordsets) of the labels of escaping functions. A function
%%         is considered to escape if the control escapes a function,
%%         i.e., this analysis is not module-local but rather
%%         function-local.
%%
%% Calls = a dict mapping apply:s to a ordset of function labels to which
%%         the operation can refer to. If 'external' is part of the
%%         set the operation can be externally defined.
%%

analyze(Tree) ->
  %%io:format("Handling ~w\n", [cerl:atom_val(cerl:module_name(Tree))]),
  {_, State} = traverse(Tree, map__new(), state__new(Tree), top),
  Esc = state__esc(State), 
  %% Add dependency from 'external' to all escaping function
  State1 = state__add_deps(external, output(Esc), State),
  Deps = state__deps(State1),
  Calls = state__calls(State1),
  {map__finalize(Deps), set__to_ordsets(Esc), map__finalize(Calls)}.

traverse(Tree, Out, State, CurrentFun) ->
  %%io:format("Type: ~w\n", [cerl:type(Tree)]),
  case cerl:type(Tree) of
    apply ->
      Op = cerl:apply_op(Tree),
      Args = cerl:apply_args(Tree),
      %% Op is always a variable and should not be marked as escaping
      %% based on its use.
      case var =:= cerl:type(Op) of
	false -> erlang:fault({apply_op_not_a_variable, cerl:type(Op)});
	true -> ok
      end,
      OpFuns = case map__lookup(cerl_trees:get_label(Op), Out) of
		 none -> output(none);
		 {value, OF} -> OF
	       end,
      {ArgFuns, State2} = traverse_list(Args, Out, State, CurrentFun),
      State3 = state__add_esc(merge_outs(ArgFuns), State2),
      State4 = state__add_deps(CurrentFun, OpFuns, State3),
      State5 = state__store_callsite(cerl_trees:get_label(Tree), OpFuns,State4),
      {output(set__singleton(external)), State5};
    binary ->
      {output(none), State};
    'case' ->
      Arg = cerl:case_arg(Tree),
      {Funs, NewState} = traverse(Arg, Out, State, CurrentFun),
      Clauses = cerl:case_clauses(Tree),
      traverse_clauses(Clauses, Funs, Out, NewState, CurrentFun);
    call ->
      Args = cerl:call_args(Tree),
      {ArgFuns, State1} = traverse_list(Args, Out, State, CurrentFun),
      remote_call(Tree, merge_outs(ArgFuns), State1);
    'catch' ->
      traverse(cerl:catch_body(Tree), Out, State, CurrentFun);
    cons ->
      {HdFuns, State1} = traverse(cerl:cons_hd(Tree), Out, State, CurrentFun),
      {TlFuns, State2} = traverse(cerl:cons_tl(Tree), Out, State1, CurrentFun),
      {merge_outs([HdFuns, TlFuns]), State2};
    'fun' ->
      %%io:format("Entering fun: ~w\n", [cerl_trees:get_label(Tree)]),
      Body = cerl:fun_body(Tree),
      Label = cerl_trees:get_label(Tree),
      if CurrentFun =:= top -> 
	  State1 = state__add_deps(top, output(set__singleton(Label)), State);
	 true -> 
	  O1 = output(set__singleton(CurrentFun)),
	  O2 = output(set__singleton(Label)),
	  TmpState = state__add_deps(Label, O1, State),
	  State1 = state__add_deps(CurrentFun, O2,TmpState)
      end,
      {BodyFuns, State2} = traverse(Body, Out, State1, 
				    cerl_trees:get_label(Tree)),
      {output(set__singleton(Label)), state__add_esc(BodyFuns, State2)};
    'let' ->
      Vars = cerl:let_vars(Tree),
      Arg = cerl:let_arg(Tree),
      Body = cerl:let_body(Tree),
      {ArgFuns, State1} = traverse(Arg, Out, State, CurrentFun),
      Out1 = bind_list(Vars, ArgFuns, Out),
      traverse(Body, Out1, State1, CurrentFun);
    letrec ->
      Defs = cerl:letrec_defs(Tree),
      Body = cerl:letrec_body(Tree),
      Out1 = bind_defs(Defs, Out),
      State1 = traverse_defs(Defs, Out1, State, CurrentFun),
      traverse(Body, Out1, State1, CurrentFun);
    literal ->
      {output(none), State};
    module ->
      Defs = cerl:module_defs(Tree),
      Out1 = bind_defs(Defs, Out),
      State1 = traverse_defs(Defs, Out1, State, CurrentFun),
      {output(none), State1};
    primop ->
      Args = cerl:primop_args(Tree),
      {ArgFuns, State1} = traverse_list(Args, Out, State, CurrentFun),
      primop(Tree, merge_outs(ArgFuns), State1);
    'receive' ->
      Clauses = cerl:receive_clauses(Tree),
      TimeOut = cerl:receive_timeout(Tree),
      Action = cerl:receive_action(Tree),
      {ClauseFuns, State1} = 
	traverse_clauses(Clauses, output(none), Out, State, CurrentFun),
      {_, State2} = traverse(TimeOut, Out, State1, CurrentFun),
      {ActionFuns, State3} = traverse(Action, Out, State2, CurrentFun),
      {merge_outs([ClauseFuns, ActionFuns]), State3};
    seq ->
      {_, State1} = traverse(cerl:seq_arg(Tree), Out, State, CurrentFun),
      traverse(cerl:seq_body(Tree), Out, State1, CurrentFun);
    'try' ->
      Arg = cerl:try_arg(Tree),
      Body = cerl:try_body(Tree),
      Vars = cerl:try_vars(Tree),
      EVars = cerl:try_evars(Tree),
      Handler = cerl:try_handler(Tree),
      {ArgFuns, State1} = traverse(Arg, Out, State, CurrentFun),
      Out1 = bind_list(Vars, ArgFuns, Out),
      {BodyFuns, State2} = traverse(Body, Out1, State1, CurrentFun),
      Out2 = bind_single(EVars, output(set__singleton(external)), Out),
      {HandlerFuns, State3} = traverse(Handler, Out2, State2, CurrentFun),
      {merge_outs([BodyFuns, HandlerFuns]), State3};
    tuple ->
      Args = cerl:tuple_es(Tree),
      {List, State1} = traverse_list(Args, Out, State, CurrentFun),
      {merge_outs(List), State1};
    values ->      
      traverse_list(cerl:values_es(Tree), Out, State, CurrentFun);
    var ->
      case map__lookup(cerl_trees:get_label(Tree), Out) of
	none -> {output(none), State};
	{value, Val} -> 
	  case is_only_external(Val) of
	    true ->
	      %% Do nothing
	      {Val, State};
	    false ->
	      %% If this is used in a function this means a dependency.
	      {Val, state__add_deps(CurrentFun, Val, State)}
	  end
      end
  end.

traverse_list(Trees, Out, State, CurrentFun) ->
  traverse_list(Trees, Out, State, CurrentFun, []).

traverse_list([Tree|Left], Out, State, CurrentFun, Acc) ->
  {X, State1} = traverse(Tree, Out, State, CurrentFun),
  traverse_list(Left, Out, State1, CurrentFun, [X|Acc]);
traverse_list([], _Out, State, _CurrentFun, Acc) ->
  {output(lists:reverse(Acc)), State}.

traverse_defs([{_, Fun}|Left], Out, State, CurrentFun) ->
  {_, State1} = traverse(Fun, Out, State, CurrentFun),
  traverse_defs(Left, Out, State1, CurrentFun);
traverse_defs([], _Out, State, _CurrentFun) ->
  State.

traverse_clauses(Clauses, ArgFuns, Out, State, CurrentFun) ->
  case filter_match_fail(Clauses) of
    [] ->
      %% Can happen for example with receives used as timouts.
      {output(none), State};
    Clauses1 ->
      traverse_clauses(Clauses1, ArgFuns, Out, State, CurrentFun, [])
  end.

traverse_clauses([Clause|Left], ArgFuns, Out, State, CurrentFun, Acc) ->
  Pats = cerl:clause_pats(Clause),
  Guard = cerl:clause_guard(Clause),
  Body = cerl:clause_body(Clause),
  Out1 = bind_pats_list(Pats, ArgFuns, Out),
  {_, State2} = traverse(Guard, Out1, State, CurrentFun),
  {BodyFuns, State3} = traverse(Body, Out1, State2, CurrentFun),
  traverse_clauses(Left, ArgFuns, Out, State3, CurrentFun, [BodyFuns|Acc]);
traverse_clauses([], _ArgFuns, _Out, State, _CurrentFun, Acc) ->
  {merge_outs(Acc), State}.

filter_match_fail([Clause]) ->
  Body = cerl:clause_body(Clause),
  case cerl:type(Body) of
    primop ->
      case cerl:atom_val(cerl:primop_name(Body)) of
	match_fail -> [];
	raise -> [];
	_ -> [Clause]
      end;
    _ -> [Clause]
  end;
filter_match_fail([H|T]) ->
  [H|filter_match_fail(T)];
filter_match_fail([]) ->
  %% This can actually happen, for example in 
  %%      receive after 1 -> ok end
  [].

remote_call(Tree, ArgFuns, State) ->  
  M = cerl:call_module(Tree),
  F = cerl:call_name(Tree),
  A = length(cerl:call_args(Tree)),
  case cerl:is_c_atom(M) andalso cerl:is_c_atom(F) of
    false ->
      %% Unknown function. 
      {output(set__singleton(external)), state__add_esc(ArgFuns, State)};
    true ->
      M1 = cerl:atom_val(M),
      F1 = cerl:atom_val(F),
      Literal = cerl_closurean:is_literal_op(M1, F1, A),
      case erl_bifs:is_pure(M1, F1, A) of
	true ->
	  case Literal of
	    true -> 
	      {output(none), State};
	    false -> 
	      {output(set__singleton(external)), state__add_esc(ArgFuns, State)}
	  end;
	false ->	  
	  State1 = case cerl_closurean:is_escape_op(M1, F1, A) of
		     true -> state__add_esc(ArgFuns, State);
		     false -> State
		   end,
	  case Literal of
	    true -> {output(none), State1};
	    false -> {add_external(ArgFuns), State1}
	  end
      end
  end.

primop(Tree, ArgFuns, State) ->
  F = cerl:atom_val(cerl:primop_name(Tree)),
  A = length(cerl:primop_args(Tree)),
  State1 = case cerl_closurean:is_escape_op(F, A) of
	     true -> state__add_esc(ArgFuns, State);
	     false -> State
	   end,
  case cerl_closurean:is_literal_op(F, A) of
    true -> {output(none), State1};
    false -> {ArgFuns, State1}
  end.

%%____________________________________________________________
%%
%% Set
%%

-record(set, {set}).

set__singleton(Val) ->
  #set{set=sets:add_element(Val, sets:new())}.

set__from_list(List) ->
  #set{set=sets:from_list(List)}.

set__is_element(_El, none) ->
  false;
set__is_element(El, #set{set=Set}) ->
  sets:is_element(El, Set).

set__union(none, X) -> X;
set__union(X, none) -> X;
set__union(#set{set=X}, #set{set=Y}) -> #set{set=sets:union(X, Y)}.

set__to_ordsets(none) -> [];
set__to_ordsets(#set{set=Set}) -> ordsets:from_list(sets:to_list(Set)).

set__size(none) -> 0;
set__size(#set{set=X}) -> sets:size(X).

%%____________________________________________________________
%%
%% Outputs
%%

%% #output{type = single|list, 
%%         content = #set{} | [#output{}] | none}

-record(output, {type, content}).

output(none) -> #output{type=single, content=none};
output(S = #set{}) -> #output{type=single, content=S};
output(List) when is_list(List) -> #output{type=list, content=List}.

merge_outs([H|T]) ->
  merge_outs(T, H);
merge_outs(#output{type=list, content=[H|T]}) ->
  merge_outs(T, H);
merge_outs(#output{type=list, content=[]}) ->
  output(none).

merge_outs([#output{content=none}|Left], O) ->
  merge_outs(Left, O);
merge_outs([O|Left], #output{content=none}) ->
  merge_outs(Left, O);
merge_outs([#output{type=single, content=S1}|Left], 
	   #output{type=single, content=S2}) ->
  merge_outs(Left, output(set__union(S1, S2)));
merge_outs([#output{type=list, content=L1}|Left],
	   #output{type=list, content=L2}) ->
  NewList = [merge_outs([X, Y]) || {X, Y} <- lists:zip(L1, L2)],
  merge_outs(Left, output(NewList));
merge_outs([], Res) ->
  Res.

add_external(#output{type=single, content=Set}) ->
  output(set__union(Set, set__singleton(external)));
add_external(#output{type=list, content=List}) ->
  output([add_external(O) || O <- List]).

is_only_external(#output{type=single, content=Set}) ->
  set__is_element(external, Set) andalso (set__size(Set) =:= 1).

%%____________________________________________________________
%%
%% Map
%%

map__new() ->
  dict:new().

map__add(_Label, none, Map) ->
  Map;
map__add(Label, Set, Map) ->
  case map__lookup(Label, Map) of
    {value, OldSet} ->
      NewSet = set__union(OldSet, Set),
      map__store(Label, NewSet, Map);
    none ->
      map__store(Label, Set, Map)
  end.

map__store(Label, Val, Map) ->  
  dict:store(Label, Val, Map).

map__lookup(Label, Map) ->
  case dict:find(Label, Map) of
    {ok, Val} -> {value, Val};
    error -> none
  end.

map__finalize(Map) ->
  dict:map(fun(_Key, Set = #set{}) -> set__to_ordsets(Set);
	      (_Key, #output{type=single, content=Set}) -> set__to_ordsets(Set)
	   end, Map).

%%____________________________________________________________
%%
%% Binding outs in the map
%%

bind_pats_list(_Pats, #output{content=none}, Map) ->
  Map;
bind_pats_list([Pat], O = #output{type=single}, Map) ->
  bind_single(all_vars(Pat), O, Map);
bind_pats_list(Pats, #output{type=list, content=List}, Map) ->
  bind_pats_list(Pats, List, Map);
bind_pats_list([Pat|PatLeft],
	       [O = #output{type=single}|SetLeft], Map)->
  Map1 = bind_single(all_vars(Pat), O, Map),
  bind_pats_list(PatLeft, SetLeft, Map1);
bind_pats_list([Pat|PatLeft],
	       [#output{type=list, content=List}|SetLeft], Map)->
  case cerl:is_c_values(Pat) of
    true -> Map1 = bind_pats_list(cerl:values_es(Pat), List, Map);
    false -> Map1 = bind_single(all_vars(Pat), merge_outs(List), Map)
  end,
  bind_pats_list(PatLeft, SetLeft, Map1);
bind_pats_list([], [], Map) ->
  Map.
  
bind_single([Var|Left], O, Map) ->
  bind_single(Left, O, map__store(cerl_trees:get_label(Var), O, Map));
bind_single([], _O, Map) ->
  Map.

bind_list(List, O = #output{type=single}, Map) ->
  bind_single(List, O, Map);
bind_list(List1, #output{type=list, content=List2}, Map) ->
  bind_list1(List1, List2, Map).

bind_list1([Var|VarLeft], [O|OLeft], Map) ->
  bind_list1(VarLeft, OLeft, map__store(cerl_trees:get_label(Var), O, Map));
bind_list1([], [], Map) ->
  Map.

bind_defs([{Var, Fun}|Left], Map) ->
  O = output(set__singleton(cerl_trees:get_label(Fun))),
  Map1 = map__store(cerl_trees:get_label(Var), O, Map),
  bind_defs(Left, Map1);
bind_defs([], Map) ->
  Map.

all_vars(Tree) ->
  all_vars(Tree, []).

all_vars(Tree, AccIn) ->
  cerl_trees:fold(fun(SubTree, Acc) ->
		      case cerl:is_c_var(SubTree) of
			true -> [SubTree|Acc];
			false -> Acc
		      end
		  end, AccIn, Tree).

%%____________________________________________________________
%%
%% The state

-record(state, {deps, esc, call}).

state__new(Tree) ->
  Exports = set__from_list([X || X <- cerl:module_exports(Tree)]),
  InitEsc = set__from_list([cerl_trees:get_label(Fun) 
			    || {Var, Fun} <- cerl:module_defs(Tree),
			       set__is_element(Var, Exports)]),
  #state{deps=map__new(), esc=InitEsc, call=map__new()}.

state__add_deps(_From, #output{content=none}, State) ->
  State;
state__add_deps(From, #output{type=single, content=To}, 
		State = #state{deps=Map}) ->
  %%io:format("Adding deps from ~w to ~w\n", [From, set__to_ordsets(To)]),
  State#state{deps=map__add(From, To, Map)}.

state__deps(#state{deps=Deps}) ->
  Deps.

state__add_esc(#output{content=none}, State) ->
  State;
state__add_esc(#output{type=single, content=Set}, State = #state{esc=Esc}) ->
  State#state{esc=set__union(Set, Esc)}.

state__esc(#state{esc=Esc}) ->
  Esc.

state__store_callsite(_From, #output{content=none}, State) ->
  State;
state__store_callsite(From, To, State = #state{call=Calls}) ->
  State#state{call=map__store(From, To, Calls)}.

state__calls(#state{call=Calls}) ->
  Calls.

%%____________________________________________________________
%%
%% A test function. Not part of the intended interface.
%%

-ifndef(NO_UNUSED).

test(Mod) ->
  {ok, _, Code} = compile:file(Mod, [to_core,binary]), 
  Tree = cerl:from_records(Code),
  {LabeledTree, _} = cerl_trees:label(Tree),

  %%io:put_chars(cerl_prettypr:format(LabeledTree)),
  %%io:nl(),

  {Deps, Esc, Calls} = analyze(LabeledTree),
  Edges0 = dict:fold(fun(Caller, Set, Acc) ->
			 [[{Caller, Callee} || Callee <- Set]|Acc]
		     end, [], Deps),
  Edges1 = lists:flatten(Edges0),
  Edges = [{X,Y} || {X,Y} <- Edges1, X =/= top],
  Fun = fun(SubTree, Acc) ->
	    case cerl:type(SubTree) of
	      'fun' ->
		case lists:keysearch(id, 1, cerl:get_ann(SubTree)) of
		  false -> Acc;
		  {value, {id, ID}} -> 
		    dict:store(cerl_trees:get_label(SubTree), ID, Acc)
		end;
	      module ->
		Defs = cerl:module_defs(SubTree),
		lists:foldl(fun({Var, Fun}, Acc1) ->
				dict:store(cerl_trees:get_label(Fun),
					   {cerl:fname_id(Var), 
					    cerl:fname_arity(Var)},
					   Acc1)
			    end, Acc, Defs);
	      letrec ->
		Defs = cerl:letrec_defs(SubTree),
		lists:foldl(fun({Var, Fun}, Acc1) ->
				dict:store(cerl_trees:get_label(Fun),
					   {cerl:fname_id(Var), 
					    cerl:fname_arity(Var)},
					   Acc1)
			    end, Acc, Defs);
	      _ -> Acc
	    end
	end,
  NameMap1 = cerl_trees:fold(Fun, dict:new(), LabeledTree),
  NameMap = dict:store(external, external, NameMap1),
  NamedEdges = lists:map(fun({X, Y}) ->
			     {dict:fetch(X, NameMap), dict:fetch(Y, NameMap)}
			 end, Edges),
  NamedEsc = lists:map(fun(X) -> dict:fetch(X, NameMap) end, Esc),
  %% Color the edges
  ColorEsc = [{X, {color, red}} || X <- NamedEsc],

  CallEdges0 = dict:fold(fun(Caller, Set, Acc) ->
			     [[{Caller, Callee} || Callee <- Set]|Acc]
			 end, [], Calls),
  CallEdges = lists:flatten(CallEdges0),
  NamedCallEdges = lists:map(fun({X, Y}) ->
				 {X, dict:fetch(Y, NameMap)}
			     end, CallEdges),

  hipe_dot:translate_list(NamedEdges ++ NamedCallEdges, "/tmp/cg.dot", "CG", 
			  ColorEsc),
  os:cmd("dot -T ps -o /tmp/cg.ps /tmp/cg.dot"),

  ok.

-endif.
