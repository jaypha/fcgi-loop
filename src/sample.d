// Written in the D programming language.
/*
 * Sample fcgi-loop program.
 *
 * Copyright 2013 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 *
 * Authors: Jason den Dulk
 */

module sample;

import jaypha.fcgi.loop;

import std.conv;

//----------------------------------------------------------------------------
// Function that is called for each request.

void process(ref FcgiRequest r)
{
  /*
   * Your code to process the request.
   */


  r.fcgiOut.put(cast(const(ubyte)[])"Content-Type: text/plain\r\n");
  r.fcgiOut.put(cast(const(ubyte)[])"\r\n");
  r.fcgiOut.put(cast(const(ubyte)[])"Hello World!\r\n");
  r.fcgiOut.put(cast(const(ubyte)[])"This is FCGI Loop\r\n\r\n");
  r.fcgiOut.put(cast(const(ubyte)[])"Environment:\r\n");
  foreach (i,v; r.env)
  {
    r.fcgiOut.put(cast(const(ubyte)[])i);
    r.fcgiOut.put(cast(const(ubyte)[])": ");
    r.fcgiOut.put(cast(const(ubyte)[])v);
    r.fcgiOut.put(cast(const(ubyte)[])"\r\n");
  }
}

//----------------------------------------------------------------------------

void main()
{
  // Simply call fcgiLoop with the named callback.
  fcgiLoop(&process);
}
