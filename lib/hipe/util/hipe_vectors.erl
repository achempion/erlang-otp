%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%%			  VECTORS IN ERLANG
%%
%% Abstract interface to vectors, indexed from 0 to size-1.

%-define(USE_TUPLES, true).
-define(USE_GBTREES, true).

-module(hipe_vectors).
-export([new/2,
	 set/3,
	 get/2,
	 size/1,
	 vector_to_list/1,
	 list_to_vector/1,
	 list/1]).

%% ---------------------------------------------------------------------

-ifdef(USE_TUPLES).

new(N, V) ->
    erlang:make_tuple(N, V).

size(V) -> erlang:size(V).

list(Vec) ->
    index(tuple_to_list(Vec), 0).

index([X|Xs],N) ->
    [{N,X} | index(Xs,N+1)];
index([],_) ->
    [].

list_to_vector(Xs) ->
    list_to_tuple(Xs).

vector_to_list(V) ->
    tuple_to_list(V).

set(Vec,Ix,V) ->
    setelement(Ix+1,Vec,V).

get(Vec,Ix) -> element(Ix+1,Vec).

-endif. %% ifdef USE_TUPLES

%% ---------------------------------------------------------------------

-ifdef(USE_GBTREES).

new(N, V) when is_integer(N) ->
    gb_trees:from_orddict(mklist(N, V)).

mklist(N, V) ->
    mklist(0, N, V).

mklist(M, N, V) when M < N ->
    [{M, V} | mklist(M+1, N, V)];
mklist(_, _, _) ->
    [].

size(V) -> gb_trees:size(V).

list(Vec) ->
    gb_trees:to_list(Vec).

list_to_vector(Xs) ->
    gb_trees:from_orddict(index(Xs, 0)).

index([X|Xs], N) ->
    [{N, X} | index(Xs, N+1)];
index([],_) ->
    [].

vector_to_list(V) ->
    gb_trees:values(V).

set(Vec, Ix, V) ->
    gb_trees:update(Ix, V, Vec).

get(Vec, Ix) ->
    gb_trees:get(Ix, Vec).

-endif. %% ifdef USE_GBTREES
