%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosFileTransfer_VirtualFileSystem
%% Source: /net/shelob/ldisk/daily_build/otp_prebuild_r13b.2009-04-15_20/otp_src_R13B/lib/cosFileTransfer/src/CosFileTransfer.idl
%% IC vsn: 4.2.20
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosFileTransfer_VirtualFileSystem').
-ic_compiled("4_2_20").


%% Interface functions
-export(['_get_file_system_type'/1, '_get_file_system_type'/2, '_get_supported_content_types'/1]).
-export(['_get_supported_content_types'/2, login/4, login/5]).

%% Type identification function
-export([typeID/0]).

%% Used to start server
-export([oe_create/0, oe_create_link/0, oe_create/1]).
-export([oe_create_link/1, oe_create/2, oe_create_link/2]).

%% TypeCode Functions and inheritance
-export([oe_tc/1, oe_is_a/1, oe_get_interface/0]).

%% gen server export stuff
-behaviour(gen_server).
-export([init/1, terminate/2, handle_call/3]).
-export([handle_cast/2, handle_info/2, code_change/3]).

-include_lib("orber/include/corba.hrl").


%%------------------------------------------------------------
%%
%% Object interface functions.
%%
%%------------------------------------------------------------



%%%% Operation: '_get_file_system_type'
%% 
%%   Returns: RetVal
%%
'_get_file_system_type'(OE_THIS) ->
    corba:call(OE_THIS, '_get_file_system_type', [], ?MODULE).

'_get_file_system_type'(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, '_get_file_system_type', [], ?MODULE, OE_Options).

%%%% Operation: '_get_supported_content_types'
%% 
%%   Returns: RetVal
%%
'_get_supported_content_types'(OE_THIS) ->
    corba:call(OE_THIS, '_get_supported_content_types', [], ?MODULE).

'_get_supported_content_types'(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, '_get_supported_content_types', [], ?MODULE, OE_Options).

%%%% Operation: login
%% 
%%   Returns: RetVal, Root
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::IllegalOperationException
%%
login(OE_THIS, Username, Password, Account) ->
    corba:call(OE_THIS, login, [Username, Password, Account], ?MODULE).

login(OE_THIS, OE_Options, Username, Password, Account) ->
    corba:call(OE_THIS, login, [Username, Password, Account], ?MODULE, OE_Options).

%%------------------------------------------------------------
%%
%% Inherited Interfaces
%%
%%------------------------------------------------------------
oe_is_a("IDL:omg.org/CosFileTransfer/VirtualFileSystem:1.0") -> true;
oe_is_a(_) -> false.

%%------------------------------------------------------------
%%
%% Interface TypeCode
%%
%%------------------------------------------------------------
oe_tc('_get_file_system_type') -> 
	{{tk_enum,"IDL:omg.org/CosFileTransfer/VirtualFileSystem/NativeFileSystemType:1.0",
                  "NativeFileSystemType",
                  ["FTAM","FTP","NATIVE"]},
         [],[]};
oe_tc('_get_supported_content_types') -> 
	{{tk_sequence,tk_long,0},[],[]};
oe_tc(login) -> 
	{{tk_objref,"IDL:omg.org/CosFileTransfer/FileTransferSession:1.0",
                    "FileTransferSession"},
         [{tk_string,0},{tk_string,0},{tk_string,0}],
         [{tk_objref,"IDL:omg.org/CosFileTransfer/Directory:1.0",
                     "Directory"}]};
oe_tc(_) -> undefined.

oe_get_interface() -> 
	[{"login", oe_tc(login)},
	{"_get_supported_content_types", oe_tc('_get_supported_content_types')},
	{"_get_file_system_type", oe_tc('_get_file_system_type')}].




%%------------------------------------------------------------
%%
%% Object server implementation.
%%
%%------------------------------------------------------------


%%------------------------------------------------------------
%%
%% Function for fetching the interface type ID.
%%
%%------------------------------------------------------------

typeID() ->
    "IDL:omg.org/CosFileTransfer/VirtualFileSystem:1.0".


%%------------------------------------------------------------
%%
%% Object creation functions.
%%
%%------------------------------------------------------------

oe_create() ->
    corba:create(?MODULE, "IDL:omg.org/CosFileTransfer/VirtualFileSystem:1.0").

oe_create_link() ->
    corba:create_link(?MODULE, "IDL:omg.org/CosFileTransfer/VirtualFileSystem:1.0").

oe_create(Env) ->
    corba:create(?MODULE, "IDL:omg.org/CosFileTransfer/VirtualFileSystem:1.0", Env).

oe_create_link(Env) ->
    corba:create_link(?MODULE, "IDL:omg.org/CosFileTransfer/VirtualFileSystem:1.0", Env).

oe_create(Env, RegName) ->
    corba:create(?MODULE, "IDL:omg.org/CosFileTransfer/VirtualFileSystem:1.0", Env, RegName).

oe_create_link(Env, RegName) ->
    corba:create_link(?MODULE, "IDL:omg.org/CosFileTransfer/VirtualFileSystem:1.0", Env, RegName).

%%------------------------------------------------------------
%%
%% Init & terminate functions.
%%
%%------------------------------------------------------------

init(Env) ->
%% Call to implementation init
    corba:handle_init('CosFileTransfer_VirtualFileSystem_impl', Env).

terminate(Reason, State) ->
    corba:handle_terminate('CosFileTransfer_VirtualFileSystem_impl', Reason, State).


%%%% Operation: '_get_file_system_type'
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, '_get_file_system_type', []}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_VirtualFileSystem_impl', '_get_file_system_type', [], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: '_get_supported_content_types'
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, '_get_supported_content_types', []}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_VirtualFileSystem_impl', '_get_supported_content_types', [], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: login
%% 
%%   Returns: RetVal, Root
%%   Raises:  CosFileTransfer::SessionException, CosFileTransfer::FileNotFoundException, CosFileTransfer::IllegalOperationException
%%
handle_call({OE_THIS, OE_Context, login, [Username, Password, Account]}, _, OE_State) ->
  corba:handle_call('CosFileTransfer_VirtualFileSystem_impl', login, [Username, Password, Account], OE_State, OE_Context, OE_THIS, false);



%%%% Standard gen_server call handle
%%
handle_call(stop, _, State) ->
    {stop, normal, ok, State};

handle_call(_, _, State) ->
    {reply, catch corba:raise(#'BAD_OPERATION'{minor=1163001857, completion_status='COMPLETED_NO'}), State}.


%%%% Standard gen_server cast handle
%%
handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_, State) ->
    {noreply, State}.


%%%% Standard gen_server handles
%%
handle_info(Info, State) ->
    corba:handle_info('CosFileTransfer_VirtualFileSystem_impl', Info, State).


code_change(OldVsn, State, Extra) ->
    corba:handle_code_change('CosFileTransfer_VirtualFileSystem_impl', OldVsn, State, Extra).

