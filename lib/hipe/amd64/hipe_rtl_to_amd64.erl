%%% -*- erlang-indent-level: 4 -*-
%%% $Id$
%%%
%%% Translate 3-address RTL code to 2-address pseudo-amd64 code.

-module(hipe_rtl_to_amd64).
-export([translate/1]).
-include("hipe_amd64.hrl").

translate(RTL) ->	% RTL function -> amd64 defun
    hipe_gensym:init(amd64),
    hipe_gensym:set_var(amd64, hipe_amd64_registers:first_virtual()),
    hipe_gensym:set_label(amd64, hipe_gensym:get_label(rtl)),
    Map0 = vmap_empty(),
    {Formals, Map1} = conv_formals(hipe_rtl:rtl_params(RTL), Map0),
    OldData = hipe_rtl:rtl_data(RTL),
    {Code0, NewData} = conv_insn_list(hipe_rtl:rtl_code(RTL), Map1, OldData),
    {RegFormals,_} = split_args(Formals),
    Code =
	case RegFormals of
	    [] -> Code0;
	    _ -> [hipe_amd64:mk_label(hipe_gensym:get_next_label(amd64)) |
		  move_formals(RegFormals, Code0)]
	end,
    IsClosure = hipe_rtl:rtl_is_closure(RTL),
    IsLeaf = hipe_rtl:rtl_is_leaf(RTL),
    hipe_amd64:mk_defun(conv_mfa(hipe_rtl:rtl_fun(RTL)),
		      Formals,
		      IsClosure,
		      IsLeaf,
		      Code,
		      NewData,
		      [], 
		      []).

conv_insn_list([H|T], Map, Data) ->
    {NewH, NewMap, NewData1} = conv_insn(H, Map, Data),
     %% io:format("~w \n  ==>\n ~w\n- - - - - - - - -\n",[H,NewH]),
    {NewT, NewData2} = conv_insn_list(T, NewMap, NewData1),
    {NewH ++ NewT, NewData2};
conv_insn_list([], _, Data) ->
    {[], Data}.

conv_insn(I, Map, Data) ->
    case hipe_rtl:type(I) of
	alu ->
	%% dst = src1 binop src2
	    BinOp = conv_binop(hipe_rtl:alu_op(I)),
	    {Dst, Map0} = conv_dst(hipe_rtl:alu_dst(I), Map),
	    {{Src1, Map1}, Imm64_1} = conv_src(hipe_rtl:alu_src1(I), Map0),
	    {{Src2, Map2}, Imm64_2} = conv_src(hipe_rtl:alu_src2(I), Map1),
	I2=	   
	  case hipe_rtl:is_shift_op(hipe_rtl:alu_op(I)) of
	    true ->
	      conv_shift(Dst, Src1, BinOp, Src2); 
	    false ->
	      conv_alu(Dst, Src1, BinOp, Src2, [])
	  end,
	{Imm64_1++Imm64_2++I2, Map2, Data};
	alub ->
	    %% dst = src1 op src2; if COND goto label
	    BinOp = conv_binop(hipe_rtl:alub_op(I)),
	    {Dst, Map0} = conv_dst(hipe_rtl:alub_dst(I), Map),
	    {{Src1, Map1},Imm64_1} = conv_src(hipe_rtl:alub_src1(I), Map0),
	    {{Src2, Map2},Imm64_2} = conv_src(hipe_rtl:alub_src2(I), Map1),
	    Cc = conv_cond(hipe_rtl:alub_cond(I)),
	    I1 = [hipe_amd64:mk_pseudo_jcc(Cc,
					 hipe_rtl:alub_true_label(I),
					 hipe_rtl:alub_false_label(I),
					 hipe_rtl:alub_pred(I))],
	    I2 = conv_alu(Dst, Src1, BinOp, Src2, I1),
	    {Imm64_1++Imm64_2++I2, Map2, Data};
	branch ->
	    %% <unused> = src1 - src2; if COND goto label
	    {{Src1, Map0},Imm64_1} = conv_src(hipe_rtl:branch_src1(I), Map),
	    {{Src2, Map1},Imm64_2} = conv_src(hipe_rtl:branch_src2(I), Map0),
	    Cc = conv_cond(hipe_rtl:branch_cond(I)),
	    I2 = conv_branch(Src1, Cc, Src2,
			     hipe_rtl:branch_true_label(I),
			     hipe_rtl:branch_false_label(I),
			     hipe_rtl:branch_pred(I)),
	    {Imm64_1++Imm64_2++I2, Map1, Data};
	call ->
	    %%	push <arg1>
	    %%	...
	    %%	push <argn>
	    %%	eax := call <Fun>; if exn goto <Fail> else goto Next
	    %% Next:
	    %%	<Dst> := eax
	    %%	goto <Cont>
	    {{Args, Map0},Insns} = 
                conv_src_list(hipe_rtl:call_arglist(I), Map),
	    {Dsts, Map1} = conv_dst_list(hipe_rtl:call_dstlist(I), Map0),
	    {Fun, Map2} = conv_fun(hipe_rtl:call_fun(I), Map1),
	    I2 = conv_call(Dsts, Fun, Args,
			   hipe_rtl:call_continuation(I),
			   hipe_rtl:call_fail(I),
			   hipe_rtl:call_type(I)),
            %% XXX Fixme: Insn stuff is probably inefficient here.
	    {Insns++I2, Map2, Data};
	comment ->
	    I2 = [hipe_amd64:mk_comment(hipe_rtl:comment_text(I))],
	    {I2, Map, Data};
	enter ->
	    {{Args, Map0},Insns} = 
                conv_src_list(hipe_rtl:enter_arglist(I), Map),
	    {Fun, Map1} = conv_fun(hipe_rtl:enter_fun(I), Map0),
	    I2 = conv_tailcall(Fun, Args, hipe_rtl:enter_type(I)),
	    {Insns++I2, Map1, Data};
	goto ->
	    I2 = [hipe_amd64:mk_jmp_label(hipe_rtl:goto_label(I))],
	    {I2, Map, Data};
	label ->
	    I2 = [hipe_amd64:mk_label(hipe_rtl:label_name(I))],
	    {I2, Map, Data};
	load ->
	    {Dst, Map0} = conv_dst(hipe_rtl:load_dst(I), Map),
	    {{Src, Map1},Insns_1} = conv_src(hipe_rtl:load_src(I), Map0),
	    {{Off, Map2},Insns_2} = conv_src(hipe_rtl:load_offset(I), Map1),
	    I2 = case {hipe_rtl:load_size(I), hipe_rtl:load_sign(I)} of
		     {byte, signed} ->
			 [hipe_amd64:mk_movsx(
                            hipe_amd64:mk_mem(Src, Off, 'byte'), Dst)];
		     {byte, unsigned} ->
			 [hipe_amd64:mk_movzx(
                            hipe_amd64:mk_mem(Src, Off, 'byte'), Dst)];
		     {int16, signed} ->
			 [hipe_amd64:mk_movsx(
                            hipe_amd64:mk_mem(Src, Off, 'int16'), Dst)];
		     {int16, unsigned} ->
			 [hipe_amd64:mk_movzx(
                            hipe_amd64:mk_mem(Src, Off, 'int16'), Dst)];
		     {int32, signed} ->
			 [hipe_amd64:mk_movsx(
                            hipe_amd64:mk_mem(Src, Off, 'int32'), Dst)];
		     {int32, unsigned} ->
			 [hipe_amd64:mk_movzx(
                            hipe_amd64:mk_mem(Src, Off, 'int32'), Dst)];
		     _ ->
			 Type = typeof_dst(Dst),
			 case hipe_amd64:is_imm(Src) of
			     false ->
				 [hipe_amd64:mk_move(
                                    hipe_amd64:mk_mem(Src, Off, Type), Dst)];
			     true ->
				 %% XXX: this is temporary until
				 %% rtl_prop gets fixed
				 io:format(standard_io, "hipe_rtl_to_amd64:"
                                           "ERROR: ignoring bogus RTL"
                                           "load ~w\n", [I]),
				 [hipe_amd64:mk_comment(I)]
			 end
		 end,
	    {Insns_1++Insns_2++I2, Map2, Data};
	load_address ->
	    {Dst, Map0} = conv_dst(hipe_rtl:load_address_dst(I), Map),
	    Addr = hipe_rtl:load_address_address(I),
	    Type = hipe_rtl:load_address_type(I),
            Src = hipe_amd64:mk_imm_from_addr(Addr, Type),
	    case Type of
		c_const -> %% 32 bits
		    I2 = [hipe_amd64:mk_move(Src, Dst)];
		_ ->
		    I2 = [hipe_amd64:mk_move64(Src, Dst)]
	    end,
	    {I2, Map0, Data};
	load_atom ->
	    {Dst, Map0} = conv_dst(hipe_rtl:load_atom_dst(I), Map),
	    Src = hipe_amd64:mk_imm_from_atom(hipe_rtl:load_atom_atom(I)),
	    I2 = [hipe_amd64:mk_move(Src, Dst)],
	    {I2, Map0, Data};
	move ->
	    {Dst, Map0} = conv_dst(hipe_rtl:move_dst(I), Map),
	    {{Src, Map1}, Imm64} = conv_src(hipe_rtl:move_src(I), Map0),
            I2 = [hipe_amd64:mk_move(Src, Dst)],
	    {Imm64++I2, Map1, Data};
	begin_handler ->	% for SPARC this is eliminated by hipe_frame
	    [Dst0] = hipe_rtl:begin_handler_varlist(I),
	    {Dst1,Map1} = conv_dst(Dst0, Map),
	    Src = mk_eax(),
	    {[hipe_amd64:mk_move(Src, Dst1)], Map1, Data};
	return ->
	    %% TODO: multiple-value returns
	    {{[Arg], Map0},Imm64} = 
                conv_src_list(hipe_rtl:return_varlist(I), Map),
	    Dst = mk_eax(),
	    I2 = [hipe_amd64:mk_move(Arg, Dst),
		  hipe_amd64:mk_ret(-1)],	% frame will fill in npop later
	    {Imm64++I2, Map0, Data};
	store ->
	    {Ptr, Map0} = conv_dst(hipe_rtl:store_base(I), Map),
	    {{Src, Map1},Imm64_1} = conv_src(hipe_rtl:store_src(I), Map0),
	    {{Off, Map2},Imm64_2} = conv_src(hipe_rtl:store_offset(I), Map1),
	    case hipe_rtl:store_size(I) of
		word ->
		    Type = typeof_src(Src);
		Type ->
		    ok
	    end,
	    I2 = [hipe_amd64:mk_move(Src, hipe_amd64:mk_mem(Ptr, Off, Type))],
	    {Imm64_1++Imm64_2++I2, Map2, Data};
	switch ->	% this one also updates Data :-(
	    %% from hipe_rtl2sparc, but we use a hairy addressing mode
	    %% instead of doing the arithmetic manually
	    Labels = hipe_rtl:switch_labels(I),
	    LMap = [{label,L} || L <- Labels],
	    {NewData, JTabLab} =
		case hipe_rtl:switch_sort_order(I) of
		    [] ->
			hipe_consttab:insert_block(Data, word, LMap);
		    SortOrder ->
			hipe_consttab:insert_sorted_block(
			  Data, word, LMap, SortOrder)
		end,
	    %% no immediates allowed here
	    {Index, Map1} = conv_dst(hipe_rtl:switch_src(I), Map),
            JTabReg = hipe_amd64:mk_new_temp('untagged'),
            JTabImm = hipe_amd64:mk_imm_from_addr(JTabLab,constant),
	    I2 = [hipe_amd64:mk_move64(JTabImm, JTabReg),
                  hipe_amd64:mk_jmp_switch(Index, JTabReg, Labels)],
	    {I2, Map1, NewData};
	fload ->
	    {Dst, Map0} = conv_dst(hipe_rtl:fload_dst(I), Map),
	    {{Src, Map1},_} = conv_src(hipe_rtl:fload_src(I), Map0),
            {{Off, Map2},_} = conv_src(hipe_rtl:fload_offset(I), Map1),
            I2 = [hipe_amd64:mk_fmove(
                    hipe_amd64:mk_mem(Src, Off, 'double'),Dst)],
	    {I2, Map2, Data};
	fstore ->
	    {Dst, Map0} = conv_dst(hipe_rtl:fstore_base(I), Map),
	    {{Src, Map1},_} = conv_src(hipe_rtl:fstore_src(I), Map0),
            {{Off, Map2},_} = conv_src(hipe_rtl:fstore_offset(I), Map1),
            I2 = [hipe_amd64:mk_fmove(
                    Src, hipe_amd64:mk_mem(Dst, Off, 'double'))],	    
	    {I2, Map2, Data};
	fp ->
	    {Dst, Map0} = conv_dst(hipe_rtl:fp_dst(I), Map),
	    {{Src1, Map1},_} = conv_src(hipe_rtl:fp_src1(I), Map0),
            {{Src2, Map2},_} = conv_src(hipe_rtl:fp_src2(I), Map1),
            Op = hipe_rtl:fp_op(I),
            I2 = conv_fp_binop(Dst, Src1, Op, Src2),
	    {I2, Map2, Data};
	fp_unop ->
	    {Dst, Map0} = conv_dst(hipe_rtl:fp_unop_dst(I), Map),
	    {{Src, Map1},_} = conv_src(hipe_rtl:fp_unop_src(I), Map0),
	    Op = hipe_rtl:fp_unop_op(I),	    
	    I2 = conv_fp_unop(Dst, Src, Op),
	    {I2, Map1, Data};
	fmove ->
	    {Dst, Map0} = conv_dst(hipe_rtl:fmove_dst(I), Map),
	    {{Src, Map1},_} = conv_src(hipe_rtl:fmove_src(I), Map0),
	    I2 = [hipe_amd64:mk_fmove(Src, Dst)],
	    {I2, Map1, Data};
	fconv ->
	    {Dst, Map0} = conv_dst(hipe_rtl:fconv_dst(I), Map),
	    {{Src, Map1},_} = conv_src(hipe_rtl:fconv_src(I), Map0),
	    I2 = [hipe_amd64:mk_fmove(Src, Dst)],
	    {I2, Map1, Data};
	X ->
	    %% gctest??
	    %% jmp, jmp_link, jsr, esr, multimove,
	    %% stackneed, pop_frame, restore_frame, save_frame
	    throw({?MODULE, {"unknown RTL instruction", X}})
    end.

%%% Finalise the conversion of a 3-address ALU operation, taking
%%% care to not introduce more temps and moves than necessary.

conv_alu(Dst, Src1, BinOp, Src2, Tail) ->
    case same_opnd(Dst, Src1) of
	true ->			% x = x op y
	    [hipe_amd64:mk_alu(BinOp, Src2, Dst) | Tail];		% x op= y
	false ->		% z = x op y, where z != x
	    case same_opnd(Dst, Src2) of
		false ->	% z = x op y, where z != x && z != y
		    [hipe_amd64:mk_move(Src1, Dst),			% z = x
		     hipe_amd64:mk_alu(BinOp, Src2, Dst) | Tail];	% z op= y
		true ->		% y = x op y, where y != x
		    case binop_commutes(BinOp) of
			true ->	% y = y op x
			    [hipe_amd64:mk_alu(BinOp, Src1, Dst) | Tail]; % y op= x
			false ->% y = x op y, where op doesn't commute
			    Tmp = clone_dst(Dst),
			    [hipe_amd64:mk_move(Src1, Tmp),		% t = x
			     hipe_amd64:mk_alu(BinOp, Src2, Tmp),	% t op= y
			     hipe_amd64:mk_move(Tmp, Dst) | Tail]	% y = t
		    end
	    end
    end.



conv_shift(Dst, Src1, BinOp, Src2) ->
  {NewSrc2,I1} =
    case hipe_amd64:is_imm(Src2) of 
      true ->
	{Src2, []};
      false ->
	NewSrc = hipe_amd64:mk_temp(hipe_amd64_registers:rcx(), 'untagged'),
	{NewSrc, [hipe_amd64:mk_move(Src2, NewSrc)]}
    end,
  I2 = case same_opnd(Dst, Src1) of
	 true ->			% x = x op y
	   [hipe_amd64:mk_shift(BinOp, NewSrc2, Dst)];		% x op= y
	 false ->		% z = x op y, where z != x
	   case same_opnd(Dst, Src2) of
	     false ->	% z = x op y, where z != x && z != y
	       [hipe_amd64:mk_move(Src1, Dst),			% z = x
		hipe_amd64:mk_shift(BinOp, NewSrc2, Dst)];	% z op= y
	     true ->	    % y = x op y, no shift op commutes
	       Tmp = clone_dst(Dst),
	       [hipe_amd64:mk_move(Src1, Tmp),		% t = x
		hipe_amd64:mk_shift(BinOp, NewSrc2, Tmp),	% t op= y
		hipe_amd64:mk_move(Tmp, Dst)]	% y = t
	   end
       end,
  I1 ++ I2.

%%% Finalise the conversion of a conditional branch operation, taking
%%% care to not introduce more temps and moves than necessary.

conv_branch(Src1, Cc, Src2, TrueLab, FalseLab, Pred) ->
    case hipe_amd64:is_imm(Src1) of
	false ->
	    mk_branch(Src1, Cc, Src2, TrueLab, FalseLab, Pred);
	true ->
	    case hipe_amd64:is_imm(Src2) of
		false ->
		    NewCc = commute_cc(Cc),
		    mk_branch(Src2, NewCc, Src1, TrueLab, FalseLab, Pred);
		true ->
		    %% two immediates, let the optimiser clean it up
		    Tmp = new_untagged_temp(),
		    [hipe_amd64:mk_move(Src1, Tmp) |
		     mk_branch(Tmp, Cc, Src2, TrueLab, FalseLab, Pred)]
	    end
    end.

mk_branch(Src1, Cc, Src2, TrueLab, FalseLab, Pred) ->
    %% PRE: not(is_imm(Src1))
    [hipe_amd64:mk_cmp(Src2, Src1),
     hipe_amd64:mk_pseudo_jcc(Cc, TrueLab, FalseLab, Pred)].

%%% Convert an RTL ALU or ALUB binary operator.

conv_binop(BinOp) ->
    case BinOp of
	'add'	-> 'add';
	'sub'	-> 'sub';
	'or'	-> 'or';
	'and'	-> 'and';
	'xor'	-> 'xor';
	'sll'	-> 'shl';
	'srl'	-> 'shr';
	'sra'	-> 'sar';
	%% mul, andnot ???
	_	-> exit({?MODULE, {"unknown binop", BinOp}})
    end.

binop_commutes(BinOp) ->
    case BinOp of
	'add'	-> true;
	'or'	-> true;
	'and'	-> true;
	'xor'	-> true;
	'fadd'  -> true;
	'fmul'  -> true;
	_	-> false
    end.

%%% Convert an RTL conditional operator.

conv_cond(Cond) ->
    case Cond of
	eq	-> 'e';
	ne	-> 'ne';
	gt	-> 'g';
	gtu	-> 'a';
	ge	-> 'ge';
	geu	-> 'ae';
	lt	-> 'l';
	ltu	-> 'b';
	le	-> 'le';
	leu	-> 'be';
	overflow -> 'o';
	not_overflow -> 'no';
	_	-> exit({?MODULE, {"unknown rtl cond", Cond}})
    end.

commute_cc(Cc) ->	% if x Cc y, then y commute_cc(Cc) x
    case Cc of
	'e'	-> 'e';		% ==, ==
	'ne'	-> 'ne';	% !=, !=
	'g'	-> 'l';		% >, <
	'a'	-> 'b';		% >u, <u
	'ge'	-> 'le';	% >=, <=
	'ae'	-> 'be';	% >=u, <=u
	'l'	-> 'g';		% <, >
	'b'	-> 'a';		% <u, >u
	'le'	-> 'ge';	% <=, >=
	'be'	-> 'ae';	% <=u, >=u
	%% overflow/not_overflow: n/a
	_	-> exit({?MODULE, {"unknown cc", Cc}})
    end.

%%% Test if Dst and Src are the same operand.

same_opnd(Dst, Src) -> Dst =:= Src.

%%% Finalise the conversion of a tailcall instruction.

conv_tailcall(Fun, Args, Linkage) ->
    Arity = length(Args),
    {RegArgs,StkArgs} = split_args(Args),
    move_actuals(RegArgs,
		 [hipe_amd64:mk_pseudo_tailcall_prepare(),
		  hipe_amd64:mk_pseudo_tailcall(Fun, Arity, StkArgs, Linkage)]).

split_args(Args) ->
    split_args(0, hipe_amd64_registers:nr_args(), Args, []).
split_args(I, N, [Arg|Args], RegArgs) when I < N ->
    Reg = hipe_amd64_registers:arg(I),
    Temp = hipe_amd64:mk_temp(Reg, 'tagged'),
    split_args(I+1, N, Args, [{Arg,Temp}|RegArgs]);
split_args(_, _, StkArgs, RegArgs) ->
    {RegArgs, StkArgs}.

move_actuals([], Rest) -> Rest;
move_actuals([{Src,Dst}|Actuals], Rest) ->
    move_actuals(Actuals, [hipe_amd64:mk_move(Src, Dst) | Rest]).

move_formals([], Rest) -> Rest;
move_formals([{Dst,Src}|Formals], Rest) ->
    move_formals(Formals, [hipe_amd64:mk_move(Src, Dst) | Rest]).

%%% Finalise the conversion of a call instruction.

conv_call(Dsts, Fun, Args, ContLab, ExnLab, Linkage) ->
    case hipe_amd64:is_prim(Fun) of
	true ->
	    conv_primop_call(Dsts, Fun, Args, ContLab, ExnLab, Linkage);
	false ->
	    conv_general_call(Dsts, Fun, Args, ContLab, ExnLab, Linkage)
    end.

conv_primop_call(Dsts, Prim, Args, ContLab, ExnLab, Linkage) ->
    case hipe_amd64:prim_prim(Prim) of
	'fwait' ->
	    conv_fwait_call(Dsts, Args, ContLab, ExnLab, Linkage);
	_ ->
	    conv_general_call(Dsts, Prim, Args, ContLab, ExnLab, Linkage)
    end.

conv_fwait_call([], [], [], [], not_remote) ->
    [hipe_amd64:mk_fp_unop('fwait', [])].

conv_general_call(Dsts, Fun, Args, ContLab, ExnLab, Linkage) ->
    %% The backend does not support pseudo_calls without a
    %% continuation label, so we make sure each call has one.
    {RealContLab, Tail} =
	case do_call_results(Dsts) of
	    [] ->
		%% Avoid consing up a dummy basic block if the moves list
		%% is empty, as is typical for calls to suspend/0.
		%% This should be subsumed by a general "optimise the CFG"
		%% module, and could probably be removed.
                case ContLab of
	            [] ->
                        NewContLab = hipe_gensym:get_next_label(amd64),
                        {NewContLab, [hipe_amd64:mk_label(NewContLab)]};
                    _ ->
		        {ContLab, []}
                end;
	    Moves ->
		%% Change the call to continue at a new basic block.
		%% In this block move the result registers to the Dsts,
		%% then continue at the call's original continuation.
		%%
	        %% This should be fixed to propagate "fallthrough calls"
                %% When the rest of the backend supports them.
                NewContLab = hipe_gensym:get_next_label(amd64),
	        case ContLab of
	            [] -> %% This is just a fallthrough
                          %% No jump back after the moves.
                        {NewContLab,
		         [hipe_amd64:mk_label(NewContLab) |
		         Moves]};
	            _ ->  %% The call has a continuation
                          %% jump to it.
		        {NewContLab,
		         [hipe_amd64:mk_label(NewContLab) |
		         Moves ++
		         [hipe_amd64:mk_jmp_label(ContLab)]]}
	        end
	end,
    SDesc = hipe_amd64:mk_sdesc(ExnLab, 0, length(Args), {}),
    CallInsn = hipe_amd64:mk_pseudo_call(Fun, SDesc, RealContLab, Linkage),
    {RegArgs,StkArgs} = split_args(Args),
    do_push_args(StkArgs, move_actuals(RegArgs, [CallInsn | Tail])).

do_push_args([Arg|Args], Tail) ->
    [hipe_amd64:mk_push(Arg) | do_push_args(Args, Tail)];
do_push_args([], Tail) ->
    Tail.

do_call_results([]) ->
    [];
do_call_results([Dst]) ->
    EAX = hipe_amd64:mk_temp(hipe_amd64_registers:rax(), 'tagged'),
    MV = hipe_amd64:mk_move(EAX, Dst),
    [MV];
do_call_results(Dsts) ->
    exit({?MODULE,do_call_results,Dsts}).

%%% Convert a 'fun' operand (MFA, prim, or temp)

conv_fun(Fun, Map) ->
    case hipe_rtl:is_var(Fun) of
	true ->
	    conv_dst(Fun, Map);
	false ->
	    case hipe_rtl:is_reg(Fun) of
		true ->
		    conv_dst(Fun, Map);
		false ->
		    case Fun of
			Prim when is_atom(Prim) ->
			    {hipe_amd64:mk_prim(Prim), Map};
			{M,F,A} when is_atom(M), is_atom(F), is_integer(A) ->
			    {hipe_amd64:mk_mfa(M,F,A), Map};
			_ ->
			    exit({?MODULE,conv_fun,Fun})
		    end
	    end
    end.

%%% Convert an MFA operand.

conv_mfa({M,F,A}) ->
    hipe_amd64:mk_mfa(M, F, A).

%%% Convert an RTL source operand (imm/var/reg).

conv_src(Opnd, Map) ->
    case hipe_rtl:is_imm(Opnd) of
	true ->
            ImmVal = hipe_rtl:imm_value(Opnd),
            case is_imm64(ImmVal) of
                true ->
                    Temp = hipe_amd64:mk_new_temp('untagged'),
                    {{Temp, Map}, 
                     [hipe_amd64:mk_move64(hipe_amd64:mk_imm(ImmVal), Temp)]};
                false ->
                    {{hipe_amd64:mk_imm(ImmVal), Map}, []}
            end;
        false ->
	    {conv_dst(Opnd, Map), []}
    end.

is_imm64(Value) when is_integer(Value) ->
    (Value < -(1 bsl (32 - 1))) or (Value > (1 bsl (32 - 1)) - 1);
is_imm64({_,atom})    -> false; %% Atoms are 32 bits...
is_imm64({_,c_const}) -> false; %% ...as are c_const:s...
is_imm64({_,_})       -> true . %% ...other relocs are 64 bits

conv_src_list([O|Os], Map) ->
    {{V, Map1},NewInstr} = conv_src(O, Map),
    {{Vs, Map2},Instrs} = conv_src_list(Os, Map1),
    {{[V|Vs], Map2},Instrs++NewInstr};
conv_src_list([], Map) ->
    {{[], Map},[]}.

%%% Convert an RTL destination operand (var/reg).

conv_dst(Opnd, Map) ->
    {Name, Type} =
	case hipe_rtl:is_var(Opnd) of
	    true ->
		{hipe_rtl:var_index(Opnd), 'tagged'};
	    false ->
		case hipe_rtl:is_fpreg(Opnd) of
		    true ->
			{hipe_rtl:fpreg_index(Opnd), 'double'};
		    false ->
			{hipe_rtl:reg_index(Opnd), 'untagged'}
		end
	end,
    case hipe_amd64_registers:is_precoloured(Name) of
	true ->
	    case hipe_amd64_registers:proc_offset(Name) of
		false ->
		    {hipe_amd64:mk_temp(Name, Type), Map};
		Offset ->
		    Preg = hipe_amd64_registers:proc_pointer(),
		    Pbase = hipe_amd64:mk_temp(Preg, 'untagged'),
		    Poff = hipe_amd64:mk_imm(Offset),
		    {hipe_amd64:mk_mem(Pbase, Poff, Type), Map}
	    end;
	false ->
	    case vmap_lookup(Map, Opnd) of
		{value, {_, NewTemp}} ->
		    {NewTemp, Map};
		false ->
		    NewTemp = hipe_amd64:mk_new_temp(Type),
		    {NewTemp, vmap_bind(Map, Opnd, NewTemp)}
	    end
    end.

conv_dst_list([O|Os], Map) ->
    {Dst, Map1} = conv_dst(O, Map),
    {Dsts, Map2} = conv_dst_list(Os, Map1),
    {[Dst|Dsts], Map2};
conv_dst_list([], Map) ->
    {[], Map}.

conv_formals(Os, Map) ->
    conv_formals(hipe_amd64_registers:nr_args(), Os, Map, []).

conv_formals(N, [O|Os], Map, Res) ->
    Type =
	case hipe_rtl:is_var(O) of
	    true -> 'tagged';
	    false ->'untagged'
	end,
    Dst =
	if N > 0 -> hipe_amd64:mk_new_temp(Type);	% allocatable
	   true -> hipe_amd64:mk_new_nonallocatable_temp(Type)
	end,
    Map1 = vmap_bind(Map, O, Dst),
    conv_formals(N-1, Os, Map1, [Dst|Res]);
conv_formals(_, [], Map, Res) ->
    {lists:reverse(Res), Map}.

%%% typeof_src -- what's src's type?

typeof_src(Src) ->
    case hipe_amd64:is_imm(Src) of
	true ->
	    'untagged';
	_ ->
	    typeof_dst(Src)
    end.

%%% typeof_dst -- what's dst's type?

typeof_dst(Dst) ->
    case hipe_amd64:is_temp(Dst) of
	true ->
	    hipe_amd64:temp_type(Dst);
	_ ->
	    hipe_amd64:mem_type(Dst)
    end.

%%% clone_dst -- conjure up a scratch reg with same type as dst

clone_dst(Dst) ->
    hipe_amd64:mk_new_temp(typeof_dst(Dst)).

%%% new_untagged_temp -- conjure up an untagged scratch reg

new_untagged_temp() ->
    hipe_amd64:mk_new_temp('untagged').

%%% Cons up a tagged '%eax' Temp.

mk_eax() ->
    hipe_amd64:mk_temp(hipe_amd64_registers:rax(), 'tagged').

%%% Map from RTL var/reg operands to amd64 temps.

vmap_empty() ->
    [].

vmap_lookup(VMap, Opnd) ->
    lists:keysearch(Opnd, 1, VMap).

vmap_bind(VMap, Opnd, Temp) ->
    [{Opnd, Temp} | VMap].

conv_fp_unop(Dst, Src, Op) ->
    case same_opnd(Dst, Src) of
	true  -> 
	    [hipe_amd64:mk_fp_unop(Op, Dst)];
	false ->
	    [hipe_amd64:mk_fmove(Src, Dst),
	     hipe_amd64:mk_fp_unop(Op, Dst)]
    end.

conv_fp_binop(Dst, Src1, Op, Src2) ->
    case same_opnd(Dst, Src1) of
	true ->			% x = x op y
	    [hipe_amd64:mk_fp_binop(Op, Src2, Dst)];		% x op= y
	false ->		% z = x op y, where z != x
	    case same_opnd(Dst, Src2) of
		false ->	% z = x op y, where z != x && z != y
		    [hipe_amd64:mk_fmove(Src1, Dst),			% z = x
		     hipe_amd64:mk_fp_binop(Op, Src2, Dst)];	% z op= y
		true ->		% y = x op y, where y != x
		    case binop_commutes(Op) of
			true ->	% y = y op x
			    [hipe_amd64:mk_fp_binop(Op, Src1, Dst)]; % y op= x
			false ->% y = x op y, where op doesn't commute
			    Op0 = reverse_op(Op),
			    [hipe_amd64:mk_fp_binop(Op0, Src1, Dst)]
		    end
	    end
    end.

reverse_op(Op) ->
    case Op of
	'fsub' -> 'fsubr';
	'fdiv' -> 'fdivr'
    end.