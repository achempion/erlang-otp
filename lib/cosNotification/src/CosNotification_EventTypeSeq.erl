%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosNotification_EventTypeSeq
%% Source: /net/shelob/ldisk/daily_build/otp_prebuild_r13b.2009-04-15_20/otp_src_R13B/lib/cosNotification/src/CosNotification.idl
%% IC vsn: 4.2.20
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosNotification_EventTypeSeq').
-ic_compiled("4_2_20").


-include("CosNotification.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_sequence,{tk_struct,"IDL:omg.org/CosNotification/EventType:1.0",
                                "EventType",
                                [{"domain_name",{tk_string,0}},
                                 {"type_name",{tk_string,0}}]},
                     0}.

%% returns id
id() -> "IDL:omg.org/CosNotification/EventTypeSeq:1.0".

%% returns name
name() -> "CosNotification_EventTypeSeq".



