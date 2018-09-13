/// TestCoverage.UI.Application
Class TestCoverage.UI.Application Extends %ZEN.application
{

/// This is the name of this application.
Parameter APPLICATIONNAME;

/// This is the URL of the main starting page of this application.
Parameter HOMEPAGE;

/// Comma-separated list of additional JS include files that should be
/// included for every page within the application.
Parameter JSINCLUDES As STRING = "jquery-2.0.3.min.js";

/// This Style block contains application-wide CSS style definitions.
XData Style
{
<style type="text/css">
/* For dataGrid links */
a.elevated {
	z-index: 2;
	position: relative;
}

/* body/box/pre.coverage styles derived from MIT-licensed work: */
/*
Copyright (c) 2018 by Ole Bertram (https://codepen.io/elomatreb/pen/hbgxp)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
body {
	background-color: #eee;
	color: #555;
}

/* Modified from pre.coverage */
.box {
	background-color: #fff;
	padding: 0.5em;
	margin-top: 2em;
	border-radius: .25em;
	box-shadow: 0.1em 0.1em 0.5em rgba(0, 0, 0, 0.45);
}

pre.coverage {
	font-family: monospace;
	background-color: #fff;
	margin-top: 2em;
	margin-left: 4em auto;
	margin-right: 4em auto;
	padding: 0.5em;
	border-radius: .25em;
	box-shadow: 0.1em 0.1em 0.5em rgba(0, 0, 0, 0.45);
	line-height: 0;
	counter-reset: line;
	max-width: 80vw;
	max-height: 75vh;
	overflow-x: auto;
}
pre.coverage span {
	white-space: pre;
	tab-size: 4;
	display: block;
	line-height: 1.5em;
	width: 100%;
}
pre.coverage span:before {
	counter-increment: line;
	content: counter(line);
	display: inline-block;
	border-right: 1px solid #ddd;
	padding: 0 .5em;
	margin-right: .5em;
	min-width: 3em;
	color: #888;
}

/* Classes for display of code coverage */
pre.coverage span.executable:before {
	background-color: #f66;
}

pre.coverage span.covered:before {
	background-color: #6f6;
}

pre.coverage span.hide:before {
	background-color: #fff;
}

</style>
}

}

