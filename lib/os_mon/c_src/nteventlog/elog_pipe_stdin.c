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
#include "elog_global.h"
#include "elog_pipe_stdin.h"

/*
 * Data for the handling of a pipe stdin,
 * data is read in a separate thread, so locking and 
 * event signaling needs to be done.
 */

static CRITICAL_SECTION io_crit;
static char *stdin_buff = NULL;
static int stdin_siz = 0;
static int stdin_len = 0;
static int stdin_eof = 0;
/* end syncronized objects */
static int stdin_is_console = 0;
static HANDLE stdin_event;

DWORD WINAPI stdin_thread(LPVOID ptr){
  HANDLE in = GetStdHandle(STD_INPUT_HANDLE);
  char buff[1];
  DWORD red;
  for(;;){
    if(!ReadFile(in, buff, (DWORD) 1, &red, NULL)){
      if(GetLastError() == ERROR_BROKEN_PIPE){
	EnterCriticalSection(&io_crit);
	stdin_eof = 1;
	SetEvent(stdin_event);
	LeaveCriticalSection(&io_crit);
	return 0;
      }
      return 1;
    }else if(red == 0){
	EnterCriticalSection(&io_crit);
	stdin_eof = 1;
	SetEvent(stdin_event);
	LeaveCriticalSection(&io_crit);
	return 0;
    }
#ifdef HARDDEBUG
    fprintf(stderr,"stdin_thread go data (%d)\n",(int)*buff);
#endif
    EnterCriticalSection(&io_crit);
    if(stdin_len + 1 >= stdin_siz){
      if(!stdin_siz)
	stdin_buff = malloc(stdin_siz = 100);
      else
	stdin_buff = realloc(stdin_buff, stdin_siz +=100);
    }
    stdin_buff[stdin_len++] = *buff;
    SetEvent(stdin_event);
    LeaveCriticalSection(&io_crit);
  }
  return 0;
}

BOOL peek_pipe_stdin_eof(void){
  BOOL ret;
  EnterCriticalSection(&io_crit);
  if((ret = !!stdin_eof))
    ResetEvent(stdin_event); /* Now we "unsignal" */
  LeaveCriticalSection(&io_crit);
  return ret;
}

int read_pipe_stdin(char *buff, int max){
  int ret;
  EnterCriticalSection(&io_crit);
  if(stdin_len == 0){
    if(!stdin_eof){
      LeaveCriticalSection(&io_crit);
      WaitForSingleObject(stdin_event,INFINITE);
      EnterCriticalSection(&io_crit);
      if(!stdin_len){
	if(stdin_eof){
	  /* Stay signaled */
	  LeaveCriticalSection(&io_crit);
	  return 0;
	} else {
	  ResetEvent(stdin_event);
	  LeaveCriticalSection(&io_crit);
	  return -1;
	}
      }
    } else {
      /* Stay signaled */
      LeaveCriticalSection(&io_crit);
      return 0;
    }
  }
#ifdef HARDDEBUG
  fprintf(stderr,"read_pipe_stdin got data.\n"
	  "max = %d, stdin_len = %d, *stdin_buff = %d\n",
	  max,stdin_len,*stdin_buff);
#endif
  /* stdin_len should be something now */
  if(stdin_len > max){
    memcpy(buff,stdin_buff,max);
    memmove(stdin_buff,stdin_buff + max,stdin_len - max);
    stdin_len -= max;
    ret = max;
  } else {
    memcpy(buff,stdin_buff,stdin_len);
    ret = stdin_len;
    stdin_len = 0;
  }
  if(!stdin_eof) /* Stay signaled if EOF */
    ResetEvent(stdin_event);
  LeaveCriticalSection(&io_crit);
  return ret;
}

BOOL setup_pipe_stdin(void){
  HANDLE in = GetStdHandle(STD_INPUT_HANDLE);
  DWORD dummy;
  if(GetConsoleMode(in, &dummy)){
    stdin_is_console = 1;
    stdin_event = in;
    return TRUE;
  }
  stdin_event = CreateEvent(NULL, TRUE, FALSE, NULL);
  InitializeCriticalSection(&io_crit);
  return (_beginthreadex(NULL,0,&stdin_thread,NULL,0,&dummy));
}

BOOL console_stdin(void){
  return stdin_is_console;
}

HANDLE get_stdin_event(void){
  return stdin_event;
}

