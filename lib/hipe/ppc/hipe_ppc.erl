%%% -*- erlang-indent-level: 2 -*-
%%% $Id$

-module(hipe_ppc).
-export([
	 mk_temp/2,
	 mk_new_temp/1,
	 mk_new_nonallocatable_temp/1,
	 is_temp/1,
	 temp_reg/1,
	 temp_type/1,
	 temp_is_allocatable/1,

	 mk_simm16/1,
	 mk_uimm16/1,

	 mk_mfa/3,
	 mfa_mfa/1,

	 mk_prim/1,
	 is_prim/1,
	 prim_prim/1,

	 mk_sdesc/4,

	 mk_alu/4,

	 mk_b_fun/2,

	 mk_b_label/1,

	 mk_bc/3,

	 mk_bctr/1,

	 mk_bctrl/1,

	 mk_bl/3,

	 mk_blr/0,

	 mk_cmp/3,

	 mk_comment/1,

	 mk_label/1,
	 is_label/1,
	 label_label/1,

	 mk_li/2,
	 mk_li/3,
	 mk_addi/4,

	 mk_load/4,
	 mk_loadx/4,

	 mk_mcrxr/0,

	 mk_mfspr/2,

	 mk_mtspr/2,

	 mk_pseudo_bc/4,
	 negate_bcond/1,

	 mk_pseudo_call/4,
	 pseudo_call_contlab/1,
	 pseudo_call_func/1,
	 pseudo_call_sdesc/1,
	 pseudo_call_linkage/1,

	 mk_pseudo_call_prepare/1,
	 pseudo_call_prepare_nrstkargs/1,

	 mk_pseudo_li/2,

	 mk_pseudo_move/2,
	 is_pseudo_move/1,
	 pseudo_move_dst/1,
	 pseudo_move_src/1,

	 mk_pseudo_ret/1,

	 mk_pseudo_tailcall/4,
	 pseudo_tailcall_func/1,
	 pseudo_tailcall_stkargs/1,
	 pseudo_tailcall_linkage/1,

	 mk_pseudo_tailcall_prepare/0,

	 mk_store/4,
	 mk_storex/4,

	 mk_unary/3,

	 mk_defun/8,
	 defun_mfa/1,
	 defun_formals/1,
	 defun_is_closure/1,
	 defun_is_leaf/1,
	 defun_code/1,
	 defun_data/1,
	 defun_var_range/1]).

-include("hipe_ppc.hrl").

mk_temp(Reg, Type, Allocatable) ->
  #ppc_temp{reg=Reg, type=Type, allocatable=Allocatable}.
mk_temp(Reg, Type) -> mk_temp(Reg, Type, true).
mk_new_temp(Type, Allocatable) ->
  mk_temp(hipe_gensym:get_next_var(ppc), Type, Allocatable).
mk_new_temp(Type) -> mk_new_temp(Type, true).
mk_new_nonallocatable_temp(Type) -> mk_new_temp(Type, false).
is_temp(X) -> case X of #ppc_temp{} -> true; _ -> false end.
temp_reg(#ppc_temp{reg=Reg}) -> Reg.
temp_type(#ppc_temp{type=Type}) -> Type.
temp_is_allocatable(#ppc_temp{allocatable=A}) -> A.

mk_simm16(Value) -> #ppc_simm16{value=Value}.
mk_uimm16(Value) -> #ppc_uimm16{value=Value}.

mk_mfa(M, F, A) -> #ppc_mfa{m=M, f=F, a=A}.
mfa_mfa(#ppc_mfa{m=M, f=F, a=A}) -> {M, F, A}.

mk_prim(Prim) -> #ppc_prim{prim=Prim}.
is_prim(X) -> case X of #ppc_prim{} -> true; _ -> false end.
prim_prim(#ppc_prim{prim=Prim}) -> Prim.

mk_sdesc(ExnLab, FSize, Arity, Live) ->
  #ppc_sdesc{exnlab=ExnLab, fsize=FSize, arity=Arity, live=Live}.

mk_alu(AluOp, Dst, Src1, Src2) ->
  #alu{aluop=AluOp, dst=Dst, src1=Src1, src2=Src2}.

mk_b_fun(Fun, Linkage) -> #b_fun{'fun'=Fun, linkage=Linkage}.

mk_b_label(Label) -> #b_label{label=Label}.

mk_bc(BCond, Label, Pred) -> #bc{bcond=BCond, label=Label, pred=Pred}.

mk_bctr(Labels) -> #bctr{labels=Labels}.

mk_bctrl(SDesc) -> #bctrl{sdesc=SDesc}.

mk_bl(Fun, SDesc, Linkage) -> #bl{'fun'=Fun, sdesc=SDesc, linkage=Linkage}.

mk_blr() -> #blr{}.

mk_cmp(CmpOp, Src1, Src2) -> #cmp{cmpop=CmpOp, src1=Src1, src2=Src2}.

mk_comment(Term) -> #comment{term=Term}.

mk_label(Label) -> #label{label=Label}.
is_label(I) -> case I of #label{} -> true; _ -> false end.
label_label(#label{label=Label}) -> Label.

%%% Load an integer constant into a register.
mk_li(Dst, Value) -> mk_li(Dst, Value, []).

mk_li(Dst, Value, Tail) ->
  R0 = mk_temp(0, 'untagged'),
  mk_addi(Dst, R0, Value, Tail).

mk_addi(Dst, R0, Value, Tail) ->
  Low = at_l(Value),
  High = at_ha(Value),
  case High of
    0 ->
      [mk_alu('addi', Dst, R0, mk_simm16(Low)) |
       Tail];
    _ ->
      case Low of
	0 ->
	  [mk_alu('addis', Dst, R0, mk_simm16(High)) |
	   Tail];
	_ ->
	  [mk_alu('addi', Dst, R0, mk_simm16(Low)),
	   mk_alu('addis', Dst, Dst, mk_simm16(High)) |
	   Tail]
      end
  end.

at_l(Value) ->
  simm16sext(Value band 16#FFFF).

at_ha(Value) ->
  simm16sext(((Value + 16#8000) bsr 16) band 16#FFFF).

simm16sext(Value) ->
  if Value >= 32768 -> (-1 bsl 16) bor Value;
     true -> Value
  end.

mk_load(LDop, Dst, Disp, Base) ->
  #load{ldop=LDop, dst=Dst, disp=Disp, base=Base}.

mk_loadx(LdxOp, Dst, Base1, Base2) ->
  #loadx{ldxop=LdxOp, dst=Dst, base1=Base1, base2=Base2}.

mk_mcrxr() -> #mcrxr{}.

mk_mfspr(Dst, Spr) -> #mfspr{dst=Dst, spr=Spr}.

mk_mtspr(Spr, Src) -> #mtspr{spr=Spr, src=Src}.

mk_pseudo_bc(BCond, TrueLab, FalseLab, Pred) ->
  if Pred >= 0.5 ->
      mk_pseudo_bc_simple(negate_bcond(BCond), FalseLab,
			  TrueLab, 1.0-Pred);
     true ->
      mk_pseudo_bc_simple(BCond, TrueLab, FalseLab, Pred)
  end.

mk_pseudo_bc_simple(BCond, TrueLab, FalseLab, Pred) when Pred =< 0.5 ->
  #pseudo_bc{bcond=BCond, true_label=TrueLab,
	     false_label=FalseLab, pred=Pred}.

negate_bcond(BCond) ->
  case BCond of
    'lt' -> 'ge';
    'ge' -> 'lt';
    'gt' -> 'le';
    'le' -> 'gt';
    'eq' -> 'ne';
    'ne' -> 'eq';
    'so' -> 'ns';
    'ns' -> 'so'
  end.

mk_pseudo_call(FunC, SDesc, ContLab, Linkage) ->
  #pseudo_call{func=FunC, sdesc=SDesc, contlab=ContLab, linkage=Linkage}.
pseudo_call_func(#pseudo_call{func=FunC}) -> FunC.
pseudo_call_sdesc(#pseudo_call{sdesc=SDesc}) -> SDesc.
pseudo_call_contlab(#pseudo_call{contlab=ContLab}) -> ContLab.
pseudo_call_linkage(#pseudo_call{linkage=Linkage}) -> Linkage.

mk_pseudo_call_prepare(NrStkArgs) ->
  #pseudo_call_prepare{nrstkargs=NrStkArgs}.
pseudo_call_prepare_nrstkargs(#pseudo_call_prepare{nrstkargs=NrStkArgs}) ->
  NrStkArgs.

mk_pseudo_li(Dst, Imm) -> #pseudo_li{dst=Dst, imm=Imm}.

mk_pseudo_move(Dst, Src) -> #pseudo_move{dst=Dst, src=Src}.
is_pseudo_move(I) -> case I of #pseudo_move{} -> true; _ -> false end.
pseudo_move_dst(#pseudo_move{dst=Dst}) -> Dst.
pseudo_move_src(#pseudo_move{src=Src}) -> Src.

mk_pseudo_ret(NPop) -> #pseudo_ret{npop=NPop}.

mk_pseudo_tailcall(FunC, Arity, StkArgs, Linkage) ->
  #pseudo_tailcall{func=FunC, arity=Arity, stkargs=StkArgs, linkage=Linkage}.
pseudo_tailcall_func(#pseudo_tailcall{func=FunC}) -> FunC.
pseudo_tailcall_stkargs(#pseudo_tailcall{stkargs=StkArgs}) -> StkArgs.
pseudo_tailcall_linkage(#pseudo_tailcall{linkage=Linkage}) -> Linkage.

mk_pseudo_tailcall_prepare() -> #pseudo_tailcall_prepare{}.

mk_store(STop, Src, Disp, Base) ->
  #store{stop=STop, src=Src, disp=Disp, base=Base}.

mk_storex(StxOp, Src, Base1, Base2) ->
  #storex{stxop=StxOp, src=Src, base1=Base1, base2=Base2}.

mk_unary(UnOp, Dst, Src) -> #unary{unop=UnOp, dst=Dst, src=Src}.

mk_defun(MFA, Formals, IsClosure, IsLeaf, Code, Data, VarRange, LabelRange) ->
  #defun{mfa=MFA, formals=Formals, code=Code, data=Data,
	 isclosure=IsClosure, isleaf=IsLeaf,
	 var_range=VarRange, label_range=LabelRange}.
defun_mfa(#defun{mfa=MFA}) -> MFA.
defun_formals(#defun{formals=Formals}) -> Formals.
defun_is_closure(#defun{isclosure=IsClosure}) -> IsClosure.
defun_is_leaf(#defun{isleaf=IsLeaf}) -> IsLeaf.
defun_code(#defun{code=Code}) -> Code.
defun_data(#defun{data=Data}) -> Data.
defun_var_range(#defun{var_range=VarRange}) -> VarRange.