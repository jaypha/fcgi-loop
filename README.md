FCGI Loop
=========

This project contains a simple D front end for the Open Market FCGI library.

Usage
-----

Call `fcgi_loop` with a callback function to process requests. See documentation for more details.


Modules
-------

All my modules are kept under the 'jaypha' umbrella package. The fcgi
library consists of the following modules.

* jaypha.fcgi.loop
* jaypha.fcgi.c.fcgiapp.di

Why not use Deimos Fcgi?
------------------------

The Deimos bindings lack the necessary copyright and license information,
making it unsuitable for commercial use.

License
-------

All original code is distributed under the Boost License
(see LICENSE.txt). Third party licenses are kept in the licenses
directory.
