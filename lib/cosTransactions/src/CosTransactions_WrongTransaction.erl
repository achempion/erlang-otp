%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosTransactions_WrongTransaction
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2008-04-07_20/otp_src_R12B-1/lib/cosTransactions/src/CosTransactions.idl
%% IC vsn: 4.2.17
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosTransactions_WrongTransaction').
-ic_compiled("4_2_17").


-include("CosTransactions.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_except,"IDL:omg.org/CosTransactions/WrongTransaction:1.0",
                   "WrongTransaction",[]}.

%% returns id
id() -> "IDL:omg.org/CosTransactions/WrongTransaction:1.0".

%% returns name
name() -> "CosTransactions_WrongTransaction".


