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
%%----------------------------------------------------------------------
%% Purpose: A fun implementation of user callbacks
%%----------------------------------------------------------------------

-module(megaco_mess_user_test).

-behaviour(megaco_user).

-export([
         handle_connect/2,
         handle_disconnect/3,
         handle_syntax_error/3,
         handle_message_error/3,
         handle_trans_request/3,
         handle_trans_long_request/3,
         handle_trans_reply/4,
         handle_trans_ack/4
        ]).

-export([
	 start_proxy/0,
	 stop_proxy/0,
	 apply_proxy/1,
	 reply/3,

	 start_transport/2,
	 loop_transport/1, % Internal only
	 send_message/2
	]).

-include("megaco_test_lib.hrl").
-define(SERVER, ?MODULE).

start_proxy() ->
    yes = global:register_name(?SERVER, self()),
    Pid = megaco_test_lib:proxy_start(?MODULE),
    put(?MODULE, Pid),
    Pid.

stop_proxy() ->
    global:unregister_name(?SERVER),
    Pid = erase(?MODULE),
    unlink(Pid),
    exit(Pid, shutdown).

whereis_proxy() ->
    case get(?MODULE) of
	undefined ->
	    exit(no_server, ?MODULE);
	Pid when pid(Pid) ->
	    Pid
    end.

apply_proxy(Fun) ->
    Pid = whereis_proxy(),
    ?APPLY(Pid, Fun),
    ok.

reply(Mod, Line, Fun) when function(Fun) ->
    receive
	{?MODULE, Pid, UserCallback} ->
	    UserReply = Fun(UserCallback),
	    Pid ! {?MODULE, self(), UserReply},
	    UserReply;
	Other ->
	    megaco_test_lib:error(Other, Mod, Line),
	    {error, Other}
%%     after 1000 ->
%% 	       megaco_test_lib:error(timeout, Mod, Line),
%% 	       {error, timeout}
    end.
  
call(UserCallback) ->
    Request = {?MODULE, self(), UserCallback},
    case global:whereis_name(?SERVER) of
	undefined ->
	    exit({no_server, ?SERVER, Request});
        Pid when pid(Pid) ->
	    ?LOG("send: ~p~n", [Request]),
	    Pid ! Request,
	    receive
		{?MODULE, Pid, UserReply} = Reply ->
		    ?LOG("receive: ~p~n", [Reply]),
		    case UserReply of
			{ok, Good}   -> Good;
			{error, Bad} -> exit(Bad)
		    end;
		{'EXIT', Pid, Reason} = Bad ->
		    ?LOG("receive test case exit: ~p~n", [Bad]),
		    exit(Reason);
		{'EXIT', _, Reason} = Bad ->
		    ?LOG("receive unknown exit: ~p~n", [Bad]),
		    exit(Reason);
		Bad ->
		    ?LOG("receive other: ~p~n", [Bad]),
		    exit(Bad)
	    end
    end.

%%----------------------------------------------------------------------
%% Megaco user callback
%%----------------------------------------------------------------------

handle_connect(ConnHandle, ProtocolVersion) ->
    call({connect, ConnHandle, ProtocolVersion, []}).

handle_disconnect(ConnHandle, ProtocolVersion, Reason) ->
    call({disconnect, ConnHandle, ProtocolVersion, [Reason]}).

handle_syntax_error(ReceiveHandle, ProtocolVersion, ErrorDescriptor) ->
    call({syntax_error, ReceiveHandle, ProtocolVersion, [ErrorDescriptor]}).

handle_message_error(ConnHandle, ProtocolVersion, ErrorDescriptor) ->
    call({message_error, ConnHandle, ProtocolVersion, [ErrorDescriptor]}).

handle_trans_request(ConnHandle, ProtocolVersion, ActionRequests) ->
    call({request, ConnHandle, ProtocolVersion, [ActionRequests]}).

handle_trans_long_request(ConnHandle, ProtocolVersion, RequestData) ->
    call({long_request, ConnHandle, ProtocolVersion, [RequestData]}).

handle_trans_reply(ConnHandle, ProtocolVersion, UserReply, UserData) ->
    call({reply, ConnHandle, ProtocolVersion, [UserReply, UserData]}).

handle_trans_ack(ConnHandle, ProtocolVersion, AckStatus, AckData) ->
    call({ack, ConnHandle, ProtocolVersion, [AckStatus, AckData]}).

%%----------------------------------------------------------------------
%% The ultimate Megaco transport callback
%%----------------------------------------------------------------------

start_transport(MgReceiveHandle, MgcReceiveHandle) ->
    MgControlPid  = spawn_link(?MODULE, loop_transport, [self()]),
    MgSendHandle  = {MgcReceiveHandle, MgControlPid},
    MgcControlPid = spawn_link(?MODULE, loop_transport, [self()]),
    MgcSendHandle = {MgReceiveHandle, MgcControlPid},
    SendHandle    = {MgSendHandle, MgcSendHandle},
    {ok, MgControlPid, SendHandle}.

loop_transport(Parent) ->
    receive
	{'EXIT', Pid, Reason} = Error->
	    ok = io:format("transport stopped: ~p~n", [{Parent, Error}]),
	    exit(Reason)
    end.

send_message({{RH, Pid} = LocalSendHandle, RemoteSendHandle}, Bin) ->
    SwappedSendHandle = {RemoteSendHandle, LocalSendHandle},
    megaco:receive_message(RH, Pid, SwappedSendHandle, Bin).
