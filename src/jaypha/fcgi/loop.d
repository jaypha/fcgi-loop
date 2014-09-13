// Written in the D programming language.
/*
 * An interface to the FastCGI library provided by Open Market.
 *
 * Provides a function to loop through requests, utilising a number of
 * threads created at startup.
 *
 * Also provides adapters to allow access to the input and output streams and
 * the environment variables via D style interfaces.
 *
 * Copyright 2013 Jaypha
 * Distributed under the Boost License V1.0.
 * Authors: Jason den Dulk
 */

module jaypha.fcgi.loop;

import std.concurrency;
import std.array;

import jaypha.fcgi.c.fcgiapp;

enum default_thread_count = 10;

// Note: In HTTP, input and output are octet streams. That is, an array of ubytes.

//---------------------------------------------------------------------------
// An adapter for outgoing FCGI streams that acts as an output range.
//-------------------------------------
struct FCGI_OutStream
//-------------------------------------
{
  FCGX_Stream* stream;

  this(FCGX_Stream* _stream)
  {
    stream = _stream;
  }

  void put(const(ubyte)[] c)
  {
    FCGX_PutStr(cast(const(char)*)c.ptr, cast(int)c.length, stream);
  }

  void put(const ubyte c)
  {
    FCGX_PutChar(cast(const(char))c, stream);
  }
}

//---------------------------------------------------------------------------
// An adapter for incoming FCGI streams that acts as an input range.
//-------------------------------------
struct FCGI_InStream
//-------------------------------------
{
  FCGX_Stream* stream;

  this(FCGX_Stream* _stream)
  {
    stream = _stream;
    popFront();
  }

  bool empty = false;
  ubyte front;

  void popFront()
  {
    int next = FCGX_GetChar(stream);
    if (next == -1)
      empty = true;
    front = cast(ubyte) next;
  }
}

//---------------------------------------------------------------------------
// Bundle up stuff used by a request.
//-------------------------------------
struct FCGI_Request
//-------------------------------------
{
  private FCGX_Request request;

  FCGI_OutStream fcgi_out;
  FCGI_OutStream fcgi_err;
  FCGI_InStream  fcgi_in;

  uint threadNo;

  string[string] env;

  private void prepare()
  {
    fcgi_out = FCGI_OutStream(request._out);
    fcgi_err = FCGI_OutStream(request._err);
    fcgi_in  = FCGI_InStream(request._in);
    env = pp_to_assoc(cast(const(char)**) request.envp);
  }
}

//---------------------------------------------------------------------------
// Main loop.

void fcgi_loop(void function(ref FCGI_Request) fp, uint num_threads = default_thread_count)
{
  // Spawn the required number of threads.
  foreach(i;0..num_threads)
    spawnLinked(&new_thread, fp);

  // Each time a thread terminates, spawn a new one.
  while (true)
  {
    auto m = receiveOnly!LinkTerminated();
    spawnLinked(&new_thread, fp);
  }
}

//---------------------------------------------------------------------------

immutable string basic_error_response = "Content-Type: text/plain\r\nStatus: 500 Internal Error\r\n\r\n";

private void new_thread(void function(ref FCGI_Request) fp)
{
  FCGI_Request rr;

  FCGX_Init();

  while (true)
  {
    FCGX_InitRequest(&rr.request, 0, 0);
    FCGX_Accept_r(&rr.request);
    scope(exit) { FCGX_Finish_r(&rr.request); }
    scope(failure)
    {
      FCGX_PutStr(basic_error_response.ptr, cast(int)basic_error_response.length, rr.request._out);
    }

    rr.prepare();
    fp(rr);
  }
}

//---------------------------------------------------------------------------

/*
 * Takes the environment variables as given by the FCGI and puts them
 * into an associative array.
 *
 * In FCGI, the environment variables are given in a two dimensional
 * char array.
 * The outer array is null terminated.
 * The inner arrays are C strings of the format "<name>=<value>".
 */


string[string] pp_to_assoc(const(char)** pp)
{
  string[string] ass;

  for (const(char)** p = pp; *p !is null; ++p)
  {
    const(char)* c = *p;
    auto napp = appender!string();
    while (*c != '=')
    {
      napp.put(*c);
      ++c;
    }
    ++c;
    auto vapp = appender!string();
    while (*c != '\0')
    {
      vapp.put(*c);
      ++c;
    }
    ass[napp.data] = vapp.data;
  }
  return ass;
}

//---------------------------------------------------------------------------

unittest
{
  import std.range, std.string;

  static assert(isOutputRange!(FCGI_OutStream,const(ubyte)[]));
  static assert(isOutputRange!(FCGI_OutStream,const ubyte));

  const(char)*[] pp;
  pp ~= std.string.toStringz("timber=alice");
  pp ~= std.string.toStringz("usb=false");
  pp ~= null;

  auto ass = pp_to_assoc(pp.ptr);

  assert (ass.length == 2);
  assert ("timber" in ass);
  assert (ass["timber"] == "alice");
  assert ("usb" in ass);
  assert (ass["usb"] == "false");
}

