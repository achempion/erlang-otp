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
-module(erlang).

-export([apply/2,apply/3,spawn/4,spawn_link/4,spawn_opt/4,
	 disconnect_node/1]).
-export([spawn/1, spawn_link/1, spawn/2, spawn_link/2]).
-export([yield/0]).
-export([crasher/5]).
-export([sand/2,sor/2,sxor/2,snot/1,sgt/2,sge/2,slt/2,sle/2,seq/2,sneq/2, 
	 seqeq/2, sneqeq/2]).
-export([fun_info/1]).

-export([dlink/1, dunlink/1, dsend/2, dsend_nosuspend/2, dgroup_leader/2,
	 dexit/2, dmonitor_node/2, dmonitor_p/2]).

-export([set_cookie/2, get_cookie/0]).

-export([open_port/2]).

-export([nodes/0]).

open_port(Name, Opt) -> erl_open_port:open_port(Name, Opt).

apply(Fun, Args) ->
    apply(Fun, Args).

apply(Mod, Name, Args) ->
    apply(Mod, Name, Args).

% Spawns with a fun

spawn(F) when function(F) ->
    spawn(erlang, apply, [F, []]);
spawn({M,F}=MF) when atom(M), atom(F) ->
    spawn(erlang, apply, [MF, []]);
spawn(F) ->
    erlang:fault(badarg, [F]).

spawn(N, F) when N == node() ->
    spawn(F);
spawn(N, F) when function(F) ->
    spawn(N, erlang, apply, [F, []]);
spawn(N, {M,F}=MF) when atom(M), atom(F) ->
    spawn(N, erlang, apply, [MF, []]);
spawn(N, F) ->
    erlang:fault(badarg, [N, F]).

spawn_link(F) when function(F) ->
    spawn_link(erlang, apply, [F, []]);
spawn_link({M,F}=MF) when atom(M), atom(F) ->
    spawn_link(erlang, apply, [MF, []]);
spawn_link(F) ->
    erlang:fault(badarg, [F]).

spawn_link(N, F) when N == node() ->
    spawn_link(F);
spawn_link(N, F) when function(F) ->
    spawn_link(N, erlang, apply, [F, []]);
spawn_link(N, {M,F}=MF) when atom(M), atom(F) ->
    spawn_link(N, erlang, apply, [MF, []]);
spawn_link(N, F) ->
    erlang:fault(badarg, [N, F]).

% Spawns with MFA

spawn(N,M,F,A) when N == node(), atom(M), atom(F), list(A) ->
    spawn(M,F,A);
spawn(N,M,F,A) when atom(N), atom(M), atom(F) ->
    case is_well_formed_list(A) of
	false ->
	    erlang:fault(badarg, [N, M, F, A]);
	true ->
	    ok
    end,
    case catch gen_server:call({net_kernel,N},
			       {spawn,M,F,A,group_leader()},
			       infinity) of
	Pid when pid(Pid) ->
	    Pid;
	Error ->
	    case remote_spawn_error(Error, {no_link, N, M, F, A}) of
		{fault, Fault} ->
		    erlang:fault(Fault, [N, M, F, A]);
		Pid ->
		    Pid
	    end
    end;
spawn(N,M,F,A) ->
    erlang:fault(badarg, [N, M, F, A]).

spawn_link(N,M,F,A) when N == node(), atom(M), atom(F), list(A) ->
    spawn_link(M,F,A);
spawn_link(N,M,F,A) when atom(N), atom(M), atom(F) ->
    case is_well_formed_list(A) of
	false ->
	    erlang:fault(badarg, [N, M, F, A]);
	true ->
	    ok
    end,
    case catch gen_server:call({net_kernel,N},
			       {spawn_link,M,F,A,group_leader()},
			       infinity) of
	Pid when pid(Pid) ->
	    Pid;
	Error ->
	    case remote_spawn_error(Error, {link, N, M, F, A}) of
		{fault, Fault} ->
		    erlang:fault(Fault, [N, M, F, A]);
		Pid ->
		    Pid
	    end
    end;
spawn_link(N,M,F,A) ->
    erlang:fault(badarg, [N, M, F, A]).

spawn_opt(M, F, A, Opts) ->
    case catch erlang:spawn_opt({M, F, A}, Opts) of
	Pid when pid(Pid) ->
	    Pid;
	{'EXIT', {Reason, _}} ->
	    erlang:fault(Reason, [M,F,A,Opts])
    end.

remote_spawn_error({'EXIT', {{nodedown,N}, _}}, {link, N, M, F, A}) ->
    spawn_link(erlang,crasher,[N,M,F,A,noconnection]);
remote_spawn_error({'EXIT', {{nodedown,N}, _}}, {_, N, M, F, A}) ->
    spawn(erlang,crasher,[N,M,F,A,noconnection]);
remote_spawn_error({'EXIT', {Reason, _}}, _) ->
    {fault, Reason};
remote_spawn_error({'EXIT', Reason}, _) ->
    {fault, Reason};
remote_spawn_error(Other, _) ->
    {fault, Other}.

is_well_formed_list([]) ->
    true;
is_well_formed_list([_|Rest]) ->
    is_well_formed_list(Rest);
is_well_formed_list(_) ->
    false.

yield() ->
    erlang:yield().

nodes() -> erlang:nodes(visible).

crasher(Node,Mod,Fun,Args,Reason) ->
    error_logger:error_msg("** Can not start ~w:~w,~w on ~w **~n",
			  [ Mod,Fun,Args,Node]),
    exit(Reason).

disconnect_node(Node) -> net_kernel:disconnect(Node).

fun_info(Fun) when function(Fun) ->
    [erlang:fun_info(Fun, Key) ||
	Key <- [pid,module,new_index,new_uniq,index,uniq,env,arity]].
    
sand(true, true) -> true;
sand(true, false) -> false;
sand(false, true) -> false;
sand(false, false) -> false.

sor(true, true) -> true;
sor(true, false) -> true;
sor(false, true) -> true;
sor(false, false) -> false.

sxor(true, true) -> false;
sxor(true, false) -> true;
sxor(false, true) -> true;
sxor(false, false) -> false.

snot(true) -> false;
snot(false) -> true.

sgt(X, Y) when X > Y -> true;
sgt(_, _) -> false.

sge(X, Y) when X >= Y -> true;
sge(_, _) -> false.

slt(X, Y) when X < Y -> true;
slt(_, _) -> false.

sle(X, Y) when X =< Y -> true;
sle(_, _) -> false.
    
seq(X, X) -> true;
seq(_, _) -> false.

seqeq(X, Y) when X == Y -> true;
seqeq(_, _) -> false.

sneq(X, X) -> false;
sneq(_, _) -> true.

sneqeq(X, Y) when X == Y -> false;
sneqeq(_, _) -> true.

%%
%% If the emulator wants to perform a distributed command and
%% a connection is not established to the actual node the following 
%% functions is called in order to set up the connection and then 
%% reactivate the command.
%%

dlink(Pid) ->
    case net_kernel:connect(node(Pid)) of
	true -> link(Pid);
	false -> erlang:dist_exit(self(), noconnection, Pid), true
    end.

%% Can this ever happen?
dunlink(Pid) ->
    case net_kernel:connect(node(Pid)) of
	true -> unlink(Pid);
	false -> true  %% dist_unlink ??
    end.

dmonitor_node(Node, Flag) ->
    case net_kernel:connect(Node) of
	true -> monitor_node(Node, Flag);
	false -> self() ! {nodedown, Node}, true
    end.

dgroup_leader(Leader, Pid) ->
    case net_kernel:connect(node(Pid)) of
	true -> group_leader(Leader, Pid);
	false -> true  %% bad arg ?
    end.

dexit(Pid, Reason) -> 
    case net_kernel:connect(node(Pid)) of
	true -> exit(Pid, Reason);
	false -> true
    end.

dsend(Pid, Msg) when pid(Pid) ->
    case net_kernel:connect(node(Pid)) of
	true -> Pid ! Msg;
	false -> Msg
    end;
dsend(Port, Msg) when port(Port) ->
    case net_kernel:connect(node(Port)) of
	true -> Port ! Msg;
	false -> Msg
    end;
dsend({Name, Node}, Msg) ->
    case net_kernel:connect(Node) of
	true -> {Name,Node} ! Msg;
	false -> Msg;
	ignored -> Msg				% Not distributed.
    end.

dsend_nosuspend(Pid, Msg) when pid(Pid) ->
    case net_kernel:connect(node(Pid)) of
	true -> erlang:send_nosuspend(Pid,Msg);
	false -> true
    end;
dsend_nosuspend({Name, Node}, Msg) ->
    case net_kernel:connect(Node) of
	true -> erlang:send_nosuspend({Name,Node},Msg);
	false -> true;
	ignored -> true				% Not distributed.
    end.

dmonitor_p(process, ProcSpec) ->
    {Proc, Node} =
	case ProcSpec of
	    _ when pid(ProcSpec) ->
		{ProcSpec, node(ProcSpec)};
	    %% N when atom(N) -> will not happen since that
	    %% is a local name and will not require a 
	    %% net_kernel:connect().
	    {S, N} when atom(S), atom(N), N /= node() ->
		ProcSpec
	end,
    case net_kernel:connect(Node) of
	true ->
	    erlang:monitor(process, ProcSpec);
	false ->
	    Ref = make_ref(),
	    self() ! {'DOWN', Ref, process, Proc, noconnection},
	    Ref
    end.

%%
%% The business with different in and out cookies represented
%% everywhere is discarded.
%% A node has a cookie, connections/messages to that node use that cookie.
%% Messages to us use our cookie. IF we change our cookie, other nodes 
%% have to reflect that, which we cannot forsee.
%%
set_cookie(Node, C) when Node =/= nonode@nohost, atom(Node) ->
    Res = case C of
	      _ when atom(C) ->
		  auth:set_cookie(Node, C);
	      {CI,CO} when atom(CI),atom(CO) ->
		  auth:set_cookie(Node, {CI, CO});
	      _ ->
		  error
	  end,
    case Res of
	error -> exit(badarg);
	Other -> Other
    end.
	    
get_cookie() ->
    auth:get_cookie().
