Class TestCoverage.UI.Template Extends %ZEN.Component.page [ Abstract ]
{

Parameter APPLICATION As CLASSNAME = "TestCoverage.UI.Application";

XData CSSPane [ XMLNamespace = "http://www.intersystems.com/zen" ]
{
<pane xmlns="http://www.intersystems.com/zen">
<codeCSS xmlns="http://www.intersystems.com/zen/healthshare/test-coverage" />
</pane>
}

XData TogglePane [ XMLNamespace = "http://www.intersystems.com/zen" ]
{
<pane xmlns="http://www.intersystems.com/zen">
<checkbox id="markCovered" label="Mark Covered Lines" onclick="zenPage.toggleCovered(zenThis.getValue())" value="1" />
</pane>
}

ClientMethod toggleCovered(pVisible) [ Language = javascript ]
{
	$("pre.coverage span.covered").toggleClass("hide",!pVisible);
}

ClientMethod buildCodeHTML(targetElement, codeLines) [ Language = javascript ]
{
	// Remove all children from the target to make the subsequent set of innerHTML faster.
	while (targetElement.firstChild) {
	    targetElement.removeChild(targetElement.firstChild);
	}
	var html = new Array();
	var showCovered = zen('markCovered').getValue()
	html.push('<pre class="coverage">\r\n');
	for (var i = 0; i < codeLines.length; i++) {
		var classes = new Array();
		if (codeLines[i].Executable) classes.push("executable");
		if (codeLines[i].Covered) {
			classes.push("covered");
			if (!showCovered) classes.push("hide");
		}
		var line = '<span class="'+classes.join(' ')+'">'+codeLines[i].ColoredHTML+'</span>\r\n';
		html.push(line);
	}
	html.push('</pre>');
	targetElement.innerHTML = html.join('');
}

ClientMethod renderCodeCoverage(providerID, htmlID) [ Language = javascript ]
{
	var code = zen(providerID).getContentObject().children;
	zenPage.buildCodeHTML(document.getElementById(htmlID),code);
}

}

