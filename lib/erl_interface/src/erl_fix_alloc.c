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
/*
 * Function: General purpose Memory allocator for fixed block 
 *    size objects. This allocater is at least an order of 
 *    magnitude faster than malloc().
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "erl_error.h"
#include "erl_malloc.h"
#include "erl_fix_alloc.h"
#include "erl_locking.h"
#include "erl_eterm.h"

#define WIPE_CHAR ((char)0xaa) /* 10101010 */

#ifdef SUNOS4
extern int memset();
#endif

/* the freelist is a singly linked list of these */
/* i.e. the user structure and a link pointer */
struct fix_block {
  ETERM term;
  struct fix_block *next;
  int free;
};

/* this is a struct just to keep namespace pollution low on VxWorks */
struct eterm_stateinfo {
  struct fix_block *freelist;
  unsigned long freed;
  unsigned long allocated;
  erl_mutex_t *lock;
};
static struct eterm_stateinfo *erl_eterm_state=NULL;


int 
erl_init_eterm_alloc (void)
{
#if defined(PURIFY) && defined (DEBUG)
    fprintf(stderr,"erl_fix_alloc() compiled for Purify - using \"real\" malloc()");
#endif
  
    erl_eterm_state = malloc(sizeof(*erl_eterm_state));
    if (erl_eterm_state == NULL) goto err1;

    erl_eterm_state->freelist = NULL;
    erl_eterm_state->freed = 0;
    erl_eterm_state->allocated = 0;
    erl_eterm_state->lock = erl_mutex_create();    
    if (erl_eterm_state->lock == NULL) goto err2;

    return 1;

    /* Error cleanup */
 err2:
    free(erl_eterm_state);
 err1:
    erl_errno = ENOMEM;
    return 0;
}

/* get an eterm, from the freelist if possible or from malloc() */
void *
erl_eterm_alloc (void)
{
#ifdef PURIFY
    ETERM *p;
  
    if ((p = malloc(sizeof(*p)))) {
	memset(p, WIPE_CHAR, sizeof(*p));
    }
    return p;
#else
    struct fix_block *b;

    erl_mutex_lock(erl_eterm_state->lock, 0);

    /* try to pop block from head of freelist */
    if ((b = erl_eterm_state->freelist) != NULL) {
	erl_eterm_state->freelist = b->next;
	erl_eterm_state->freed--;      
    } else if ((b = malloc(sizeof(*b))) == NULL) {
	erl_errno = ENOMEM;
    }
    erl_eterm_state->allocated++;
    b->free = 0;
    b->next = NULL;
    erl_mutex_unlock(erl_eterm_state->lock);
    return (void *) &b->term;
#endif
}

/* free an eterm back to the freelist */
void 
erl_eterm_free(void *p)
{
#ifdef PURIFY
  if (p) {
      memset(p, WIPE_CHAR, sizeof(ETERM));
  }
  free(p);
#else
  struct fix_block *b = p;
  
  if (b) {
      if (b->free) {
#ifdef DEBUG
	  fprintf(stderr,"erl_eterm_free: attempt to free already freed block %p\n",b);
#endif
	  return;
      }

      erl_mutex_lock(erl_eterm_state->lock,0);
      b->free = 1;
      b->next = erl_eterm_state->freelist;
      erl_eterm_state->freelist = b;
      erl_eterm_state->freed++;
      erl_eterm_state->allocated--;
      erl_mutex_unlock(erl_eterm_state->lock);
  }
#endif
}

/* really free the freelist */
void 
erl_eterm_release (void)
{
#if !defined(PURIFY)
    struct fix_block *b;

    erl_mutex_lock(erl_eterm_state->lock,0);
    {
	while (erl_eterm_state->freelist != NULL) {
	    b = erl_eterm_state->freelist;
	    erl_eterm_state->freelist = b->next;
	    free(b);
	    erl_eterm_state->freed--;
	}
    }
    erl_mutex_unlock(erl_eterm_state->lock);
#endif
}

void 
erl_eterm_statistics (unsigned long *allocd, unsigned long *freed)
{
  if (allocd) *allocd = erl_eterm_state->allocated;
  if (freed) *freed = erl_eterm_state->freed;

  return;
}


/*
 * Local Variables:
 * compile-command: "cd ..; ERL_TOP=/clearcase/otp/erts make -k"
 * End:
 */
