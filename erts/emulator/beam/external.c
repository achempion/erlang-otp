/* ``The contents of this file are subject to the Erlang Public License,
 * Version 1.1, (the "License"); you may not use this file except in
 * compliance with the License. You should have received a copy of the
 * Erlang Public License along with this software. If not, it can be
 * retrieved via the world wide web at http://www.erlang.org/.
 * 
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.
 * 
 * The Initial Developer of the Original Code is Ericsson Utvecklings AB.
 * Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
 * AB. All Rights Reserved.''
 * 
 *     $Id$
 */
/*  Implementation of the erlang external format 
 *
 *  And a nice cache mechanism which is used just to send a
 *  index indicating a specific atom to a remote node instead of the
 *  entire atom.
 */

#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif

#include "sys.h"
#include "erl_vm.h"
#include "global.h"
#include "erl_process.h"
#include "error.h"
#include "external.h"
#include "bif.h"
#include "big.h"
#include "dist.h"
#include "erl_binary.h"
#include "erl_vector.h"
#include "zlib.h"

#ifdef HIPE
#include "hipe_mode_switch.h"
#endif
#define in_area(ptr,start,nbytes) ((Uint)((char*)(ptr) - (char*)(start)) < (nbytes))

#define MAX_STRING_LEN 0xffff
#define dec_set_creation(nodename,creat)				\
  (((nodename) == erts_this_node->sysname && (creat) == ORIG_CREATION)	\
   ? erts_this_node->creation						\
   : (creat))

/*
 *   Valid creations for nodes are 1, 2, or 3. 0 can also be sent
 *   as creation, though. When 0 is used as creation, the real creation
 *   is unknown. Creation 0 on data will be changed to current
 *   creation of the node which it belongs to when it enters
 *   that node.
 *       This typically happens when a remote pid is created with
 *   list_to_pid/1 and then sent to the remote node. This behavior 
 *   has the undesirable effect that a pid can be passed between nodes,
 *   and as a result of that not being equal to itself (the pid that
 *   comes back isn't equal to the original pid).
 *
 */



extern int dist_buf_size;
extern byte *dist_buf;

static byte* enc_term(DistEntry*, Eterm, byte*, Uint32);
static byte* enc_atom(DistEntry*, Eterm, byte*);
static byte* enc_pid(DistEntry*, Eterm, byte*);
static byte* dec_term(DistEntry*, Eterm**, byte*, ErlOffHeap*, Eterm*);
static byte* dec_atom(DistEntry*, byte*, Eterm*);
static byte* dec_pid(DistEntry*, Eterm**, byte*, ErlOffHeap*, Eterm*);
static byte* dec_hashed_atom(DistEntry*, byte*, Eterm*);
static byte* dec_and_insert_hashed_atom(DistEntry*, byte*, Eterm*);
static Eterm term_to_binary(Process* p, Eterm Term, int compressed);
static int decode_size2(byte *ep, byte* endp);

static Uint encode_size_struct2(Eterm, unsigned);


/**********************************************************************/

Eterm
term_to_binary_1(Process* p, Eterm Term)
{
    return term_to_binary(p, Term, 0);
}

Eterm
term_to_binary_2(Process* p, Eterm Term, Eterm Flags)
{
    int compressed = 0;

    while (is_list(Flags)) {
	Eterm arg = CAR(list_val(Flags));
	if (arg == am_compressed) {
	    compressed = 1;
	} else {
	error:
	    BIF_ERROR(p, BADARG);
	}
	Flags = CDR(list_val(Flags));
    }
    if (is_not_nil(Flags)) {
	goto error;
    }

    return term_to_binary(p, Term, compressed);
}

BIF_RETTYPE binary_to_term_1(BIF_ALIST_1)
BIF_ADECL_1
{
    int heap_size;
    Eterm res;
    Eterm* hp;
    Eterm* endp;
    size_t size;
    byte* bytes;
    byte* dest_ptr = NULL;
    byte* ep;

    if (is_not_binary(BIF_ARG_1)) {
    error:
	BIF_ERROR(BIF_P, BADARG);
    }
    size = binary_size(BIF_ARG_1);
    GET_BINARY_BYTES(BIF_ARG_1, bytes);
    if (size < 1 || bytes[0] != VERSION_MAGIC) {
	goto error;
    }
    bytes++;
    size--;
    if (size >= 5 && bytes[0] == COMPRESSED) {
	uLongf dest_len;

	dest_len = get_int32(bytes+1);
	dest_ptr = safe_alloc_from(320, dest_len);
	if (uncompress(dest_ptr, &dest_len, bytes+5, size-5) != Z_OK) {
	    sys_free(dest_ptr);
	    goto error;
	}
	bytes = dest_ptr;
	size = dest_len;
    }

    heap_size = decode_size2(bytes, bytes+size);
    if (heap_size == -1) {
	goto error;
    }
    hp = HAlloc(BIF_P, heap_size);
    endp = hp + heap_size;
    ep = dec_term(NULL, &hp, bytes, &MSO(BIF_P), &res);
    if (dest_ptr != NULL) {
	sys_free(dest_ptr);
    }
    if (ep == NULL) {
	goto error;
    }
    if (hp > endp) {
	erl_exit(1, ":%s, line %d: heap overrun by %d words(s)\n",
		 __FILE__, __LINE__, hp-endp);
    }
    HRelease(BIF_P, hp);
    return res;
}

Eterm
external_size_1(Process* p, Eterm Term)
{
    return make_small_or_big(encode_size_struct(Term,TERM_TO_BINARY_DFLAGS), p);
}

static Eterm
term_to_binary(Process* p, Eterm Term, int compressed)
{
    int size;
    Eterm bin;
    size_t real_size;
    byte* endp;

    size = encode_size_struct(Term, TERM_TO_BINARY_DFLAGS);

    if (compressed) {
	byte buf[256];
	byte* bytes = buf;
	byte* out_bytes;
	uLongf dest_len;

	if (sizeof(buf) < size) {
	    bytes = safe_alloc_from(330, size);
	}

	if ((endp = enc_term(NULL, Term, bytes, TERM_TO_BINARY_DFLAGS))
	    == NULL) {
	    erl_exit(1, "%s, line %d: bad term: %x\n",
		     __FILE__, __LINE__, Term);
	}
	real_size = endp - bytes;
	if (real_size > size) {
	    erl_exit(1, "%s, line %d: buffer overflow: %d word(s)\n",
		     __FILE__, __LINE__, real_size - size);
	}

	/*
	 * We don't want to compress if compression actually increases the size.
	 * Therefore, don't give zlib more out buffer than the size of the
	 * uncompressed external format (minus the 5 bytes needed for the
	 * COMPRESSED tag). If zlib returns any error, we'll revert to using
	 * the original uncompressed external term format.
	 */

	if (real_size < 5) {
	    dest_len = 0;
	} else {
	    dest_len = real_size - 5;
	}
	bin = new_binary(p, NULL, real_size+1);
	GET_BINARY_BYTES(bin, out_bytes);
	out_bytes[0] = VERSION_MAGIC;
	if (compress(out_bytes+6, &dest_len, bytes, real_size) != Z_OK) {
	    sys_memcpy(out_bytes+1, bytes, real_size);
	    bin = erts_realloc_binary(bin, real_size+1);
	} else {
	    out_bytes[1] = COMPRESSED;
	    put_int32(real_size, out_bytes+2);
	    bin = erts_realloc_binary(bin, dest_len+6);
	}
	if (bytes != buf) {
	    sys_free(bytes);
	}
	return bin;
    } else {
	byte* bytes;

	bin = new_binary(p, (byte *)NULL, size);
	GET_BINARY_BYTES(bin, bytes);
	
	bytes[0] = VERSION_MAGIC;
	if ((endp = enc_term(NULL, Term, bytes+1, TERM_TO_BINARY_DFLAGS))	
	    == NULL) {
	    erl_exit(1, "%s, line %d: bad term: %x\n",
		     __FILE__, __LINE__, Term);
	}
	real_size = endp - bytes;
	if (real_size > size) {
	    erl_exit(1, "%s, line %d: buffer overflow: %d word(s)\n",
		     __FILE__, __LINE__, endp - (bytes + size));
	}
	return erts_realloc_binary(bin, real_size);
    }
}

/*
 * This function fills ext with the external format of atom.
 * If it's an old atom we just supply an index, otherwise
 * we insert the index _and_ the entire atom. This way the receiving side
 * does not have to perform an hash on the etom to locate it, and
 * we save a lot of space on the wire.
 */

static byte*
enc_atom(DistEntry *dep, Eterm atom, byte *ep)
{
    Eterm* ce;
    Uint ix;
    int i, j;

    ASSERT(is_atom(atom));

    /*
     * term_to_binary/1,2 and the initial distribution message
     * don't use the cache.
     */
    if (!dep || (dep->cache == NULL)) { 
	i = atom_val(atom);
	j = atom_tab(i)->len;
	*ep++ = ATOM_EXT;
	put_int16(j, ep);  /* XXX reduce this to 8 bit in the future */
	ep += 2;
	sys_memcpy((char *) ep, (char*)atom_tab(i)->name, (int) j);
	ep += j;
	return ep;
    }

    ix = atom_val(atom) % MAXINDX;
    ce = &dep->cache->out_arr[ix];
    
    if (*ce == atom) {		/* The atom is present in the cache. */
	*ep++ = CACHED_ATOM;
	*ep++ = ix;
	return ep;
    }

    /*
     * Empty slot or another atom - overwrite.
     */

    *ce = atom;
    i = atom_val(atom);
    j = atom_tab(i)->len;
    *ep++ = NEW_CACHE;
    *ep++ = ix;
    put_int16(j, ep);
    ep += 2;
    sys_memcpy((char *) ep, (char*) atom_tab(i)->name, (int) j);
    return ep + j;
}

static byte*
enc_pid(DistEntry *dep, Eterm pid, byte* ep)
{
    Uint on, os;

    *ep++ = PID_EXT;
    /* insert  atom here containing host and sysname  */
    ep = enc_atom(dep, pid_node_name(pid), ep);

    /* two bytes for each number and serial */

    on = pid_number(pid);
    os = pid_serial(pid);

    put_int32(on, ep);
    ep += 4;
    put_int32(os, ep);
    ep += 4;
    *ep++ = pid_creation(pid);
    return ep;
}

static byte*
dec_hashed_atom(DistEntry *dep, byte *ep, Eterm* objp)
{
    if (!dep)
      *objp = am_Underscore; /* This is for the first distribution message */
    else
      *objp = dep->cache->in_arr[get_int8(ep)];
    return ep+1;
}


static byte* 
dec_and_insert_hashed_atom(DistEntry *dep, byte *ep, Eterm* objp)
{
    Uint ix;
    Uint len;

    ix = get_int8(ep);
    ep++;
    len = get_int16(ep);
    ep += 2;
    if (!dep) /* This is for the first distribution message */
	*objp = am_atom_put((char*)ep,len);
    else
	*objp = dep->cache->in_arr[ix] = 
	    am_atom_put((char*)ep,len);
    return ep + len;
}

/* Expect an atom (cached or new) */
static byte*
dec_atom(DistEntry *dep, byte* ep, Eterm* objp)
{
    Uint len;

    switch (*ep++) {
    case ATOM_EXT:
	len = get_int16(ep),
	ep += 2;
	*objp = am_atom_put((char*)ep, len);
	return ep + len;

    case NEW_CACHE:
	if (dep != NULL && !(dep->flags & DFLAG_ATOM_CACHE)) {
	    return NULL;
	}
	return dec_and_insert_hashed_atom(dep,ep,objp); 

    case CACHED_ATOM:
	if (dep != NULL && !(dep->flags & DFLAG_ATOM_CACHE)) {
	    return NULL;
	}
	return dec_hashed_atom(dep,ep,objp);

    default:
	return NULL;
    }
}

static byte*
dec_pid(DistEntry *dep, Eterm** hpp, byte* ep, ErlOffHeap* off_heap, Eterm* objp)
{
    Eterm sysname;
    Uint data;
    Uint num;
    Uint ser;
    Uint cre;
    ErlNode *node;

    /* eat first atom */
    if ((ep = dec_atom(dep, ep, &sysname)) == NULL)
	return NULL;
    num = get_int32(ep);
    ep += 4;
    ser = get_int32(ep);
    ep += 4;
    if ((cre = get_int8(ep)) >= MAX_CREATION)
	return NULL;
    ep += 1;

    cre = dec_set_creation(sysname,cre);
    node = erts_find_or_insert_node(sysname,cre);

    if (num > ERTS_MAX_PID_NUMBER)
	return NULL;
    if (ser > ERTS_MAX_PID_SERIAL)
	return NULL;
    data = make_pid_data(ser, num);
    if(node == erts_this_node) {
	*objp = make_internal_pid(data);
    }
    else {
	ExternalThing *etp = (ExternalThing *) *hpp;
	*hpp += EXTERNAL_THING_HEAD_SIZE + 1;

	etp->header = make_external_pid_header(1);
	etp->next = off_heap->externals;
	etp->node = node;
	etp->data[0] = data;

	node->refc++;
	off_heap->externals = etp;
	*objp = make_external_pid(etp);
    }
    return ep;
}


/* This function is written in this strange way because in dist.c
   we call it twice for some messages, First we insert a control message 
   in the buffer , and then we insert the actual message in the buffer
   immediataly following the control message. If the real (2) message
   makes the buffer owerflow, we must not destroy the work we have already
   done, i.e we must not forget to copy the encoding of the 
   control message as well, (If there is one)
   
   The buffer dist_buf initially points to tmp_buf, So if we write
   an application where the encoding of all distributed messages are <
   TMP_BUF_SIZE, all remote messages will be encoded into tmp_buf,
   and no additional buffer allocation is necessary.
   However, once a message does not fit into tmp_buf we 
   allocate a larger buffer and set dist_buf to point to that buffer.
   We never go back to tmp_buf situation again.

   We don't have the energy to describe the external format in words here.
   The code explains itself :-). However, All external encodings
   are predeeded with the special character VERSION_MAGIC, which makes
   it possible do distinguish encodings from incompatible erlang systems.
   Every time the external format is changed, This VERSION_MAGIC shall be 
   incremented.

*/



static byte*
enc_term(DistEntry *dep, Eterm obj, byte* ep, Uint32 dflags)
{
    int val;
    Uint n;
    Uint i;
    Uint j;
    Uint* ptr;
    FloatDef f;
    byte* back;

    switch(tag_val_def(obj)) {
    case NIL_DEF:
	*ep++ = NIL_EXT;   /* soley empty lists */
	return ep;

    case ATOM_DEF:
	return enc_atom(dep,obj,ep);

    case SMALL_DEF:
	if (is_byte(obj)) {
	    val = unsigned_val(obj);
	    *ep++ = SMALL_INTEGER_EXT;
	    put_int8(val, ep);
	    return ep + 1;
	}
	else {
	    val = signed_val(obj);
	    *ep++ = INTEGER_EXT;
	    put_int32(val, ep);
	    return ep + 4;
	}

    case BIG_DEF:
	if ((n = big_bytes(obj)) < 256) {
	    *ep++ = SMALL_BIG_EXT;
	    put_int8(n, ep);
	    ep += 1;
	}
	else {
	    *ep++ = LARGE_BIG_EXT;
	    put_int32(n, ep);
	    ep += 4;
	}
	*ep++ = big_sign(obj);
	return big_to_bytes(obj, ep);

    case PID_DEF:
    case EXTERNAL_PID_DEF:
	return enc_pid(dep, obj, ep);

    case REF_DEF:
    case EXTERNAL_REF_DEF: {
	Uint32 *ref_num;

	ASSERT(dflags & DFLAG_EXTENDED_REFERENCES);
	*ep++ = NEW_REFERENCE_EXT;
	i = ref_no_of_numbers(obj);
	put_int16(i, ep);
	ep += 2;
	ep = enc_atom(dep,ref_node_name(obj),ep);
	*ep++ = ref_creation(obj);
	ref_num = ref_numbers(obj);
	for (j = 0; j < i; j++) {
	    put_int32(ref_num[j], ep);
	    ep += 4;
	}
	return ep;
    }
    case PORT_DEF:
    case EXTERNAL_PORT_DEF:

	*ep++ = PORT_EXT;
	ep = enc_atom(dep,port_node_name(obj),ep);
	j = port_number(obj);
	put_int32(j, ep);
	ep += 4;
	*ep++ = port_creation(obj);
	return ep;

    case LIST_DEF:
	if ((i = is_string(obj)) && (i < MAX_STRING_LEN)) {
	    *ep++ = STRING_EXT;
	    put_int16(i, ep);
	    ep += 2;
	    while (is_list(obj)) {
		Eterm* cons = list_val(obj);
		*ep++ = unsigned_val(CAR(cons));
		obj = CDR(cons);
	    }
	    return ep;
	}
	*ep++ = LIST_EXT;
	back = ep;  /* leave length space */
	ep += 4;
	i = 0;
	while (is_list(obj)) {
	    Eterm* cons = list_val(obj);
	    i++;  /* count number of cons cells */
	    if ((ep = enc_term(dep, CAR(cons), ep, dflags)) == NULL)
		return NULL;
	    obj = CDR(cons);
	}
	if ((ep = enc_term(dep, obj, ep, dflags)) == NULL)
	    return NULL;
	put_int32(i, back);
	return ep;

    case TUPLE_DEF:
	ptr = tuple_val(obj);
	i = arityval(*ptr);
	ptr++;
	if (i <= 0xff) {
	    *ep++ = SMALL_TUPLE_EXT;
	    put_int8(i, ep);
	    ep += 1;
	}
	else  {
	    *ep++ = LARGE_TUPLE_EXT;
	    put_int32(i, ep);
	    ep += 4;
	}
	while(i--) {
	    if ((ep = enc_term(dep, *ptr++, ep, dflags)) == NULL)
		return NULL;
	}
	return ep;

    case VECTOR_DEF:
	n = VECTOR_SIZE(obj);
	if (n <= 0xff) {
	    *ep++ = SMALL_TUPLE_EXT;
	    put_int8(n, ep);
	    ep += 1;
	} else  {
	    *ep++ = LARGE_TUPLE_EXT;
	    put_int32(n, ep);
	    ep += 4;
	}
	for (i = 1; i <= n; i++) {
	    Eterm tmp = erts_unchecked_vector_get(i, obj);
	    if ((ep = enc_term(dep, tmp, ep, dflags)) == NULL) {
		return NULL;
	    }
	}
	return ep;

    case FLOAT_DEF:
	*ep++ = FLOAT_EXT;
	GET_DOUBLE(obj, f);

	/* now the sprintf which does the work */
	i = sys_double_to_chars(f.fd, (char*) ep);

	/* Don't leave garbage after the float!  (Bad practice in general,
	 * and Purify complains.)
	 */
	sys_memset(ep+i, 0, 31-i);

	return ep + 31;

    case BINARY_DEF:
	{
	    byte* bytes;
	    GET_BINARY_BYTES(obj, bytes);
	    *ep++ = BINARY_EXT;
	    j = binary_size(obj);
	    put_int32(j, ep);
	    ep += 4;
	    sys_memcpy(ep, bytes, j);
	    return ep + j;
	}
    case FUN_DEF:
	if ((dflags & DFLAG_NEW_FUN_TAGS) != 0) {
	    ErlFunThing* funp = (ErlFunThing *) fun_val(obj);
	    Uint num_free = funp->num_free;
	    byte* size_p;

	    *ep++ = NEW_FUN_EXT;
	    size_p = ep;
	    ep += 4;
	    *ep = funp->arity;
	    ep += 1;
	    sys_memcpy(ep, funp->fe->uniq, 16);
	    ep += 16;
	    put_int32(funp->fe->index, ep);
	    ep += 4;
	    put_int32(num_free, ep);
	    ep += 4;
	    ep = enc_atom(dep, funp->fe->module, ep);
	    ep = enc_term(dep, make_small(funp->fe->old_index), ep, dflags);
	    ep = enc_term(dep, make_small(funp->fe->old_uniq), ep, dflags);
	    ep = enc_pid(dep, funp->creator, ep);
	    ptr = funp->env;
	    while (num_free-- > 0) {
		if ((ep = enc_term(dep, *ptr++, ep, dflags)) == NULL) {
		    return NULL;
		}
	    }
	    put_int32(ep-size_p, size_p);
	} else if ((dflags & DFLAG_FUN_TAGS) != 0) {
	    ErlFunThing* funp = (ErlFunThing *) fun_val(obj);
	    Uint num_free = funp->num_free;

	    *ep++ = FUN_EXT;
	    put_int32(num_free, ep);
	    ep += 4;
	    ep = enc_pid(dep, funp->creator, ep);
	    ep = enc_atom(dep, funp->fe->module, ep);
	    ep = enc_term(dep, make_small(funp->fe->old_index), ep, dflags);
	    ep = enc_term(dep, make_small(funp->fe->old_uniq), ep, dflags);
	    ptr = funp->env;
	    while (num_free-- > 0) {
		if ((ep = enc_term(dep, *ptr++, ep, dflags)) == NULL) {
		    return NULL;
		}
	    }
	} else {
	    /*
	     * Communicating with an obsolete erl_interface or jinterface node.
	     * Convert the fun to a tuple to avoid crasching.
	     */
		
	    ErlFunThing* funp = (ErlFunThing *) fun_val(obj);
		
	    /* Tag, arity */
	    *ep++ = SMALL_TUPLE_EXT;
	    put_int8(5, ep);
	    ep += 1;
		
	    /* 'fun' */
	    ep = enc_atom(dep, am_fun, ep);
		
	    /* Module name */
	    ep = enc_atom(dep, funp->fe->module, ep);
		
	    /* Index, Uniq */
	    *ep++ = INTEGER_EXT;
	    put_int32(funp->fe->old_index, ep);
	    ep += 4;
	    *ep++ = INTEGER_EXT;
	    put_int32(unsigned_val(funp->fe->old_uniq), ep);
	    ep += 4;
		
	    /* Environment sub-tuple arity */
	    if (funp->num_free <= 0xff) {
		*ep++ = SMALL_TUPLE_EXT;
		put_int8(funp->num_free, ep);
		ep += 1;
	    } else {
		*ep++ = LARGE_TUPLE_EXT;
		put_int32(funp->num_free, ep);
		ep += 4;
	    }
		
	    /* Environment tuple */
	    for (i = 0; i < funp->num_free; i++) {
		if ((ep = enc_term(dep, funp->env[i], ep, dflags)) == NULL) {
		    return NULL;
		}
	    }
	} 	    
	return ep;
    }
    return NULL;
}

int
erts_to_external_format(DistEntry *dep, Eterm obj, byte **ext)
{
    byte* ptr = *ext;
    byte* dist_end = dist_buf + dist_buf_size;
    unsigned dflags;

    if (dep) {
	dflags = dep->flags;
    } else {
	dflags = TERM_TO_BINARY_DFLAGS;
    }

    /* check if we are using dist_buf !! */
    if (dep && (ptr >= dist_buf) && (ptr < dist_end)) {
	int size = 50 + encode_size_struct(obj, dflags);

	/* check if distbuf must grow */
	if ((ptr + size) > dist_end) {
	    int len = ptr - dist_buf;
	    char* buf;
	    
	    size += (1000 + len);
	    buf = (byte*) safe_alloc_from(281, 20+size); /* REMOVE THIS SLOPPY !!! */
	    
	    /* We need to restore the old contetnts of dist_buf
	       before we can proceed */
	    sys_memcpy(buf,dist_buf,len);
	    if (dist_buf != tmp_buf)
		sys_free(dist_buf);
	    dist_buf_size = size;
	    dist_buf = buf;
	    ptr =  dist_buf + len;
	    *ext = ptr;
	}
    }
    *ptr++ = VERSION_MAGIC;
    if ((ptr = enc_term(dep, obj, ptr, dflags)) == NULL)
	erl_exit(1, "Internal data structure error (in to_external)\n");
    *ext = ptr;
    return 0;
}

/*
** hpp is set to either a &p->htop or
** a pointer to a memory pointer (form message buffers)
** on return hpp is updated to point after allocated data
*/
Eterm
erts_from_external_format(DistEntry *dep,
			  Eterm** hpp,
			  byte **ext,
			  ErlOffHeap* off_heap)
{
    Eterm obj;
    byte* ep = *ext;

    if (*ep++ != VERSION_MAGIC) {
	cerr_pos = 0;
	if (dep)
	    erl_printf(CBUF,
		       "** Got message from noncompatible erlang on channel %d\n",
		       dist_entry_channel_no(dep));
	else 
	    erl_printf(CBUF,
		       "** Attempt to convert old non compatible binary %d\n",
		       *ep);
	send_error_to_logger(NIL);
	return THE_NON_VALUE;
    }
    if ((ep = dec_term(dep, hpp, ep, off_heap, &obj)) == NULL) {
	if (dep) {	/* Don't print this for binary_to_term */
	    cerr_pos = 0;
	    erl_printf(CBUF,"Got corrupted message on channel %d\n",
		       dist_entry_channel_no(dep));
	    send_error_to_logger(NIL);
	}
#ifdef DEBUG
	bin_write(CERR,*ext,500);
#endif
	return THE_NON_VALUE;
    }
    *ext = ep;
    return obj;
}

static byte*
dec_term(DistEntry *dep, Eterm** hpp, byte* ep, ErlOffHeap* off_heap, Eterm* objp)
{
    int n;
    Eterm* hp = *hpp;
    Eterm* next = objp;

    *next = (Eterm) NULL;

    while (next != NULL) {
	objp = next;
	next = (Eterm *) (*objp);

	switch (*ep++) {
	case INTEGER_EXT:
	    {
		Sint sn = get_int32(ep);

		ep += 4;
		if (MY_IS_SSMALL(sn)) {
		    *objp = make_small(sn);
		} else {
		    *objp = uint_to_big(sn, hp);
		    hp += 2;
		}
		break;
	    }
	case SMALL_INTEGER_EXT:
	    n = get_int8(ep);
	    ep++;
	    *objp = make_small(n);
	    break;
	case SMALL_BIG_EXT:
	    n = get_int8(ep);
	    ep++;
	    goto big_loop;
	case LARGE_BIG_EXT:
	    n = get_int32(ep);
	    ep += 4;
	big_loop:
	    {
		Eterm big;

		Uint k = get_int8(ep);
		ep++;
		big = bytes_to_big(ep, n, k, hp);
		if (is_big(big)) {
		    hp += (big_arity(big)+1);
		}
		*objp = big;
		ep += n;
		break;
	    }
	case NEW_CACHE:
	    if (dep != NULL && !(dep->flags & DFLAG_ATOM_CACHE)) {
		return NULL;
	    }
	    ep = dec_and_insert_hashed_atom(dep, ep, objp);
	    break;
	case CACHED_ATOM:
	    if (dep != NULL && !(dep->flags & DFLAG_ATOM_CACHE)) {
		return NULL;
	    }
	    ep = dec_hashed_atom(dep, ep, objp);
	    break;
	case ATOM_EXT:
	    {
		Atom a;
		
		n = get_int16(ep);
		ep += 2;
		a.len = n;
		a.name = ep;
		ep += n;
		*objp = make_atom(index_put(&atom_table, (void*) &a));
		break;
	    }
	case LARGE_TUPLE_EXT:
	    n = get_int32(ep);
	    ep += 4;
	    goto tuple_loop;
	case SMALL_TUPLE_EXT:
	    n = get_int8(ep);
	    ep++;
	tuple_loop:
	    *objp = make_tuple(hp);
	    *hp++ = make_arityval(n);
	    hp += n;
	    objp = hp - 1;
	    while (n-- > 0) {
		objp[0] = (Eterm) next;
		next = objp;
		objp--;
	    }
	    break;
	case NIL_EXT:
	    *objp = NIL;
	    break;
	case LIST_EXT:
	    n = get_int32(ep);
	    ep += 4;
	    if (n == 0) {
		*objp = NIL;
		break;
	    }
	    *objp = make_list(hp);
	    hp += 2*n;
	    objp = hp - 2;
	    objp[0] = (Eterm) (objp+1);
	    objp[1] = (Eterm) next;
	    next = objp;
	    objp -= 2;
	    while (--n > 0) {
		objp[0] = (Eterm) next;
		objp[1] = make_list(objp + 2);
		next = objp;
		objp -= 2;
	    }
	    break;
	case STRING_EXT:
	    n = get_int16(ep);
	    ep += 2;
	    if (n == 0) {
		*objp = NIL;
		break;
	    }
	    *objp = make_list(hp);
	    while (n-- > 0) {
		hp[0] = make_small(*ep++);
		hp[1] = make_list(hp+2);
		hp += 2;
	    }
	    hp[-1] = NIL;
	    break;
	case FLOAT_EXT:
	    {
		FloatDef ff;

		if (sys_chars_to_double((char*)ep, &ff.fd) != 0) {
		    return NULL;
		}
		ep += 31;
		*objp = make_float(hp);
		PUT_DOUBLE(ff, hp);
		hp += 3;
		break;
	    }
	case PID_EXT:
	    ep = dec_pid(dep, &hp, ep, off_heap, objp);
	    break;
	case PORT_EXT:
	    {
		Eterm sysname;
		ErlNode *node;
		Uint num;
		Uint cre;

		if ((ep = dec_atom(dep, ep, &sysname)) == NULL)
		  return NULL;
		if ((num = get_int32(ep)) > ERTS_MAX_PORT_NUMBER)
		  return NULL;
		ep += 4;
		if ((cre = get_int8(ep)) >= MAX_CREATION)
		  return NULL;
		ep++;
		cre = dec_set_creation(sysname,cre);
		node = erts_find_or_insert_node(sysname, cre);

		if(node == erts_this_node) {
		  *objp = make_internal_port(num);
		}
		else {
		    ExternalThing *etp = (ExternalThing *) hp;
		    hp += EXTERNAL_THING_HEAD_SIZE + 1;
		    
		    etp->header = make_external_port_header(1);
		    etp->next = off_heap->externals;
		    etp->node = node;
		    etp->data[0] = num;

		    node->refc++;
		    off_heap->externals = etp;
		    *objp = make_external_port(etp);
		}

		break;
	    }
	case REFERENCE_EXT:
	    {
		Eterm sysname;
		ErlNode *node;
		int i;
		Uint cre;
		Uint32 *ref_num;
		Uint32 r0;
		Uint ref_words;

		ref_words = 1;

		if ((ep = dec_atom(dep,ep, &sysname)) == NULL)
		    return NULL;
		if ((r0 = get_int32(ep)) >= MAX_REFERENCE )
		    return NULL;
		ep += 4;

		if ((cre = get_int8(ep)) >= MAX_CREATION)
		    return NULL;
		ep += 1;
		goto ref_ext_common;

	    case NEW_REFERENCE_EXT:

		ref_words = get_int16(ep);
		ep += 2;

		if (ref_words > ERTS_MAX_REF_NUMBERS)
		    return NULL;

		if ((ep = dec_atom(dep, ep, &sysname)) == NULL)
		    return NULL;

		if ((cre = get_int8(ep)) >= MAX_CREATION)
		    return NULL;
		ep += 1;

		r0 = get_int32(ep);
		ep += 4;
		if(r0 > MAX_REFERENCE)
		    return NULL;

	    ref_ext_common:

		cre = dec_set_creation(sysname, cre);
		node = erts_find_or_insert_node(sysname, cre);
		if(node == erts_this_node) {
		    RefThing *rtp = (RefThing *) hp;
		    hp += REF_THING_HEAD_SIZE;
#ifdef ARCH_64
		    rtp->header = make_ref_thing_header(ref_words/2 + 1);
#else
		    rtp->header = make_ref_thing_header(ref_words);
#endif
		    *objp = make_internal_ref(rtp);
		}
		else {
		    ExternalThing *etp = (ExternalThing *) hp;
		    hp += EXTERNAL_THING_HEAD_SIZE;
		    
#ifdef ARCH_64
		    etp->header = make_external_ref_header(ref_words/2 + 1);
#else
		    etp->header = make_external_ref_header(ref_words);
#endif
		    etp->next = off_heap->externals;
		    etp->node = node;

		    node->refc++;
		    off_heap->externals = etp;
		    *objp = make_external_ref(etp);
		}

		ref_num = (Uint32 *) hp;
#ifdef ARCH_64
		*(ref_num++) = ref_words /* 32-bit arity */;
#endif
		ref_num[0] = r0;
		for(i = 1; i < ref_words; i++) {
		    ref_num[i] = get_int32(ep);
		    ep += 4;
		}
#ifdef ARCH_64
		if ((1 + ref_words) % 2)
		    ref_num[ref_words] = 0;
		hp += ref_words/2 + 1;
#else
		hp += ref_words;
#endif
		break;
	    }
	case BINARY_EXT:
	    {
		n = get_int32(ep);
		ep += 4;
	    
		if (n <= ERL_ONHEAP_BIN_LIMIT) {
		    ErlHeapBin* hb = (ErlHeapBin *) hp;

		    hb->thing_word = header_heap_bin(n);
		    hb->size = n;
		    hp += heap_bin_size(n);
		    sys_memcpy(hb->data, ep, n);
		    *objp = make_binary(hb);
		} else {
		    Binary* dbin = OH_BIN_SAFE_ALLOC(60, n+sizeof(Binary));
		    ProcBin* pb;
		    dbin->flags = 0;
		    dbin->orig_size = n;
		    dbin->refc = 1;
		    sys_memcpy(dbin->orig_bytes, ep, n);
		    tot_bin_allocated += n;
		    pb = (ProcBin *) hp;
		    hp += PROC_BIN_SIZE;
		    pb->thing_word = HEADER_PROC_BIN;
		    pb->size = n;
		    pb->next = off_heap->mso;
		    off_heap->mso = pb;
		    pb->val = dbin;
		    pb->bytes = dbin->orig_bytes;
		    *objp = make_binary(pb);
		}
		ep += n;
		break;
	    }
	case NEW_FUN_EXT:
	    {
		ErlFunThing* funp = (ErlFunThing *) hp;
		Uint arity;
		Eterm module;
		int old_uniq;
		int old_index;
		unsigned num_free;
		int i;
		Eterm* temp_hp;
		Eterm** hpp = &temp_hp;
		Eterm temp;


		ep += 4;	/* Skip total size in bytes */
		arity = *ep++;
		ep += 20;
		num_free = get_int32(ep);
		ep += 4;
		hp += ERL_FUN_SIZE + num_free;
		*hpp = hp;
		funp->thing_word = HEADER_FUN;
#ifndef SHARED_HEAP
		funp->next = off_heap->funs;
		off_heap->funs = funp;
#endif
		funp->num_free = num_free;
		*objp = make_fun(funp);

		/* Module */
		if ((ep = dec_atom(dep, ep, &temp)) == NULL) {
		    return NULL;
		}
		module = temp;

		/* Index */
		if ((ep = dec_term(dep, hpp, ep, off_heap, &temp)) == NULL) {
		    return NULL;
		}
		if (!is_small(temp)) {
		    return NULL;
		}
		old_index = unsigned_val(temp);

		/* Uniq */
		if ((ep = dec_term(dep, hpp, ep, off_heap, &temp)) == NULL) {
		    return NULL;
		}
		if (!is_small(temp)) {
		    return NULL;
		}
		old_uniq = unsigned_val(temp);

		funp->fe = erts_put_fun_entry(module, old_uniq, old_index);
		funp->fe->arity = arity;
		funp->arity = arity;
#ifdef HIPE
		if (funp->fe->native_address == NULL) {
		    hipe_set_closure_stub(funp->fe, num_free);
		}
		funp->native_address = funp->fe->native_address;
#endif
		hp = *hpp;

		/* Environment */
		for (i = num_free-1; i >= 0; i--) {
		    funp->env[i] = (Eterm) next;
		    next = funp->env + i;
		}
		/* Creator */
		funp->creator = (Eterm) next;
		next = &(funp->creator);
		break;
	    }
	case FUN_EXT:
	    {
		ErlFunThing* funp = (ErlFunThing *) hp;
		Eterm module;
		int old_uniq;
		int old_index;
		unsigned num_free;
		int i;
		Eterm* temp_hp;
		Eterm** hpp = &temp_hp;
		Eterm temp;

		num_free = get_int32(ep);
		ep += 4;
		hp += ERL_FUN_SIZE + num_free;
		*hpp = hp;
		funp->thing_word = HEADER_FUN;
#ifndef SHARED_HEAP
		funp->next = off_heap->funs;
		off_heap->funs = funp;
#endif
		funp->num_free = num_free;
		*objp = make_fun(funp);

		/* Creator pid */
		switch(*ep) {
		case PID_EXT:
		    ep = dec_pid(dep, hpp, ++ep, off_heap, &funp->creator);
		    break;
		default:
		    return NULL;
		}
		if(!ep)
		    return NULL;

		/* Module */
		if ((ep = dec_atom(dep, ep, &temp)) == NULL) {
		    return NULL;
		}
		module = temp;

		/* Index */
		if ((ep = dec_term(dep, hpp, ep, off_heap, &temp)) == NULL) {
		    return NULL;
		}
		if (!is_small(temp)) {
		    return NULL;
		}
		old_index = unsigned_val(temp);

		/* Uniq */
		if ((ep = dec_term(dep, hpp, ep, off_heap, &temp)) == NULL) {
		    return NULL;
		}
		if (!is_small(temp)) {
		    return NULL;
		}
		old_uniq = unsigned_val(temp);

		funp->fe = erts_put_fun_entry(module, old_uniq, old_index);
		funp->arity = funp->fe->address[-1] - num_free;
#ifdef HIPE
		funp->native_address = funp->fe->native_address;
#endif
		hp = *hpp;

		/* Environment */
		for (i = num_free-1; i >= 0; i--) {
		    funp->env[i] = (Eterm) next;
		    next = funp->env + i;
		}
		break;
	    }
	default:
	    return NULL;
	}
    }
    *hpp = hp;
    return ep;
}

/* returns the number of bytes needed to encode an object
   to a sequence of bytes
   N.B. That this must agree with to_external2() above!!!
   (except for cached atoms) */

Uint
encode_size_struct(Eterm obj, unsigned dflags)
{
    return (1 + encode_size_struct2(obj, dflags));
				/* 1 for the VERSION_MAGIC */
}

static Uint
encode_size_struct2(Eterm obj, unsigned dflags)
{
    Uint m,i, arity, *nobj, sum;

    switch (tag_val_def(obj)) {
    case NIL_DEF:
	return 1;
    case ATOM_DEF:
	/* Make sure NEW_CACHE ix l1 l0 a1 a2 .. an fits */
	return (1 + 1 + 2 + atom_tab(atom_val(obj))->len);
    case SMALL_DEF:
	if (unsigned_val(obj) < 256 ) 
	    return(1 + 1);
	else 
	    return(1 + 4);
    case BIG_DEF:
	if ((i = big_bytes(obj)) < 256)
	    return 1 + 1 + 1 + i;  /* tag,size,sign,digits */
	else
	    return 1 + 4 + 1 + i;  /* tag,size,sign,digits */
    case PID_DEF:
    case EXTERNAL_PID_DEF:
	return (1 + encode_size_struct2(pid_node_name(obj), dflags)
		+ 4 + 4 + 1);
    case REF_DEF:
    case EXTERNAL_REF_DEF:
	ASSERT(dflags & DFLAG_EXTENDED_REFERENCES);
	i = ref_no_of_numbers(obj);
	return (1 + 2 + encode_size_struct2(ref_node_name(obj), dflags)
		+ 1 + 4*i);
    case PORT_DEF:
    case EXTERNAL_PORT_DEF:
	return (1 + encode_size_struct2(port_node_name(obj), dflags)
		+ 4 + 1);
    case LIST_DEF:
	if ((m = is_string(obj)) && (m < MAX_STRING_LEN))
	    return m + 2 + 1;
	nobj = list_val(obj);
	sum = 5;
	while (1) {
	    sum += encode_size_struct2(*nobj++, dflags);
	    if (is_not_list(*nobj)) {
		if (is_nil(*nobj))
		    return sum + 1;
		return(sum + encode_size_struct2(*nobj, dflags));
	    }
	    nobj = list_val(*nobj);
	}
    case TUPLE_DEF:
	arity = arityval(*(tuple_val(obj)));
	if (arity <= 0xff) 
	    sum = 1 + 1;
	else
	    sum = 1 + 4;
	for (i = 0; i < arity; i++)
	    sum += encode_size_struct2(*(tuple_val(obj) + i + 1), dflags);
	return sum;
    case VECTOR_DEF:
	arity = VECTOR_SIZE(obj);
	if (arity <= 0xff) 
	    sum = 1 + 1;
	else
	    sum = 1 + 4;
	for (i = 1; i <= arity; i++) {
	    Eterm tmp = erts_unchecked_vector_get(i, obj);
	    sum += encode_size_struct2(tmp, dflags);
	}
	return sum;
    case FLOAT_DEF:
	return 32;   /* Yes, including the tag */
    case BINARY_DEF:
	return 1 + 4 + binary_size(obj);
    case FUN_DEF:
	if ((dflags & DFLAG_NEW_FUN_TAGS) != 0) {
	    sum = 20+1+1+4;	/* New ID + Tag */
	    goto fun_size;
	} else if ((dflags & DFLAG_FUN_TAGS) != 0) {
	    sum = 1;		/* Tag */
	    goto fun_size;
	} else {
	    /*
	     * Size when fun is mapped to a tuple (to avoid crasching).
	     */

	    ErlFunThing* funp = (ErlFunThing *) fun_val(obj);

	    sum = 1 + 1;	/* Tuple tag, arity */
	    sum += 1 + 1 + 2 + atom_tab(atom_val(am_fun))->len; /* 'fun' */
	    sum += 1 + 1 + 2 +
		atom_tab(atom_val(funp->fe->module))->len; /* Module name */
	    sum += 2 * (1 + 4); /* Index + Uniq */

	    /*
	     * The free variables are a encoded as a sub tuple.
	     */
	    sum += 1 + (funp->num_free < 0x100 ? 1 : 4);
	    for (i = 0; i < funp->num_free; i++) {
		sum += encode_size_struct2(funp->env[i], dflags);
	    }
	    return sum;
	}
    
    fun_size:
	{
	    ErlFunThing* funp = (ErlFunThing *) fun_val(obj);
	    sum += 4;		/* Length field (number of free variables */
	    sum += encode_size_struct2(funp->creator, dflags);
	    sum += encode_size_struct2(funp->fe->module, dflags);
	    sum += 2 * (1+4);	/* Index, Uniq */
	    for (i = 0; i < funp->num_free; i++) {
		sum += encode_size_struct2(funp->env[i], dflags);
	    }
	    return sum;
	} 
    default:
	erl_exit(1,"Internal data structure error (in encode_size_struct2)%x\n",
		 obj);
    }
    return -1; /* Pedantic (lint does not know about erl_exit) */
}

static int
decode_size2(byte *ep, byte* endp)
{
    int heap_size = 0;
    int terms = 1;
    int atom_extra_skip = 0;
    Uint n;
    DECLARE_ESTACK(s);

#define SKIP(sz)				\
    do {					\
	if ((sz) <= endp-ep) {			\
	    ep += (sz);				\
        } else {return -1; };			\
    } while (0)

#define CHKSIZE(sz)				\
    do {					\
	 if ((sz) > endp-ep) { return -1; }	\
    } while (0)

    for (;;) {
	while (terms-- > 0) {
	    int tag;

	    CHKSIZE(1);
	    tag = ep++[0];
	    switch (tag) {
	    case INTEGER_EXT:
		SKIP(4);
		heap_size += 2;
		break;
	    case SMALL_INTEGER_EXT:
		SKIP(1);
		break;
	    case SMALL_BIG_EXT:
		CHKSIZE(1);
		n = ep[0];		/* number of bytes */
		SKIP(1+1+n);		/* skip size,sign,digits */
		heap_size += 1+1+(n+3)/4;
		break;
	    case LARGE_BIG_EXT:
		CHKSIZE(4);
		n = (ep[0] << 24) | (ep[1] << 16) | (ep[2] << 8) | ep[3];
		SKIP(4+1+n);		/* skip, size,sign,digits */
		heap_size += 1+1+(n+3)/4;
		break;
	    case ATOM_EXT:
		CHKSIZE(2);
		n = (ep[0] << 8) | ep[1];
		SKIP(n+2+atom_extra_skip);
		atom_extra_skip = 0;
		break;
	    case NEW_CACHE:
		CHKSIZE(3);
		n = get_int16(ep+1);
		SKIP(n+3+atom_extra_skip);
		atom_extra_skip = 0;
		break;
	    case CACHED_ATOM:
		SKIP(1+atom_extra_skip);
		atom_extra_skip = 0;
		break;
	    case PID_EXT:
		atom_extra_skip = 9;
		 /* In case it is an external pid */
		heap_size += EXTERNAL_THING_HEAD_SIZE + 1;
		terms++;
		break;
	    case PORT_EXT:
		atom_extra_skip = 5;
		 /* In case it is an external port */
		heap_size += EXTERNAL_THING_HEAD_SIZE + 1;
		terms++;
		break;
	    case NEW_REFERENCE_EXT:
		{
		    int id_words;

		    CHKSIZE(2);
		    id_words = get_int16(ep);
		    
		    if (id_words > ERTS_MAX_REF_NUMBERS)
			return -1;

		    ep += 2;
		    atom_extra_skip = 1 + 4*id_words;
		    /* In case it is an external ref */
#ifdef ARCH_64
		    heap_size += EXTERNAL_THING_HEAD_SIZE + id_words/2 + 1;
#else
		    heap_size += EXTERNAL_THING_HEAD_SIZE + id_words;
#endif
		    terms++;
		    break;
		}
	    case REFERENCE_EXT:
		/* In case it is an external ref */
		heap_size += EXTERNAL_THING_HEAD_SIZE + 1;
		atom_extra_skip = 5;
		terms++;
		break;
	    case NIL_EXT:
		break;
	    case LIST_EXT:
		CHKSIZE(4);
		ESTACK_PUSH(s, terms);
		terms = (ep[0] << 24) | (ep[1] << 16) | (ep[2] << 8) | ep[3];
		terms++;
		ep += 4;
		heap_size += 2 * terms;
		break;
	    case SMALL_TUPLE_EXT:
		CHKSIZE(1);
		ESTACK_PUSH(s, terms);
		terms = *ep++;
		heap_size += terms + 1;
		break;
	    case LARGE_TUPLE_EXT:
		CHKSIZE(4);
		ESTACK_PUSH(s, terms);
		terms = (ep[0] << 24) | (ep[1] << 16) | (ep[2] << 8) | ep[3];
		ep += 4;
		heap_size += terms + 1;
		break;
	    case STRING_EXT:
		CHKSIZE(2);
		n = (ep[0] << 8) | ep[1];
		SKIP(n+2);
		heap_size += 2 * n;
		break;
	    case FLOAT_EXT:
		SKIP(31);
		heap_size += 3;
		break;
	    case BINARY_EXT:
		CHKSIZE(4);
		n = (ep[0] << 24) | (ep[1] << 16) | (ep[2] << 8) | ep[3];
		SKIP(4+n);
		if (n <= ERL_ONHEAP_BIN_LIMIT) {
		    heap_size += 1+heap_bin_size(n);
		} else {
		    heap_size += 1+PROC_BIN_SIZE;
		}
		break;
	    case NEW_FUN_EXT:
		{
		    int num_free;
		    Uint total_size;

		    total_size = get_int32(ep);
		    CHKSIZE(total_size);
		    CHKSIZE(20+1+4);
		    ep += 20+1+4;
		    /*FALLTHROUGH*/

		case FUN_EXT:
		    CHKSIZE(4);
		    num_free = get_int32(ep);
		    ep += 4;
		    ESTACK_PUSH(s, terms);
		    terms = 4 + num_free;
		    heap_size += ERL_FUN_SIZE + num_free;
		    break;
		}
	    default:
		return -1;
	    }
	}
	if (ESTACK_ISEMPTY(s)) {
	    DESTROY_ESTACK(s);
	    return heap_size;
	}
	terms = ESTACK_POP(s);
    }
#undef SKIP
#undef CHKSIZE
}

int
decode_size(byte* t, int size)
{
    if (size > 0 && *t == VERSION_MAGIC)
	t++;
    else
	return -1;
    size--;
    return decode_size2(t, t+size);
}
