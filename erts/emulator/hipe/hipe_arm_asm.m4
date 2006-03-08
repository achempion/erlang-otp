changecom(`/*', `*/')dnl
/*
 * $Id$
 */
`#ifndef HIPE_ARM_ASM_H
#define HIPE_ARM_ASM_H'

/*
 * Tunables.
 */
define(LEAF_WORDS,16)dnl number of stack words for leaf functions
define(NR_ARG_REGS,3)dnl admissible values are 0 to 6, inclusive

`#define ARM_LEAF_WORDS	'LEAF_WORDS

/*
 * Reserved registers.
 */
`#define P	r11'
`#define NSP	r10'
`#define HP	r9'
`#define TEMP_LR	r8'

/*
 * Context switching macros.
 *
 * RESTORE_CONTEXT and RESTORE_CONTEXT_QUICK do not affect
 * the condition register.
 */
`#define SAVE_CONTEXT_QUICK	\
	mov	TEMP_LR, lr'

`#define RESTORE_CONTEXT_QUICK	\
	mov	lr, TEMP_LR'

`#define SAVE_CACHED_STATE	\
	str	HP, [P, #P_HP];	\
	str	NSP, [P, #P_NSP]'

`#define RESTORE_CACHED_STATE	\
	ldr	HP, [P, #P_HP];	\
	ldr	NSP, [P, #P_NSP]'

`#define SAVE_CONTEXT		\
	mov	TEMP_LR, lr;	\
	str	lr, [P, #P_NRA];	\
	SAVE_CACHED_STATE'

`#define RESTORE_CONTEXT	\
	mov	lr, TEMP_LR;	\
	RESTORE_CACHED_STATE'

/*
 * Argument (parameter) registers.
 */
`#define ARM_NR_ARG_REGS	'NR_ARG_REGS
`#define NR_ARG_REGS	'NR_ARG_REGS

define(defarg,`define(ARG$1,`$2')dnl
#`define ARG'$1	$2'
)dnl

ifelse(eval(NR_ARG_REGS >= 1),0,,
`defarg(0,`r1')')dnl
ifelse(eval(NR_ARG_REGS >= 2),0,,
`defarg(1,`r2')')dnl
ifelse(eval(NR_ARG_REGS >= 3),0,,
`defarg(2,`r3')')dnl
ifelse(eval(NR_ARG_REGS >= 4),0,,
`defarg(3,`r4')')dnl
ifelse(eval(NR_ARG_REGS >= 5),0,,
`defarg(4,`r5')')dnl
ifelse(eval(NR_ARG_REGS >= 6),0,,
`defarg(5,`r6')')dnl

/*
 * TEMP_RV:
 *	Used in nbif_stack_trap_ra to preserve the return value.
 *	Must be a C callee-save register.
 *	Must be otherwise unused in the return path.
 */
`#define TEMP_RV	r7'

/*
 * TEMP_ARG{0,1}:
 *	Used by NBIF_SAVE_RESCHED_ARGS to save argument
 *	registers in locations preserved by C.
 *	May be registers or process-private memory locations.
 *	Must not be C caller-save registers.
 *	Must not overlap with any Erlang global registers.
 */
`#define TEMP_ARG0	r7'
`#define TEMP_ARG1	r6'

dnl XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
dnl X								X
dnl X			hipe_arm_glue.S support			X
dnl X								X
dnl XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

dnl
dnl LOAD_ARG_REGS
dnl
define(LAR_1,`ldr ARG$1, [P, #P_ARG$1] ; ')dnl
define(LAR_N,`ifelse(eval($1 >= 0),0,,`LAR_N(eval($1-1))LAR_1($1)')')dnl
define(LOAD_ARG_REGS,`LAR_N(eval(NR_ARG_REGS-1))')dnl
`#define LOAD_ARG_REGS	'LOAD_ARG_REGS

dnl
dnl STORE_ARG_REGS
dnl
define(SAR_1,`str ARG$1, [P, #P_ARG$1] ; ')dnl
define(SAR_N,`ifelse(eval($1 >= 0),0,,`SAR_N(eval($1-1))SAR_1($1)')')dnl
define(STORE_ARG_REGS,`SAR_N(eval(NR_ARG_REGS-1))')dnl
`#define STORE_ARG_REGS	'STORE_ARG_REGS

dnl
dnl NSP_RETN(NPOP)
dnl NPOP should be non-zero.
dnl
define(NSP_RETN,`add	NSP, NSP, #$1
	mov pc, lr')dnl

dnl
dnl NSP_RET0
dnl
define(NSP_RET0,`mov pc, lr')dnl

dnl XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
dnl X								X
dnl X			hipe_arm_bifs.m4 support		X
dnl X								X
dnl XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

dnl
dnl NBIF_ARG(DST,ARITY,ARGNO)
dnl Access a formal parameter.
dnl It will be a memory load via NSP when ARGNO >= NR_ARG_REGS.
dnl It will be a register move when 0 <= ARGNO < NR_ARG_REGS; if
dnl the source and destination are the same, the move is suppressed.
dnl
define(NBIF_MOVE_REG,`ifelse($1,$2,`# mov	$1, $2',`mov	$1, $2')')dnl
define(NBIF_REG_ARG,`NBIF_MOVE_REG($1,ARG$2)')dnl
define(NBIF_STK_LOAD,`ldr	$1, [NSP, #$2]')dnl
define(NBIF_STK_ARG,`NBIF_STK_LOAD($1,eval(4*(($2-$3)-1)))')dnl
define(NBIF_ARG,`ifelse(eval($3 >= NR_ARG_REGS),0,`NBIF_REG_ARG($1,$3)',`NBIF_STK_ARG($1,$2,$3)')')dnl
`/* #define NBIF_ARG_1_0	'NBIF_ARG(r1,1,0)` */'
`/* #define NBIF_ARG_2_0	'NBIF_ARG(r1,2,0)` */'
`/* #define NBIF_ARG_2_1	'NBIF_ARG(r2,2,1)` */'
`/* #define NBIF_ARG_3_0	'NBIF_ARG(r1,3,0)` */'
`/* #define NBIF_ARG_3_1	'NBIF_ARG(r2,3,1)` */'
`/* #define NBIF_ARG_3_2	'NBIF_ARG(r3,3,2)` */'
`/* #define NBIF_ARG_5_0	'NBIF_ARG(r1,5,0)` */'
`/* #define NBIF_ARG_5_1	'NBIF_ARG(r2,5,1)` */'
`/* #define NBIF_ARG_5_2	'NBIF_ARG(r3,5,2)` */'
`/* #define NBIF_ARG_5_3	'NBIF_ARG(r4,5,3)` */'
`/* #define NBIF_ARG_5_4	'NBIF_ARG(r5,5,4)` */'

dnl
dnl NBIF_RET(ARITY)
dnl Generates a return from a native BIF, taking care to pop
dnl any stacked formal parameters.
dnl
define(RET_POP,`ifelse(eval($1 > NR_ARG_REGS),0,0,eval(4*($1 - NR_ARG_REGS)))')dnl
define(NBIF_RET_N,`ifelse(eval($1),0,`NSP_RET0',`NSP_RETN($1)')')dnl
define(NBIF_RET,`NBIF_RET_N(eval(RET_POP($1)))')dnl
`/* #define NBIF_RET_0	'NBIF_RET(0)` */'
`/* #define NBIF_RET_1	'NBIF_RET(1)` */'
`/* #define NBIF_RET_2	'NBIF_RET(2)` */'
`/* #define NBIF_RET_3	'NBIF_RET(3)` */'
`/* #define NBIF_RET_5	'NBIF_RET(5)` */'

dnl
dnl NBIF_SAVE_RESCHED_ARGS(ARITY)
dnl Used in the expensive_bif_interface_{1,2}() macros to copy
dnl caller-save argument registers to non-volatile locations.
dnl Currently, 1 <= ARITY <= 2, so this simply moves the arguments
dnl to C callee-save registers.
dnl
define(NBIF_MIN,`ifelse(eval($1 > $2),0,$1,$2)')dnl
define(NBIF_SVA_1,`ifelse(eval($1 < NR_ARG_REGS),0,,`mov	TEMP_ARG$1,ARG$1; ')')dnl
define(NBIF_SVA_N,`ifelse(eval($1 >= 0),0,,`NBIF_SVA_N(eval($1-1))NBIF_SVA_1($1)')')dnl
define(NBIF_SAVE_RESCHED_ARGS,`NBIF_SVA_N(eval(NBIF_MIN($1,NR_ARG_REGS)-1))')dnl
`/* #define NBIF_SAVE_RESCHED_ARGS_1 'NBIF_SAVE_RESCHED_ARGS(1)` */'
`/* #define NBIF_SAVE_RESCHED_ARGS_2 'NBIF_SAVE_RESCHED_ARGS(2)` */'

`#endif /* HIPE_ARM_ASM_H */'