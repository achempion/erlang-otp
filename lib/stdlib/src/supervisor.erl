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
-module(supervisor).

-behaviour(gen_server).

%% External exports
-export([start_link/2,start_link/3,
	 start_child/2, restart_child/2,
	 delete_child/2, terminate_child/2,
	 which_children/1,
	 check_childspecs/1]).

-export([behaviour_info/1]).

%% Internal exports
-export([init/1, handle_call/3, handle_info/2, terminate/2, code_change/3]).
-export([handle_cast/2]).

-record(state, {name,
		strategy,
		children = [],
		dynamics = [],
		intensity,
		period,
		restarts = [],
	        module,
	        args}).

-record(child, {pid = undefined,  % pid is undefined when child is not running
		name,
		mfa,
		restart_type,
		shutdown,
		child_type,
		modules = []}).

-define(is_simple(State), State#state.strategy == simple_one_for_one).

behaviour_info(callbacks) ->
    [{init,1}];
behaviour_info(Other) ->
    undefined.

%%% ---------------------------------------------------
%%% This is a general process supervisor built upon gen_server.erl.
%%% Servers/processes should/could also be built using gen_server.erl.
%%% SupName = {local, atom()} | {global, atom()}.
%%% ---------------------------------------------------
start_link(Mod, Args) ->
    gen_server:start_link(supervisor, {self, Mod, Args}, []).
 
start_link(SupName, Mod, Args) ->
    gen_server:start_link(SupName, supervisor, {SupName, Mod, Args}, []).
 
%%% ---------------------------------------------------
%%% Interface functions.
%%% ---------------------------------------------------
start_child(Supervisor, ChildSpec) ->
    call(Supervisor, {start_child, ChildSpec}).

restart_child(Supervisor, Name) ->
    call(Supervisor, {restart_child, Name}).

delete_child(Supervisor, Name) ->
    call(Supervisor, {delete_child, Name}).

%%-----------------------------------------------------------------
%% Func: terminate_child/2
%% Returns: ok | {error, Reason}
%%          Note that the child is *always* terminated in some
%%          way (maybe killed).
%%-----------------------------------------------------------------
terminate_child(Supervisor, Name) ->
    call(Supervisor, {terminate_child, Name}).

which_children(Supervisor) ->
    call(Supervisor, which_children).

call(Supervisor, Req) ->
    gen_server:call(Supervisor, Req, infinity).

check_childspecs(ChildSpecs) when list(ChildSpecs) ->
    case check_startspec(ChildSpecs) of
	{ok, _} -> ok;
	Error -> {error, Error}
    end;
check_childspecs(X) -> {error, {badarg, X}}.

%%% ---------------------------------------------------
%%% 
%%% Initialize the supervisor.
%%% 
%%% ---------------------------------------------------
init({SupName, Mod, Args}) ->
    process_flag(trap_exit, true),
    case apply(Mod, init, [Args]) of
	{ok, {SupFlags, StartSpec}} ->
	    case init_state(SupName, SupFlags, Mod, Args) of
		{ok, State} when ?is_simple(State) ->
		    init_dynamic(State, StartSpec);
		{ok, State} ->
		    init_children(State, StartSpec);
		Error ->
		    {stop, {supervisor_data, Error}}
	    end;
	ignore ->
	    ignore;
	Error ->
	    {stop, {bad_return, {Mod, init, Error}}}
    end.
	
init_children(State, StartSpec) ->
    SupName = State#state.name,
    case check_startspec(StartSpec) of
        {ok, Children} ->
            case start_children(Children, SupName) of
                {ok, NChildren} ->
                    {ok, State#state{children = NChildren}};
                {error, NChildren} ->
                    terminate_children(NChildren, SupName),
                    {stop, shutdown}
            end;
        Error ->
            {stop, {start_spec, Error}}
    end.

init_dynamic(State, [StartSpec]) ->
    SupName = State#state.name,
    case check_startspec([StartSpec]) of
        {ok, Children} ->
	    {ok, State#state{children = Children}};
        Error ->
            {stop, {start_spec, Error}}
    end;
init_dynamic(State, StartSpec) ->
    {stop, {bad_start_spec, StartSpec}}.

%%-----------------------------------------------------------------
%% Func: start_children/2
%% Args: Children = [#child] in start order
%%       SupName = {local, atom()} | {global, atom()} | {pid(),Mod}
%% Purpose: Start all children.  The new list contains #child's 
%%          with pids.
%% Returns: {ok, NChildren} | {error, NChildren}
%%          NChildren = [#child] in termination order (reversed
%%                        start order)
%%-----------------------------------------------------------------
start_children(Children, SupName) -> start_children(Children, [], SupName).

start_children([Child|Chs], NChildren, SupName) ->
    case do_start_child(SupName, Child) of
	{ok, Pid} ->
	    start_children(Chs, [Child#child{pid = Pid}|NChildren], SupName);
	{ok, Pid, _Extra} ->
	    start_children(Chs, [Child#child{pid = Pid}|NChildren], SupName);
	{error, Reason} ->
	    report_error(start_error, Reason, Child, SupName),
	    {error, lists:reverse(Chs) ++ [Child | NChildren]}
    end;
start_children([], NChildren, _SupName) ->
    {ok, NChildren}.

do_start_child(SupName, Child) ->
    #child{mfa = {M, F, A}} = Child,
    case catch apply(M, F, A) of
	{ok, Pid} when pid(Pid) ->
	    NChild = Child#child{pid = Pid},
	    report_progress(NChild, SupName),
	    {ok, Pid};
	{ok, Pid, Extra} when pid(Pid) ->
	    NChild = Child#child{pid = Pid},
	    report_progress(NChild, SupName),
	    {ok, Pid, Extra};
	ignore -> 
	    NChild = Child#child{pid = undefined},
	    {ok, undefined};
	{error, What} -> {error, What};
	What -> {error, What}
    end.

do_start_child_i(M, F, A) ->
    case catch apply(M, F, A) of
	{ok, Pid} when pid(Pid) ->
	    {ok, Pid};
	{ok, Pid, Extra} when pid(Pid) ->
	    {ok, Pid, Extra};
	ignore ->
	    {ok, undefined};
	{error, Error} ->
	    {error, Error};
	What ->
	    {error, What}
    end.
    

%%% ---------------------------------------------------
%%% 
%%% Callback functions.
%%% 
%%% ---------------------------------------------------
handle_call({start_child, EArgs}, _From, State) when ?is_simple(State) ->
    #child{mfa = {M, F, A}} = hd(State#state.children),
    Args = A ++ EArgs,
    case do_start_child_i(M, F, Args) of
	{ok, Pid} ->
	    NState = State#state{dynamics = [{Pid, Args}|State#state.dynamics]},
	    {reply, {ok, Pid}, NState};
	{ok, Pid, Extra} ->
	    NState = State#state{dynamics = [{Pid, Args}|State#state.dynamics]},
	    {reply, {ok, Pid, Extra}, NState};
	What ->
	    {reply, What, State}
    end;
handle_call({Req, Data}, _From, State) when ?is_simple(State) ->
    {reply, {error, simple_one_for_one}, State};
handle_call({start_child, ChildSpec}, _From, State) ->
    case check_childspec(ChildSpec) of
	{ok, Child} ->
	    {Resp, NState} = handle_start_child(Child, State),
	    {reply, Resp, NState};
	What ->
	    {reply, {error, What}, State}
    end;

handle_call({restart_child, Name}, _From, State) ->
    case get_child(Name, State) of
	{value, Child} when Child#child.pid == undefined ->
	    case do_start_child(State#state.name, Child) of
		{ok, Pid} ->
		    NState = replace_child(Child#child{pid = Pid}, State),
		    {reply, {ok, Pid}, NState};
		{ok, Pid, Extra} ->
		    NState = replace_child(Child#child{pid = Pid}, State),
		    {reply, {ok, Pid, Extra}, NState};
		Error ->
		    {reply, Error, State}
	    end;
	{value, _} ->
	    {reply, {error, running}, State};
	_ ->
	    {reply, {error, not_found}, State}
    end;

handle_call({delete_child, Name}, _From, State) ->
    case get_child(Name, State) of
	{value, Child} when Child#child.pid == undefined ->
	    NState = remove_child(Child, State),
	    {reply, ok, NState};
	{value, _} ->
	    {reply, {error, running}, State};
	_ ->
	    {reply, {error, not_found}, State}
    end;

handle_call({terminate_child, Name}, _From, State) ->
    case get_child(Name, State) of
	{value, Child} ->
	    NChild = do_terminate(Child, State#state.name),
	    {reply, ok, replace_child(NChild, State)};
	_ ->
	    {reply, {error, not_found}, State}
    end;

handle_call(which_children, _From, State) when ?is_simple(State) ->
    [#child{child_type = CT, modules = Mods}] = State#state.children,
    Reply = lists:map(fun({Pid, _}) -> {undefined, Pid, CT, Mods} end,
		      State#state.dynamics),
    {reply, Reply, State};

handle_call(which_children, _From, State) ->
    Resp =
	lists:map(fun(#child{pid = Pid, name = Name,
			     child_type = ChildType, modules = Mods}) ->
		    {Name, Pid, ChildType, Mods}
		  end,
		  State#state.children),
    {reply, Resp, State}.

%
% Take care of terminated children.
%
handle_info({'EXIT', Pid, Reason}, State) ->
    case restart_child(Pid, Reason, State) of
	{ok, State1} ->
	    {noreply, State1};
	{shutdown, State1} ->
	    {stop, shutdown, State1}
    end;

handle_info(_, State) ->
    {noreply, State}.

%
% Terminate this server.
%
terminate(_Reason, State) ->
    terminate_children(State#state.children, State#state.name),
    ok.

%
% Change code for the supervisor.
% Call the new call-back module and fetch the new start specification.
% Combine the new spec. with the old. If the new start spec. is
% not valid the code change will not succeed.
% Use the old Args as argument to Module:init/1.
% NOTE: This requires that the init function of the call-back module
%       does not have any side effects.
%
code_change(_, State, _) ->
    case apply(State#state.module, init,
	       [State#state.args]) of
	{ok, {SupFlags, StartSpec}} ->
	    case catch check_flags(SupFlags) of
		ok ->
		    {Strategy, MaxIntensity, Period} = SupFlags,
                    update_childspec(State#state{strategy = Strategy,
                                                 intensity = MaxIntensity,
                                                 period = Period},
                                     StartSpec);
		Error ->
		    {error, Error}
	    end;
	ignore ->
	    {ok, State};
	Error ->
	    Error
    end.

handle_cast(null, State) ->
    {noreply, State}.

check_flags({Strategy, MaxIntensity, Period}) ->
    validStrategy(Strategy),
    validIntensity(MaxIntensity),
    validPeriod(Period),
    ok;
check_flags(What) ->
    {bad_flags, What}.

update_childspec(State, StartSpec)  when ?is_simple(State) -> 
    case check_startspec(StartSpec) of                        
        {ok, [Child]} ->                                      
            {ok, State#state{children = [Child]}};            
        Error ->                                              
            {error, Error}                                    
    end;                                                      

update_childspec(State, StartSpec) ->
    case check_startspec(StartSpec) of
	{ok, Children} ->
	    OldC = State#state.children, % In reverse start order !
	    NewC = update_childspec1(OldC, Children, []),
	    {ok, State#state{children = NewC}};
        Error ->
	    {error, Error}
    end.

update_childspec1([Child|OldC], Children, KeepOld) ->
    case update_chsp(Child, Children) of
	{ok,NewChildren} ->
	    update_childspec1(OldC, NewChildren, KeepOld);
	false ->
	    update_childspec1(OldC, Children, [Child|KeepOld])
    end;
update_childspec1([], Children, KeepOld) ->
    % Return them in (keeped) reverse start order.
    lists:reverse(Children ++ KeepOld).  

update_chsp(OldCh, Children) ->
    case lists:map(fun(Ch) when OldCh#child.name == Ch#child.name ->
			   Ch#child{pid = OldCh#child.pid};
		      (Ch) ->
			   Ch
		   end,
		   Children) of
	Children ->
	    false;  % OldCh not found in new spec.
	NewC ->
	    {ok, NewC}
    end.
    
%%% ---------------------------------------------------
%%% Start a new child.
%%% ---------------------------------------------------

handle_start_child(Child, State) ->
    case get_child(Child#child.name, State) of
	false ->
	    case do_start_child(State#state.name, Child) of
		{ok, Pid} ->
		    Children = State#state.children,
		    {{ok, Pid},
		     State#state{children = [Child#child{pid = Pid}|Children]}};
		{ok, Pid, Extra} ->
		    Children = State#state.children,
		    {{ok, Pid, Extra},
		     State#state{children = [Child#child{pid = Pid}|Children]}};
		{error, What} ->
		    {{error, {What, Child}}, State}
	    end;
	{value, OldChild} when OldChild#child.pid /= undefined ->
	    {{error, {already_started, OldChild#child.pid}}, State};
	{value, OldChild} ->
	    {{error, already_present}, State}
    end.

%%% ---------------------------------------------------
%%% Restart. A process has terminated.
%%% Returns: {ok, #state} | {shutdown, #state}
%%% ---------------------------------------------------

restart_child(Pid, Reason, State) when ?is_simple(State) ->
    case lists:keysearch(Pid, 1, State#state.dynamics) of
	{value, {_Pid, Args}} ->
	    [Child] = State#state.children,
	    RestartType = Child#child.restart_type,
	    {M, F, A} = Child#child.mfa,
	    NChild = Child#child{pid = Pid, mfa = {M, F, Args}},
	    do_restart(RestartType, Reason, NChild, State);
	_ ->
	    {ok, State}
    end;
restart_child(Pid, Reason, State) ->
    Children = State#state.children,
    case lists:keysearch(Pid, #child.pid, Children) of
	{value, Child} ->
	    RestartType = Child#child.restart_type,
	    do_restart(RestartType, Reason, Child, State);
	_ ->
	    {ok, State}
    end.

do_restart(permanent, Reason, Child, State) ->
    report_error(child_terminated, Reason, Child, State#state.name),
    restart(Child, State);
do_restart(_, normal, Child, State) ->
    NState = state_del_child(Child, State),
    {ok, NState};
do_restart(_, shutdown, Child, State) ->
    NState = state_del_child(Child, State),
    {ok, NState};
do_restart(transient, Reason, Child, State) ->
    report_error(child_terminated, Reason, Child, State#state.name),
    restart(Child, State);
do_restart(temporary, Reason, Child, State) ->
    report_error(child_terminated, Reason, Child, State#state.name),
    NState = state_del_child(Child, State),
    {ok, NState}.

restart(Child, State) ->
    case add_restart(State) of
	{ok, NState} ->
	    restart(NState#state.strategy, Child, NState);
	{terminate, NState} ->
	    report_error(shutdown, reached_max_restart_intensity,
			 Child, State#state.name),
	    {shutdown, remove_child(Child, NState)}
    end.

restart(simple_one_for_one, Child, State) ->
    #child{mfa = {M, F, A}} = Child,
    Dynamics = lists:keydelete(Child#child.pid,1,State#state.dynamics),
    case do_start_child_i(M, F, A) of
	{ok, Pid} ->
	    NState = State#state{dynamics = [{Pid, A} | Dynamics]},
	    {ok, NState};
	{ok, Pid, _Extra} ->
	    NState = State#state{dynamics = [{Pid, A} | Dynamics]},
	    {ok, NState};
	{error, Error} ->
	    report_error(start_error, Error, Child, State#state.name),
	    restart(Child, State)
    end;
restart(one_for_one, Child, State) ->
    case do_start_child(State#state.name, Child) of
	{ok, Pid} ->
	    NState = replace_child(Child#child{pid = Pid}, State),
	    {ok, NState};
	{ok, Pid, _Extra} ->
	    NState = replace_child(Child#child{pid = Pid}, State),
	    {ok, NState};
	{error, Reason} ->
	    report_error(start_error, Reason, Child, State#state.name),
	    restart(Child, State)
    end;
restart(rest_for_one, Child, State) ->
    {ChAfter, ChBefore} = split_child(Child#child.pid, State#state.children),
    ChAfter2 = terminate_children(ChAfter, State#state.name),
    case start_children(ChAfter2, State#state.name) of
	{ok, ChAfter3} ->
	    {ok, State#state{children = ChAfter3 ++ ChBefore}};
	{error, ChAfter3} ->
	    restart(Child, State#state{children = ChAfter3 ++ ChBefore})
    end;
restart(one_for_all, Child, State) ->
    Children1 = del_child(Child#child.pid, State#state.children),
    Children2 = terminate_children(Children1, State#state.name),
    case start_children(Children2, State#state.name) of
	{ok, NChs} ->
	    {ok, State#state{children = NChs}};
	{error, NChs} ->
	    restart(Child, State#state{children = NChs})
    end.

%%-----------------------------------------------------------------
%% Func: terminate_children/2
%% Args: Children = [#child] in termination order
%%       SupName = {local, atom()} | {global, atom()} | {pid(),Mod}
%% Returns: NChildren = [#child] in
%%          startup order (reversed termination order)
%%-----------------------------------------------------------------
terminate_children(Children, SupName) ->
    terminate_children(Children, SupName, []).

terminate_children([Child | Children], SupName, Res) ->
    NChild = do_terminate(Child, SupName),
    terminate_children(Children, SupName, [NChild | Res]);
terminate_children([], SupName, Res) ->
    Res.

do_terminate(Child, SupName) when Child#child.pid /= undefined ->
    case shutdown(Child#child.pid,
		  Child#child.shutdown) of
	ok ->
	    Child#child{pid = undefined};
	{error, OtherReason} ->
	    report_error(shutdown_error, OtherReason, Child, SupName),
	    Child#child{pid = undefined}
    end;
do_terminate(Child, _SupName) ->
    Child.

%%-----------------------------------------------------------------
%% Try to shutdown a child.  We must check the EXIT value of the
%% child, because it might have died with another reason than
%% the wanted.  In this case we want to report the error.
%% The child is guaranteed to be terminated.
%% Returns: ok | {error, OtherReason}  (this should be reported)
%%-----------------------------------------------------------------
shutdown(Pid, brutal_kill) ->
    exit(Pid, kill),
    receive
	{'EXIT', Pid, killed} -> ok;
	{'EXIT', Pid, OtherReason} -> {error, OtherReason}
    end;
shutdown(Pid, Time) ->
    exit(Pid, shutdown),
    receive
	{'EXIT', Pid, shutdown} -> ok;
	{'EXIT', Pid, OtherReason} -> {error, OtherReason}
    after Time ->
	    exit(Pid, kill),  %% Force termination.
	    receive
		{'EXIT', Pid, OtherReason} ->
		    {error, OtherReason}
	    end
    end.

%%-----------------------------------------------------------------
%% Child/State manipulating functions.
%%-----------------------------------------------------------------
state_del_child(#child{pid = Pid}, State) when ?is_simple(State) ->
    NDynamics = lists:keydelete(Pid, 1, State#state.dynamics),
    State#state{dynamics = NDynamics};
state_del_child(Child, State) ->
    NChildren = del_child(Child#child.name, State#state.children),
    State#state{children = NChildren}.

del_child(Name, [Ch|Chs]) when Ch#child.name == Name ->
    [Ch#child{pid = undefined} | Chs];
del_child(Pid, [Ch|Chs]) when Ch#child.pid == Pid ->
    [Ch#child{pid = undefined} | Chs];
del_child(Name, [Ch|Chs]) ->
    [Ch|del_child(Name, Chs)];
del_child(_, []) ->
    [].

%% Chs = [S4, S3, Ch, S1, S0]
%% Ret: {[S4, S3, Ch], [S1, S0]}
split_child(Name, Chs) ->
    split_child(Name, Chs, []).

split_child(Name, [Ch|Chs], After) when Ch#child.name == Name ->
    {lists:reverse([Ch#child{pid = undefined} | After]), Chs};
split_child(Pid, [Ch|Chs], After) when Ch#child.pid == Pid ->
    {lists:reverse([Ch#child{pid = undefined} | After]), Chs};
split_child(Name, [Ch|Chs], After) ->
    split_child(Name, Chs, [Ch | After]);
split_child(_, [], After) ->
    {lists:reverse(After), []}.

get_child(Name, State) ->
    lists:keysearch(Name, #child.name, State#state.children).
replace_child(Child, State) ->
    Chs = do_replace_child(Child, State#state.children),
    State#state{children = Chs}.

do_replace_child(Child, [Ch|Chs]) when Ch#child.name == Child#child.name ->
    [Child | Chs];
do_replace_child(Child, [Ch|Chs]) ->
    [Ch|do_replace_child(Child, Chs)].

remove_child(Child, State) ->
    Chs = lists:keydelete(Child#child.name, #child.name, State#state.children),
    State#state{children = Chs}.

%%-----------------------------------------------------------------
%% Func: init_state/4
%% Args: SupName = {local, atom()} | {global, atom()} | self
%%       Type = {Strategy, MaxIntensity, Period}
%%         Strategy = one_for_one | one_for_all | simple_one_for_one |
%%                    rest_for_one 
%%         MaxIntensity = integer()
%%         Period = integer()
%%       Mod :== atom()
%%       Arsg :== term()
%% Purpose: Check that Type is of correct type (!)
%% Returns: {ok, #state} | Error
%%-----------------------------------------------------------------
init_state(SupName, Type, Mod, Args) ->
    case catch init_state1(SupName, Type, Mod, Args) of
	{ok, State} ->
	    {ok, State};
	Error ->
	    Error
    end.

init_state1(SupName, {Strategy, MaxIntensity, Period}, Mod, Args) ->
    validStrategy(Strategy),
    validIntensity(MaxIntensity),
    validPeriod(Period),
    {ok, #state{name = supname(SupName,Mod),
	       strategy = Strategy,
	       intensity = MaxIntensity,
	       period = Period,
	       module = Mod,
	       args = Args}};
init_state1(_SupName, Type, _, _) ->
    {invalid_type, Type}.

validStrategy(simple_one_for_one) -> true;
validStrategy(one_for_one)        -> true;
validStrategy(one_for_all)        -> true;
validStrategy(rest_for_one)       -> true;
validStrategy(What)               -> throw({invalid_strategy, What}).

validIntensity(Max) when integer(Max),
                         Max >=  0 -> true;
validIntensity(What)              -> throw({invalid_intensity, What}).

validPeriod(Period) when integer(Period),
                         Period > 0 -> true;
validPeriod(What)                   -> throw({invalid_period, What}).

supname(self,Mod) -> {self(),Mod};
supname(N,_)      -> N.

%%% ------------------------------------------------------
%%% Check that the children start specification is valid.
%%% Shall be a six (6) tuple
%%%    {Name, Func, RestartType, Shutdown, ChildType, Modules}
%%% where Name is an atom
%%%       Func is {Mod, Fun, Args} == {atom, atom, list}
%%%       RestartType is permanent | temporary | transient
%%%       Shutdown = integer() | infinity | brutal_kill
%%%       ChildType = supervisor | worker
%%%       Modules = [atom()] | dynamic
%%% Returns: {ok, [#child]} | Error
%%% ------------------------------------------------------

check_startspec(Children) -> check_startspec(Children, []).

check_startspec([ChildSpec|T], Res) ->
    case check_childspec(ChildSpec) of
	{ok, Child} ->
	    case lists:keysearch(Child#child.name, #child.name, Res) of
		{value, _} -> {duplicate_child_name, Child#child.name};
		_ -> check_startspec(T, [Child | Res])
	    end;
	Error -> Error
    end;
check_startspec([], Res) ->
    {ok, lists:reverse(Res)}.

check_childspec({Name, Func, RestartType, Shutdown, ChildType, Mods}) ->
    catch check_childspec(Name, Func, RestartType, Shutdown, ChildType, Mods);
check_childspec(X) -> {invalid_child_spec, X}.

check_childspec(Name, Func, RestartType, Shutdown, ChildType, Mods) ->
    validName(Name),
    validFunc(Func),
    validRestartType(RestartType),
    validChildType(ChildType),
    validShutdown(Shutdown, ChildType),
    validMods(Mods),
    {ok, #child{name = Name, mfa = Func, restart_type = RestartType,
		shutdown = Shutdown, child_type = ChildType, modules = Mods}}.

validChildType(supervisor)  -> true;
validChildType(worker) -> true;
validChildType(What)  -> throw({invalid_child_type, What}).

validName(Name) -> true. 

validFunc({M, F, A}) when atom(M), atom(F), list(A) -> true;
validFunc(Func)                                 -> throw({invalid_mfa, Func}).

validRestartType(permanent)   -> true;
validRestartType(temporary)   -> true;
validRestartType(transient)   -> true;
validRestartType(RestartType) -> throw({invalid_restart_type, RestartType}).

validShutdown(Shutdown, _) 
  when integer(Shutdown), Shutdown > 0 -> true;
validShutdown(infinity, supervisor)    -> true;
validShutdown(brutal_kill, _)          -> true;
validShutdown(Shutdown, _)             -> throw({invalid_shutdown, Shutdown}).

validMods(dynamic) -> true;
validMods(Mods) when list(Mods) ->
    lists:foreach(fun(Mod) ->
		    if
			atom(Mod) -> ok;
			true -> throw({invalid_module, Mod})
		    end
		  end,
		  Mods);
validMods(Mods) -> throw({invalid_modules, Mods}).

%%% ------------------------------------------------------
%%% Add a new restart and calculate if the max restart
%%% intensity has been reached (in that case the supervisor
%%% shall terminate).
%%% All restarts accured inside the period amount of seconds
%%% are kept in the #state.restarts list.
%%% Returns: {ok, State'} | {terminate, State'}
%%% ------------------------------------------------------

add_restart(State) ->  
    I = State#state.intensity,
    P = State#state.period,
    R = State#state.restarts,
    Now = erlang:now(),
    R1 = add_restart([Now|R], Now, P),
    State1 = State#state{restarts = R1},
    case length(R1) of
	CurI when CurI  =< I ->
	    {ok, State1};
	_ ->
	    {terminate, State1}
    end.

add_restart([R|Restarts], Now, Period) ->
    case inPeriod(R, Now, Period) of
	true ->
	    [R|add_restart(Restarts, Now, Period)];
	_ ->
	    []
    end;
add_restart([], _, _) ->
    [].

inPeriod(Time, Now, Period) ->
    case difference(Time, Now) of
	T when T > Period ->
	    false;
	_ ->
	    true
    end.

%%
%% Time = {MegaSecs, Secs, MicroSecs} (NOTE: MicroSecs is ignored)
%% Calculate the time elapsed in seconds between two timestamps.
%% If MegaSecs is equal just subtract Secs.
%% Else calculate the Mega difference and add the Secs difference,
%% note that Secs difference can be negative, e.g.
%%      {827, 999999, 676} diff {828, 1, 653753} == > 2 secs.
%%
difference({TimeM, TimeS, _}, {CurM, CurS, _}) when CurM > TimeM ->
    ((CurM - TimeM) * 1000000) + (CurS - TimeS);
difference({_, TimeS, _}, {_, CurS, _}) ->
    CurS - TimeS.

%%% ------------------------------------------------------
%%% Error and progress reporting.
%%% ------------------------------------------------------

report_error(Error, Reason, Child, SupName) ->
    ErrorMsg = [{supervisor, SupName},
		{errorContext, Error},
		{reason, Reason},
		{offender, extract_child(Child)}],
    error_logger:error_report(supervisor_report, ErrorMsg).


extract_child(Child) ->
    [{pid, Child#child.pid},
     {name, Child#child.name},
     {mfa, Child#child.mfa},
     {restart_type, Child#child.restart_type},
     {shutdown, Child#child.shutdown},
     {child_type, Child#child.child_type}].

report_progress(Child, SupName) ->
    Progress = [{supervisor, SupName},
		{started, extract_child(Child)}],
    error_logger:info_report(progress, Progress).


