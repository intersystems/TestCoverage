Class TestCoverage.UI.ResultDetailViewer Extends TestCoverage.UI.Template
{

Parameter PAGENAME = "Unit Test Coverage - Detail";

Property testIndex As %ZEN.Datatype.string(ZENURL = "testIndex");

Property codeUnit As %ZEN.Datatype.string(ZENURL = "codeUnit");

Property testPath As %ZEN.Datatype.string;

XData Contents [ XMLNamespace = "http://www.intersystems.com/zen" ]
{
<page xmlns="http://www.intersystems.com/zen" xmlns:tc="http://www.intersystems.com/zen/healthshare/test-coverage" title="Unit Test Coverage - Class Viewer">

<vgroup width="80%" align="center">
<hgroup align="left" enclosingClass="box" cellAlign="even">
<vgroup labelPosition="left">
<tc:select id="testPath" label="Test Path" sql="select distinct %exact TestPath from TestCoverage_Data.Coverage where Run = ? and Hash = ?" onchange="zenPage.testFilterChanged(zenThis)">
<parameter value="#(%page.testIndex)#" />
<parameter value="#(%page.codeUnit)#" />
</tc:select>
</vgroup>
<vgroup width="25%">
<pane paneName="TogglePane" labelPosition="left" />
</vgroup>
</hgroup>

<altJSONSQLProvider id="coverageDataProvider" maxRows="10000" queryClass="TestCoverage.UI.Utils" queryName="ColoredText">
<parameter paramName="1" value="#(%page.testIndex)#" />
<parameter paramName="2" value="#(%page.codeUnit)#" />
<parameter paramName="3" value="#(%page.testPath)#" />
</altJSONSQLProvider>

<html id="coverageResults" align="left">
</html>

</vgroup>

</page>
}

ClientMethod testFilterChanged(pSrcComponent As %ZEN.Component.select) [ Language = javascript ]
{
	var value = pSrcComponent.getValue();
	if (pSrcComponent.id == 'testPath') {
		zenPage.testPath = value;
	}
	
	this.showCodeCoverage();
}

ClientMethod showCodeCoverage() [ Language = javascript ]
{
	zen('coverageDataProvider').reloadContentsAsynch(function() {
		var code = zen('coverageDataProvider').getContentObject().children;
		document.getElementById('coverageResults').innerHTML = zenPage.buildCodeHTML(code);
	});
}

/// This client event, if present, is fired when the page is loaded.
ClientMethod onloadHandler() [ Language = javascript ]
{
	zenPage.showCodeCoverage();
}

}

