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

enum defaultThreadCount = 10;

// Note: In HTTP, input and output are octet streams. That is, an array of ubytes.

//---------------------------------------------------------------------------
// An adapter for outgoing FCGI streams that acts as an output range.
//-------------------------------------
struct FcgiOutStream
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
struct FcgiInStream
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
struct FcgiRequest
//-------------------------------------
{
  private FCGX_Request request;

  FcgiOutStream fcgiOut;
  FcgiOutStream fcgiErr;
  FcgiInStream  fcgiIn;

  string[string] env;

  private void prepare()
  {
    fcgiOut = FcgiOutStream(request._out);
    fcgiErr = FcgiOutStream(request._err);
    fcgiIn  = FcgiInStream(request._in);
    env = ppToAssoc(cast(const(char)**) request.envp);
  }
}

//---------------------------------------------------------------------------
// Main loop.

void fcgiLoop(void function(ref FcgiRequest) callback, uint numThreads = defaultThreadCount)
{
  // Spawn the required number of threads.
  foreach(i;0..numThreads)
    spawnLinked(&newThread, callback);

  // Each time a thread terminates, spawn a new one.
  while (true)
  {
    auto m = receiveOnly!LinkTerminated();
    spawnLinked(&newThread, callback);
  }
}

//---------------------------------------------------------------------------
// This function indefinitely loops through each request.

private void newThread(void function(ref FcgiRequest) fp)
{
  FcgiRequest rr;

  FCGX_Init();

  while (true)
  {
    FCGX_InitRequest(&rr.request, 0, 0);
    FCGX_Accept_r(&rr.request);
    scope(exit) { FCGX_Finish_r(&rr.request); }

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


private string[string] ppToAssoc(const(char)** pp)
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

  static assert(isOutputRange!(FcgiOutStream,const(ubyte)[]));
  static assert(isOutputRange!(FcgiOutStream,const ubyte));

  const(char)*[] pp;
  pp ~= std.string.toStringz("timber=alice");
  pp ~= std.string.toStringz("usb=false");
  pp ~= null;

  auto ass = ppToAssoc(pp.ptr);

  assert (ass.length == 2);
  assert ("timber" in ass);
  assert (ass["timber"] == "alice");
  assert ("usb" in ass);
  assert (ass["usb"] == "false");
}

