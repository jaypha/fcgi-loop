// Written in the D programming language.
/*
 * Sample fcgi program.
 *
 * Copyright 2013 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 *
 * Authors: Jason den Dulk
 */

module sample;

import jaypha.fcgi.loop;

void process(ref FCGI_Request r)
{
  /*
   * Your code to process the request.
   */

  r.fcgi_out.put(cast(const(ubyte)[])"Content-Type: text/plain\r\n");
  r.fcgi_out.put(cast(const(ubyte)[])"\r\n");
  r.fcgi_out.put(cast(const(ubyte)[])"Hello World!\r\n");
  r.fcgi_out.put(cast(const(ubyte)[])"This is FCGI Loop\r\n");
}

void main()
{
  fcgi_loop(&process);
}
