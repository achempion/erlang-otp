%%% -*- erlang-indent-level: 2 -*-
%%% $Id$

-module(hipe_ppc_defuse).
-export([insn_def/1, insn_use/1]).
-include("hipe_ppc.hrl").

%%%
%%% @doc Returns the set of temps defined by an instruction.
%%%

insn_def(I) ->
  case I of
    #alu{dst=Dst} -> [Dst];
    #load{dst=Dst} -> [Dst];
    #loadx{dst=Dst} -> [Dst];
    #mfspr{dst=Dst} -> [Dst];
    #pseudo_call{} -> call_clobbered();
    #pseudo_li{dst=Dst} -> [Dst];
    #pseudo_move{dst=Dst} -> [Dst];
    #pseudo_tailcall_prepare{} -> tailcall_clobbered();
    #unary{dst=Dst} -> [Dst];
    _ -> []
  end.

call_clobbered() ->
  [hipe_ppc:mk_temp(R, T)
   || {R,T} <- hipe_ppc_registers:call_clobbered() ++ all_fp_pseudos()].

all_fp_pseudos() -> [].	% XXX: for now

tailcall_clobbered() ->
  [hipe_ppc:mk_temp(R, T)
   || {R,T} <- hipe_ppc_registers:tailcall_clobbered() ++ all_fp_pseudos()].

%%%
%%% @doc Returns the set of temps used by an instruction.
%%%

insn_use(I) ->
  case I of
    #alu{src1=Src1,src2=Src2} -> addsrc(Src2, [Src1]);
    #blr{} ->
      [hipe_ppc:mk_temp(hipe_ppc_registers:return_value(), 'tagged')];
    #cmp{src1=Src1,src2=Src2} -> addsrc(Src2, [Src1]);
    #load{base=Base} -> [Base];
    #loadx{base1=Base1,base2=Base2} -> addtemp(Base1, [Base2]);
    #mtspr{src=Src} -> [Src];
    #pseudo_call{sdesc=#ppc_sdesc{arity=Arity}} -> arity_use(Arity);
    #pseudo_move{src=Src} -> [Src];
    #pseudo_ret{} ->
      [hipe_ppc:mk_temp(hipe_ppc_registers:return_value(), 'tagged')];
    #pseudo_tailcall{arity=Arity,stkargs=StkArgs} ->
      addsrcs(StkArgs, addtemps(tailcall_clobbered(), arity_use(Arity)));
    #store{src=Src,base=Base} -> addtemp(Src, [Base]);
    #storex{src=Src,base1=Base1,base2=Base2} ->
      addtemp(Src, addtemp(Base1, [Base2]));
    #unary{src=Src} -> [Src];
    _ -> []
  end.

arity_use(Arity) ->
  [hipe_ppc:mk_temp(R, 'tagged')
   || R <- hipe_ppc_registers:args(Arity)].

addsrcs([Arg|Args], Set) ->
  addsrcs(Args, addsrc(Arg, Set));
addsrcs([], Set) ->
  Set.

addsrc(Src, Set) ->
  case Src of
    #ppc_temp{} -> addtemp(Src, Set);
    _ -> Set
  end.

%%%
%%% Auxiliary operations on sets of temps
%%% These sets are small. No point using gb_trees, right?
%%%

addtemps([Arg|Args], Set) ->
  addtemps(Args, addtemp(Arg, Set));
addtemps([], Set) ->
  Set.

addtemp(Temp, Set) ->
  case lists:member(Temp, Set) of
    false -> [Temp|Set];
    _ -> Set
  end.