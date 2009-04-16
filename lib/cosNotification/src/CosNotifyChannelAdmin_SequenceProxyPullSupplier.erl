%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosNotifyChannelAdmin_SequenceProxyPullSupplier
%% Source: /net/shelob/ldisk/daily_build/otp_prebuild_r13b.2009-04-15_20/otp_src_R13B/lib/cosNotification/src/CosNotifyChannelAdmin.idl
%% IC vsn: 4.2.20
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosNotifyChannelAdmin_SequenceProxyPullSupplier').
-ic_compiled("4_2_20").


%% Interface functions
-export([connect_sequence_pull_consumer/2, connect_sequence_pull_consumer/3]).

%% Exports from "CosNotifyChannelAdmin::ProxySupplier"
-export(['_get_MyType'/1, '_get_MyType'/2, '_get_MyAdmin'/1]).
-export(['_get_MyAdmin'/2, '_get_priority_filter'/1, '_get_priority_filter'/2]).
-export(['_set_priority_filter'/2, '_set_priority_filter'/3, '_get_lifetime_filter'/1]).
-export(['_get_lifetime_filter'/2, '_set_lifetime_filter'/2, '_set_lifetime_filter'/3]).
-export([obtain_offered_types/2, obtain_offered_types/3, validate_event_qos/2]).
-export([validate_event_qos/3]).

%% Exports from "CosNotification::QoSAdmin"
-export([get_qos/1, get_qos/2, set_qos/2]).
-export([set_qos/3, validate_qos/2, validate_qos/3]).

%% Exports from "CosNotifyFilter::FilterAdmin"
-export([add_filter/2, add_filter/3, remove_filter/2]).
-export([remove_filter/3, get_filter/2, get_filter/3]).
-export([get_all_filters/1, get_all_filters/2, remove_all_filters/1]).
-export([remove_all_filters/2]).

%% Exports from "CosNotifyComm::SequencePullSupplier"
-export([pull_structured_events/2, pull_structured_events/3, try_pull_structured_events/2]).
-export([try_pull_structured_events/3, disconnect_sequence_pull_supplier/1, disconnect_sequence_pull_supplier/2]).

%% Exports from "CosNotifyComm::NotifySubscribe"
-export([subscription_change/3, subscription_change/4]).

%% Exports from "oe_CosNotificationComm::Event"
-export([callSeq/3, callSeq/4, callAny/3]).
-export([callAny/4]).

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



%%%% Operation: connect_sequence_pull_consumer
%% 
%%   Returns: RetVal
%%   Raises:  CosEventChannelAdmin::AlreadyConnected
%%
connect_sequence_pull_consumer(OE_THIS, Pull_consumer) ->
    corba:call(OE_THIS, connect_sequence_pull_consumer, [Pull_consumer], ?MODULE).

connect_sequence_pull_consumer(OE_THIS, OE_Options, Pull_consumer) ->
    corba:call(OE_THIS, connect_sequence_pull_consumer, [Pull_consumer], ?MODULE, OE_Options).

%%%% Operation: '_get_MyType'
%% 
%%   Returns: RetVal
%%
'_get_MyType'(OE_THIS) ->
    corba:call(OE_THIS, '_get_MyType', [], ?MODULE).

'_get_MyType'(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, '_get_MyType', [], ?MODULE, OE_Options).

%%%% Operation: '_get_MyAdmin'
%% 
%%   Returns: RetVal
%%
'_get_MyAdmin'(OE_THIS) ->
    corba:call(OE_THIS, '_get_MyAdmin', [], ?MODULE).

'_get_MyAdmin'(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, '_get_MyAdmin', [], ?MODULE, OE_Options).

%%%% Operation: '_get_priority_filter'
%% 
%%   Returns: RetVal
%%
'_get_priority_filter'(OE_THIS) ->
    corba:call(OE_THIS, '_get_priority_filter', [], ?MODULE).

'_get_priority_filter'(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, '_get_priority_filter', [], ?MODULE, OE_Options).

%%%% Operation: '_set_priority_filter'
%% 
%%   Returns: RetVal
%%
'_set_priority_filter'(OE_THIS, OE_Value) ->
    corba:call(OE_THIS, '_set_priority_filter', [OE_Value], ?MODULE).

'_set_priority_filter'(OE_THIS, OE_Options, OE_Value) ->
    corba:call(OE_THIS, '_set_priority_filter', [OE_Value], ?MODULE, OE_Options).

%%%% Operation: '_get_lifetime_filter'
%% 
%%   Returns: RetVal
%%
'_get_lifetime_filter'(OE_THIS) ->
    corba:call(OE_THIS, '_get_lifetime_filter', [], ?MODULE).

'_get_lifetime_filter'(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, '_get_lifetime_filter', [], ?MODULE, OE_Options).

%%%% Operation: '_set_lifetime_filter'
%% 
%%   Returns: RetVal
%%
'_set_lifetime_filter'(OE_THIS, OE_Value) ->
    corba:call(OE_THIS, '_set_lifetime_filter', [OE_Value], ?MODULE).

'_set_lifetime_filter'(OE_THIS, OE_Options, OE_Value) ->
    corba:call(OE_THIS, '_set_lifetime_filter', [OE_Value], ?MODULE, OE_Options).

%%%% Operation: obtain_offered_types
%% 
%%   Returns: RetVal
%%
obtain_offered_types(OE_THIS, Mode) ->
    corba:call(OE_THIS, obtain_offered_types, [Mode], ?MODULE).

obtain_offered_types(OE_THIS, OE_Options, Mode) ->
    corba:call(OE_THIS, obtain_offered_types, [Mode], ?MODULE, OE_Options).

%%%% Operation: validate_event_qos
%% 
%%   Returns: RetVal, Available_qos
%%   Raises:  CosNotification::UnsupportedQoS
%%
validate_event_qos(OE_THIS, Required_qos) ->
    corba:call(OE_THIS, validate_event_qos, [Required_qos], ?MODULE).

validate_event_qos(OE_THIS, OE_Options, Required_qos) ->
    corba:call(OE_THIS, validate_event_qos, [Required_qos], ?MODULE, OE_Options).

%%%% Operation: get_qos
%% 
%%   Returns: RetVal
%%
get_qos(OE_THIS) ->
    corba:call(OE_THIS, get_qos, [], ?MODULE).

get_qos(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, get_qos, [], ?MODULE, OE_Options).

%%%% Operation: set_qos
%% 
%%   Returns: RetVal
%%   Raises:  CosNotification::UnsupportedQoS
%%
set_qos(OE_THIS, Qos) ->
    corba:call(OE_THIS, set_qos, [Qos], ?MODULE).

set_qos(OE_THIS, OE_Options, Qos) ->
    corba:call(OE_THIS, set_qos, [Qos], ?MODULE, OE_Options).

%%%% Operation: validate_qos
%% 
%%   Returns: RetVal, Available_qos
%%   Raises:  CosNotification::UnsupportedQoS
%%
validate_qos(OE_THIS, Required_qos) ->
    corba:call(OE_THIS, validate_qos, [Required_qos], ?MODULE).

validate_qos(OE_THIS, OE_Options, Required_qos) ->
    corba:call(OE_THIS, validate_qos, [Required_qos], ?MODULE, OE_Options).

%%%% Operation: add_filter
%% 
%%   Returns: RetVal
%%
add_filter(OE_THIS, New_filter) ->
    corba:call(OE_THIS, add_filter, [New_filter], ?MODULE).

add_filter(OE_THIS, OE_Options, New_filter) ->
    corba:call(OE_THIS, add_filter, [New_filter], ?MODULE, OE_Options).

%%%% Operation: remove_filter
%% 
%%   Returns: RetVal
%%   Raises:  CosNotifyFilter::FilterNotFound
%%
remove_filter(OE_THIS, Filter) ->
    corba:call(OE_THIS, remove_filter, [Filter], ?MODULE).

remove_filter(OE_THIS, OE_Options, Filter) ->
    corba:call(OE_THIS, remove_filter, [Filter], ?MODULE, OE_Options).

%%%% Operation: get_filter
%% 
%%   Returns: RetVal
%%   Raises:  CosNotifyFilter::FilterNotFound
%%
get_filter(OE_THIS, Filter) ->
    corba:call(OE_THIS, get_filter, [Filter], ?MODULE).

get_filter(OE_THIS, OE_Options, Filter) ->
    corba:call(OE_THIS, get_filter, [Filter], ?MODULE, OE_Options).

%%%% Operation: get_all_filters
%% 
%%   Returns: RetVal
%%
get_all_filters(OE_THIS) ->
    corba:call(OE_THIS, get_all_filters, [], ?MODULE).

get_all_filters(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, get_all_filters, [], ?MODULE, OE_Options).

%%%% Operation: remove_all_filters
%% 
%%   Returns: RetVal
%%
remove_all_filters(OE_THIS) ->
    corba:call(OE_THIS, remove_all_filters, [], ?MODULE).

remove_all_filters(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, remove_all_filters, [], ?MODULE, OE_Options).

%%%% Operation: pull_structured_events
%% 
%%   Returns: RetVal
%%   Raises:  CosEventComm::Disconnected
%%
pull_structured_events(OE_THIS, Max_number) ->
    corba:call(OE_THIS, pull_structured_events, [Max_number], ?MODULE).

pull_structured_events(OE_THIS, OE_Options, Max_number) ->
    corba:call(OE_THIS, pull_structured_events, [Max_number], ?MODULE, OE_Options).

%%%% Operation: try_pull_structured_events
%% 
%%   Returns: RetVal, Has_event
%%   Raises:  CosEventComm::Disconnected
%%
try_pull_structured_events(OE_THIS, Max_number) ->
    corba:call(OE_THIS, try_pull_structured_events, [Max_number], ?MODULE).

try_pull_structured_events(OE_THIS, OE_Options, Max_number) ->
    corba:call(OE_THIS, try_pull_structured_events, [Max_number], ?MODULE, OE_Options).

%%%% Operation: disconnect_sequence_pull_supplier
%% 
%%   Returns: RetVal
%%
disconnect_sequence_pull_supplier(OE_THIS) ->
    corba:call(OE_THIS, disconnect_sequence_pull_supplier, [], ?MODULE).

disconnect_sequence_pull_supplier(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, disconnect_sequence_pull_supplier, [], ?MODULE, OE_Options).

%%%% Operation: subscription_change
%% 
%%   Returns: RetVal
%%   Raises:  CosNotifyComm::InvalidEventType
%%
subscription_change(OE_THIS, Added, Removed) ->
    corba:call(OE_THIS, subscription_change, [Added, Removed], ?MODULE).

subscription_change(OE_THIS, OE_Options, Added, Removed) ->
    corba:call(OE_THIS, subscription_change, [Added, Removed], ?MODULE, OE_Options).

%%%% Operation: callSeq
%% 
%%   Returns: RetVal
%%
callSeq(OE_THIS, Events, Stat) ->
    corba:call(OE_THIS, callSeq, [Events, Stat], ?MODULE).

callSeq(OE_THIS, OE_Options, Events, Stat) ->
    corba:call(OE_THIS, callSeq, [Events, Stat], ?MODULE, OE_Options).

%%%% Operation: callAny
%% 
%%   Returns: RetVal
%%
callAny(OE_THIS, Event, Stat) ->
    corba:call(OE_THIS, callAny, [Event, Stat], ?MODULE).

callAny(OE_THIS, OE_Options, Event, Stat) ->
    corba:call(OE_THIS, callAny, [Event, Stat], ?MODULE, OE_Options).

%%------------------------------------------------------------
%%
%% Inherited Interfaces
%%
%%------------------------------------------------------------
oe_is_a("IDL:omg.org/CosNotifyChannelAdmin/SequenceProxyPullSupplier:1.0") -> true;
oe_is_a("IDL:omg.org/CosNotifyChannelAdmin/ProxySupplier:1.0") -> true;
oe_is_a("IDL:omg.org/CosNotification/QoSAdmin:1.0") -> true;
oe_is_a("IDL:omg.org/CosNotifyFilter/FilterAdmin:1.0") -> true;
oe_is_a("IDL:omg.org/CosNotifyComm/SequencePullSupplier:1.0") -> true;
oe_is_a("IDL:omg.org/CosNotifyComm/NotifySubscribe:1.0") -> true;
oe_is_a("IDL:oe_CosNotificationComm/Event:1.0") -> true;
oe_is_a(_) -> false.

%%------------------------------------------------------------
%%
%% Interface TypeCode
%%
%%------------------------------------------------------------
oe_tc(connect_sequence_pull_consumer) -> 
	{tk_void,[{tk_objref,"IDL:omg.org/CosNotifyComm/SequencePullConsumer:1.0",
                             "SequencePullConsumer"}],
                 []};
oe_tc('_get_MyType') -> 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_get_MyType');
oe_tc('_get_MyAdmin') -> 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_get_MyAdmin');
oe_tc('_get_priority_filter') -> 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_get_priority_filter');
oe_tc('_set_priority_filter') -> 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_set_priority_filter');
oe_tc('_get_lifetime_filter') -> 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_get_lifetime_filter');
oe_tc('_set_lifetime_filter') -> 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_set_lifetime_filter');
oe_tc(obtain_offered_types) -> 'CosNotifyChannelAdmin_ProxySupplier':oe_tc(obtain_offered_types);
oe_tc(validate_event_qos) -> 'CosNotifyChannelAdmin_ProxySupplier':oe_tc(validate_event_qos);
oe_tc(get_qos) -> 'CosNotification_QoSAdmin':oe_tc(get_qos);
oe_tc(set_qos) -> 'CosNotification_QoSAdmin':oe_tc(set_qos);
oe_tc(validate_qos) -> 'CosNotification_QoSAdmin':oe_tc(validate_qos);
oe_tc(add_filter) -> 'CosNotifyFilter_FilterAdmin':oe_tc(add_filter);
oe_tc(remove_filter) -> 'CosNotifyFilter_FilterAdmin':oe_tc(remove_filter);
oe_tc(get_filter) -> 'CosNotifyFilter_FilterAdmin':oe_tc(get_filter);
oe_tc(get_all_filters) -> 'CosNotifyFilter_FilterAdmin':oe_tc(get_all_filters);
oe_tc(remove_all_filters) -> 'CosNotifyFilter_FilterAdmin':oe_tc(remove_all_filters);
oe_tc(pull_structured_events) -> 'CosNotifyComm_SequencePullSupplier':oe_tc(pull_structured_events);
oe_tc(try_pull_structured_events) -> 'CosNotifyComm_SequencePullSupplier':oe_tc(try_pull_structured_events);
oe_tc(disconnect_sequence_pull_supplier) -> 'CosNotifyComm_SequencePullSupplier':oe_tc(disconnect_sequence_pull_supplier);
oe_tc(subscription_change) -> 'CosNotifyComm_NotifySubscribe':oe_tc(subscription_change);
oe_tc(callSeq) -> oe_CosNotificationComm_Event:oe_tc(callSeq);
oe_tc(callAny) -> oe_CosNotificationComm_Event:oe_tc(callAny);
oe_tc(_) -> undefined.

oe_get_interface() -> 
	[{"callAny", oe_CosNotificationComm_Event:oe_tc(callAny)},
	{"callSeq", oe_CosNotificationComm_Event:oe_tc(callSeq)},
	{"subscription_change", 'CosNotifyComm_NotifySubscribe':oe_tc(subscription_change)},
	{"disconnect_sequence_pull_supplier", 'CosNotifyComm_SequencePullSupplier':oe_tc(disconnect_sequence_pull_supplier)},
	{"try_pull_structured_events", 'CosNotifyComm_SequencePullSupplier':oe_tc(try_pull_structured_events)},
	{"pull_structured_events", 'CosNotifyComm_SequencePullSupplier':oe_tc(pull_structured_events)},
	{"remove_all_filters", 'CosNotifyFilter_FilterAdmin':oe_tc(remove_all_filters)},
	{"get_all_filters", 'CosNotifyFilter_FilterAdmin':oe_tc(get_all_filters)},
	{"get_filter", 'CosNotifyFilter_FilterAdmin':oe_tc(get_filter)},
	{"remove_filter", 'CosNotifyFilter_FilterAdmin':oe_tc(remove_filter)},
	{"add_filter", 'CosNotifyFilter_FilterAdmin':oe_tc(add_filter)},
	{"validate_qos", 'CosNotification_QoSAdmin':oe_tc(validate_qos)},
	{"set_qos", 'CosNotification_QoSAdmin':oe_tc(set_qos)},
	{"get_qos", 'CosNotification_QoSAdmin':oe_tc(get_qos)},
	{"validate_event_qos", 'CosNotifyChannelAdmin_ProxySupplier':oe_tc(validate_event_qos)},
	{"obtain_offered_types", 'CosNotifyChannelAdmin_ProxySupplier':oe_tc(obtain_offered_types)},
	{"_get_lifetime_filter", 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_get_lifetime_filter')},
	{"_set_lifetime_filter", 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_set_lifetime_filter')},
	{"_get_priority_filter", 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_get_priority_filter')},
	{"_set_priority_filter", 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_set_priority_filter')},
	{"_get_MyAdmin", 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_get_MyAdmin')},
	{"_get_MyType", 'CosNotifyChannelAdmin_ProxySupplier':oe_tc('_get_MyType')},
	{"connect_sequence_pull_consumer", oe_tc(connect_sequence_pull_consumer)}].




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
    "IDL:omg.org/CosNotifyChannelAdmin/SequenceProxyPullSupplier:1.0".


%%------------------------------------------------------------
%%
%% Object creation functions.
%%
%%------------------------------------------------------------

oe_create() ->
    corba:create(?MODULE, "IDL:omg.org/CosNotifyChannelAdmin/SequenceProxyPullSupplier:1.0").

oe_create_link() ->
    corba:create_link(?MODULE, "IDL:omg.org/CosNotifyChannelAdmin/SequenceProxyPullSupplier:1.0").

oe_create(Env) ->
    corba:create(?MODULE, "IDL:omg.org/CosNotifyChannelAdmin/SequenceProxyPullSupplier:1.0", Env).

oe_create_link(Env) ->
    corba:create_link(?MODULE, "IDL:omg.org/CosNotifyChannelAdmin/SequenceProxyPullSupplier:1.0", Env).

oe_create(Env, RegName) ->
    corba:create(?MODULE, "IDL:omg.org/CosNotifyChannelAdmin/SequenceProxyPullSupplier:1.0", Env, RegName).

oe_create_link(Env, RegName) ->
    corba:create_link(?MODULE, "IDL:omg.org/CosNotifyChannelAdmin/SequenceProxyPullSupplier:1.0", Env, RegName).

%%------------------------------------------------------------
%%
%% Init & terminate functions.
%%
%%------------------------------------------------------------

init(Env) ->
%% Call to implementation init
    corba:handle_init('PullerSupplier_impl', Env).

terminate(Reason, State) ->
    corba:handle_terminate('PullerSupplier_impl', Reason, State).


%%%% Operation: connect_sequence_pull_consumer
%% 
%%   Returns: RetVal
%%   Raises:  CosEventChannelAdmin::AlreadyConnected
%%
handle_call({OE_THIS, OE_Context, connect_sequence_pull_consumer, [Pull_consumer]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', connect_sequence_pull_consumer, [Pull_consumer], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: '_get_MyType'
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, '_get_MyType', []}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', '_get_MyType', [], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: '_get_MyAdmin'
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, '_get_MyAdmin', []}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', '_get_MyAdmin', [], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: '_get_priority_filter'
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, '_get_priority_filter', []}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', '_get_priority_filter', [], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: '_set_priority_filter'
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, '_set_priority_filter', [OE_Value]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', '_set_priority_filter', [OE_Value], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: '_get_lifetime_filter'
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, '_get_lifetime_filter', []}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', '_get_lifetime_filter', [], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: '_set_lifetime_filter'
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, '_set_lifetime_filter', [OE_Value]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', '_set_lifetime_filter', [OE_Value], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: obtain_offered_types
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, obtain_offered_types, [Mode]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', obtain_offered_types, [Mode], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: validate_event_qos
%% 
%%   Returns: RetVal, Available_qos
%%   Raises:  CosNotification::UnsupportedQoS
%%
handle_call({OE_THIS, OE_Context, validate_event_qos, [Required_qos]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', validate_event_qos, [Required_qos], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: get_qos
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, get_qos, []}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', get_qos, [], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: set_qos
%% 
%%   Returns: RetVal
%%   Raises:  CosNotification::UnsupportedQoS
%%
handle_call({OE_THIS, OE_Context, set_qos, [Qos]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', set_qos, [Qos], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: validate_qos
%% 
%%   Returns: RetVal, Available_qos
%%   Raises:  CosNotification::UnsupportedQoS
%%
handle_call({OE_THIS, OE_Context, validate_qos, [Required_qos]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', validate_qos, [Required_qos], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: add_filter
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, add_filter, [New_filter]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', add_filter, [New_filter], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: remove_filter
%% 
%%   Returns: RetVal
%%   Raises:  CosNotifyFilter::FilterNotFound
%%
handle_call({OE_THIS, OE_Context, remove_filter, [Filter]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', remove_filter, [Filter], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: get_filter
%% 
%%   Returns: RetVal
%%   Raises:  CosNotifyFilter::FilterNotFound
%%
handle_call({OE_THIS, OE_Context, get_filter, [Filter]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', get_filter, [Filter], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: get_all_filters
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, get_all_filters, []}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', get_all_filters, [], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: remove_all_filters
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, remove_all_filters, []}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', remove_all_filters, [], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: pull_structured_events
%% 
%%   Returns: RetVal
%%   Raises:  CosEventComm::Disconnected
%%
handle_call({OE_THIS, OE_Context, pull_structured_events, [Max_number]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', pull_structured_events, [Max_number], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: try_pull_structured_events
%% 
%%   Returns: RetVal, Has_event
%%   Raises:  CosEventComm::Disconnected
%%
handle_call({OE_THIS, OE_Context, try_pull_structured_events, [Max_number]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', try_pull_structured_events, [Max_number], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: disconnect_sequence_pull_supplier
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, disconnect_sequence_pull_supplier, []}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', disconnect_sequence_pull_supplier, [], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: subscription_change
%% 
%%   Returns: RetVal
%%   Raises:  CosNotifyComm::InvalidEventType
%%
handle_call({OE_THIS, OE_Context, subscription_change, [Added, Removed]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', subscription_change, [Added, Removed], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: callSeq
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, callSeq, [Events, Stat]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', callSeq, [Events, Stat], OE_State, OE_Context, OE_THIS, OE_From);

%%%% Operation: callAny
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, callAny, [Event, Stat]}, OE_From, OE_State) ->
  corba:handle_call('PullerSupplier_impl', callAny, [Event, Stat], OE_State, OE_Context, OE_THIS, OE_From);



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
    corba:handle_info('PullerSupplier_impl', Info, State).


code_change(OldVsn, State, Extra) ->
    corba:handle_code_change('PullerSupplier_impl', OldVsn, State, Extra).

