changecom(`/*', `*/')dnl
/*
 * $Id$
 */
`#ifndef HIPE_PPC_ASM_H
#define HIPE_PPC_ASM_H'

/*
 * Tunables.
 */
define(NR_ARG_REGS,4)dnl admissible values are 0 to 6, inclusive

/*
 * Standard register names.
 */
define(defreg,`define(r$1,`$1')dnl
#`define r'$1	$1')dnl
defreg(0)
defreg(1)
defreg(2)
defreg(3)
defreg(4)
defreg(5)
defreg(6)
defreg(7)
defreg(8)
defreg(9)
defreg(10)
defreg(11)
defreg(12)
defreg(13)
defreg(14)
defreg(15)
defreg(16)
defreg(17)
defreg(18)
defreg(19)
defreg(20)
defreg(21)
defreg(22)
defreg(23)
defreg(24)
defreg(25)
defreg(26)
defreg(27)
defreg(28)
defreg(29)
defreg(30)
defreg(31)

/*
 * Reserved registers.
 */
`#define P	r31'
`#define NSP	r30'
`#define HP	r29'
`#define TEMP_LR	r28'

/*
 * Context switching macros.
 *
 * RESTORE_CONTEXT and RESTORE_CONTEXT_QUICK do not affect
 * the condition register.
 */
`#define SAVE_CONTEXT_QUICK	\
	mflr	TEMP_LR'

`#define RESTORE_CONTEXT_QUICK	\
	mtlr	TEMP_LR'

`#define SAVE_CACHED_STATE	\
	stw	HP, P_HP(P);	\
	stw	NSP, P_NSP(P)'

`#define RESTORE_CACHED_STATE	\
	lwz	HP, P_HP(P);	\
	lwz	NSP, P_NSP(P)'

`#define SAVE_CONTEXT		\
	mflr	TEMP_LR;	\
	stw	TEMP_LR, P_NRA(P);\
	SAVE_CACHED_STATE'

`#define RESTORE_CONTEXT	\
	mtlr	TEMP_LR;	\
	RESTORE_CACHED_STATE'

/*
 * Argument (parameter) registers.
 */
`#define PPC_NR_ARG_REGS	'NR_ARG_REGS
`#define NR_ARG_REGS	'NR_ARG_REGS

define(defarg,`define(ARG$1,`$2')dnl
#`define ARG'$1	$2'
)dnl

ifelse(eval(NR_ARG_REGS >= 1),0,,
`defarg(0,`r4')')dnl
ifelse(eval(NR_ARG_REGS >= 2),0,,
`defarg(1,`r5')')dnl
ifelse(eval(NR_ARG_REGS >= 3),0,,
`defarg(2,`r6')')dnl
ifelse(eval(NR_ARG_REGS >= 4),0,,
`defarg(3,`r7')')dnl
ifelse(eval(NR_ARG_REGS >= 5),0,,
`defarg(4,`r8')')dnl
ifelse(eval(NR_ARG_REGS >= 6),0,,
`defarg(5,`r9')')dnl

/*
 * TEMP_ARG{0,1}:
 *	Used by NBIF_SAVE_RESCHED_ARGS to save argument
 *	registers in locations preserved by C.
 *	May be registers or process-private memory locations.
 *	Must not be C caller-save registers.
 *	Must not overlap with any Erlang global registers.
 */
`#define TEMP_ARG0	r27'
`#define TEMP_ARG1	r26'

dnl XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
dnl X								X
dnl X			hipe_ppc_glue.S support			X
dnl X								X
dnl XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

dnl
dnl LOAD_ARG_REGS
dnl
define(LAR_1,`lwz ARG$1, P_ARG$1(P) ; ')dnl
define(LAR_N,`ifelse(eval($1 >= 0),0,,`LAR_N(eval($1-1))LAR_1($1)')')dnl
define(LOAD_ARG_REGS,`LAR_N(eval(NR_ARG_REGS-1))')dnl
`#define LOAD_ARG_REGS	'LOAD_ARG_REGS

dnl
dnl STORE_ARG_REGS
dnl
define(SAR_1,`stw ARG$1, P_ARG$1(P) ; ')dnl
define(SAR_N,`ifelse(eval($1 >= 0),0,,`SAR_N(eval($1-1))SAR_1($1)')')dnl
define(STORE_ARG_REGS,`SAR_N(eval(NR_ARG_REGS-1))')dnl
`#define STORE_ARG_REGS	'STORE_ARG_REGS

dnl
dnl NSP_RETN(NPOP)
dnl NPOP should be non-zero.
dnl
define(NSP_RETN,`addi	NSP, NSP, $1
	blr')dnl

dnl
dnl NSP_RET0
dnl
define(NSP_RET0,`blr')dnl

dnl XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
dnl X								X
dnl X			hipe_ppc_bifs.m4 support		X
dnl X								X
dnl XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

dnl
dnl NBIF_ARG(DST,ARITY,ARGNO)
dnl Access a formal parameter.
dnl It will be a memory load via NSP when ARGNO >= NR_ARG_REGS.
dnl It will be a register move when 0 <= ARGNO < NR_ARG_REGS; if
dnl the source and destination are the same, the move is suppressed.
dnl
define(NBIF_MOVE_REG,`ifelse(eval($1 == $2),0,`mr	$1, $2',`# mr $1, $2')')dnl
define(NBIF_REG_ARG,`NBIF_MOVE_REG($1,ARG$2)')dnl
define(NBIF_STK_LOAD,`lwz	$1, $2(NSP)')dnl
define(NBIF_STK_ARG,`NBIF_STK_LOAD($1,eval(4*(($2-$3)-1)))')dnl
define(NBIF_ARG,`ifelse(eval($3 >= NR_ARG_REGS),0,`NBIF_REG_ARG($1,$3)',`NBIF_STK_ARG($1,$2,$3)')')dnl
`/* #define NBIF_ARG_1_0	'NBIF_ARG(r3,1,0)` */'
`/* #define NBIF_ARG_2_0	'NBIF_ARG(r3,2,0)` */'
`/* #define NBIF_ARG_2_1	'NBIF_ARG(r3,2,1)` */'
`/* #define NBIF_ARG_3_0	'NBIF_ARG(r3,3,0)` */'
`/* #define NBIF_ARG_3_1	'NBIF_ARG(r3,3,1)` */'
`/* #define NBIF_ARG_3_2	'NBIF_ARG(r3,3,2)` */'
`/* #define NBIF_ARG_5_0	'NBIF_ARG(r3,5,0)` */'
`/* #define NBIF_ARG_5_1	'NBIF_ARG(r3,5,1)` */'
`/* #define NBIF_ARG_5_2	'NBIF_ARG(r3,5,2)` */'
`/* #define NBIF_ARG_5_3	'NBIF_ARG(r3,5,3)` */'
`/* #define NBIF_ARG_5_4	'NBIF_ARG(r3,5,4)` */'

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
define(NBIF_SVA_1,`ifelse(eval($1 < NR_ARG_REGS),0,,`mr TEMP_ARG$1,ARG$1; ')')dnl
define(NBIF_SVA_N,`ifelse(eval($1 >= 0),0,,`NBIF_SVA_N(eval($1-1))NBIF_SVA_1($1)')')dnl
define(NBIF_SAVE_RESCHED_ARGS,`NBIF_SVA_N(eval(NBIF_MIN($1,NR_ARG_REGS)-1))')dnl
`/* #define NBIF_SAVE_RESCHED_ARGS_1 'NBIF_SAVE_RESCHED_ARGS(1)` */'
`/* #define NBIF_SAVE_RESCHED_ARGS_2 'NBIF_SAVE_RESCHED_ARGS(2)` */'

`#endif /* HIPE_PPC_ASM_H */'