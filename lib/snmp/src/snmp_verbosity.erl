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
-module(snmp_verbosity).

-include_lib("stdlib/include/erl_compile.hrl").

-export([print/4,print/5,printc/4,validate/1]).

print(silence,_Severity,_Format,_Arguments) ->
    ok;
print(Verbosity,Severity,Format,Arguments) ->
    print1(printable(Verbosity,Severity),Format,Arguments).


print(silence,_Severity,_Module,_Format,_Arguments) ->
    ok;
print(Verbosity,Severity,Module,Format,Arguments) ->
    print1(printable(Verbosity,Severity),Module,Format,Arguments).


printc(silence,Severity,Format,Arguments) ->
    ok;
printc(Verbosity,Severity,Format,Arguments) ->
    print2(printable(Verbosity,Severity),Format,Arguments).


print1(false,_Format,_Arguments) -> ok;
print1(Verbosity,Format,Arguments) ->
    V = image_of_verbosity(Verbosity),
    S = image_of_sname(get(sname)),
    io:format("** SNMP ~s ~s: " ++ Format ++ "~n",[S,V]++Arguments).

print1(false,_Module,_Format,_Arguments) -> ok;
print1(Verbosity,Module,Format,Arguments) ->
    V = image_of_verbosity(Verbosity),
    S = image_of_sname(get(sname)),
    io:format("** SNMP ~s ~s ~s: " ++ Format ++ "~n",[S,Module,V]++Arguments).


print2(false,_Format,_Arguments) -> ok;
print2(_Verbosity,Format,Arguments) ->
    io:format(Format ++ "~n",Arguments).


%% printable(Verbosity,Severity)
printable(info,info)      -> info;
printable(log,info)       -> info;
printable(log,log)        -> log;
printable(debug,info)     -> info;
printable(debug,log)      -> log;
printable(debug,debug)    -> debug;
printable(trace,V)        -> V;
printable(_Verb,_Sev)     -> false.


image_of_verbosity(info)  -> "INFO";
image_of_verbosity(log)   -> "LOG";
image_of_verbosity(debug) -> "DEBUG";
image_of_verbosity(trace) -> "TRACE";
image_of_verbosity(_)     -> "".

%% ShortName
image_of_sname(ma)        -> "MASTER-AGENT";
image_of_sname(maw)       -> io_lib:format("MASTER-AGENT-worker(~p)",[self()]);
image_of_sname(mais)      -> io_lib:format("MASTER-AGENT-inform_sender(~p)",
					   [self()]);
image_of_sname(mats)      -> io_lib:format("MASTER-AGENT-trap_sender(~p)",
					   [self()]);
image_of_sname(maph)      -> io_lib:format("MASTER-AGENT-pdu_handler(~p)",
					   [self()]);
image_of_sname(sa)        -> "SUB-AGENT";
image_of_sname(saw)       -> io_lib:format("SUB-AGENT-worker(~p)",[self()]);
image_of_sname(sais)      -> io_lib:format("SUB-AGENT-inform_sender(~p)",
					   [self()]);
image_of_sname(sats)      -> io_lib:format("SUB-AGENT-trap_sender(~p)",
					   [self()]);
image_of_sname(saph)      -> io_lib:format("SUB-AGENT-pdu_handler(~p)",
					   [self()]);
image_of_sname(nif)       -> "NET-IF";
image_of_sname(ldb)       -> "LOCAL-DB";
image_of_sname(ns)        -> "NOTE-STORE";
image_of_sname(ss)        -> "SYMBOLIC-STORE";
image_of_sname(sup)       -> "SUPERVISOR";
image_of_sname(ms)        -> "MIB-SERVER";
image_of_sname(conf)      -> "CONFIGURATOR";
image_of_sname(undefined) -> "";
image_of_sname(V)         -> io_lib:format("~p",[V]).


validate(info)  -> info;
validate(log)   -> log;
validate(debug) -> debug;
validate(trace) -> trace;
validate(_)     -> silence.

