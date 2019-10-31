Class TestCoverage.UI.SimpleResultViewer Extends TestCoverage.UI.Template
{

Parameter PAGENAME = "Unit Test Coverage - Class Viewer";

Property testIndex As %ZEN.Datatype.string(ZENURL = "testIndex");

Property codeUnit As %ZEN.Datatype.string(ZENURL = "codeUnit");

Property testPath As %ZEN.Datatype.string;

XData Contents [ XMLNamespace = "http://www.intersystems.com/zen" ]
{
<page xmlns="http://www.intersystems.com/zen" xmlns:tc="http://www.intersystems.com/zen/healthshare/test-coverage" title="Unit Test Coverage - Class Viewer">
<pane paneName="CSSPane" />

<vgroup width="80%" align="center">
<hgroup align="left" enclosingClass="box" cellAlign="even">
<vgroup labelPosition="left">
<tc:select id="testIndex" label="Test Index" sql="select distinct Run from TestCoverage_Data.Coverage order by Run desc" onchange="zenPage.testFilterChanged(zenThis)" />
<tc:select id="testPath" label="Test Path" sql="select distinct %exact TestPath from TestCoverage_Data.Coverage where Run = ?" onchange="zenPage.testFilterChanged(zenThis)">
<parameter value="#(%page.testIndex)#" />
</tc:select>

<spacer height="25px" />

<tc:select id="codeCovered" label="Code Unit"
	sql="select distinct %exact Hash,Hash->Name||'.'||Hash->Type
			from TestCoverage_Data.Coverage d,(select ? as Run, ? as TestPath) params
			where d.Run = params.Run
				and (params.TestPath is null or params.TestPath = d.TestPath)
			order by DECODE(Hash->Type,'CLS',1,'MAC',2,3),Hash->Name"
	onchange="zenPage.showCodeCoverage();">
<parameter value="#(%page.testIndex)#" />
<parameter value="#(%page.testPath)#" />
</tc:select>
</vgroup>
<vgroup width="25%">
<pane paneName="TogglePane" labelPosition="left" />
</vgroup>
</hgroup>

<tc:altJSONSQLProvider id="coverageDataProvider" maxRows="10000" queryClass="TestCoverage.UI.Utils" queryName="ColoredText">
<parameter paramName="1" value="#(%page.testIndex)#" />
<parameter paramName="2" value="#(%page.codeUnit)#" />
<parameter paramName="3" value="#(%page.testPath)#" />
</tc:altJSONSQLProvider>

<html id="coverageResults" align="left">
</html>

</vgroup>

</page>
}

ClientMethod testFilterChanged(pSrcComponent As %ZEN.Component.select) [ Language = javascript ]
{
	zenPage[pSrcComponent.id] = pSrcComponent.getValue();
	
	if (pSrcComponent.id == 'testIndex') {
		zen('testPath').setValue('');
		zenPage.testPath = '';
	}
	
	zen('testPath').triggerRefresh();
	zen('codeCovered').triggerRefresh();

	if (zen('codeCovered').getValue() != '') {
		this.showCodeCoverage();
	}
}

ClientMethod showCodeCoverage() [ Language = javascript ]
{
	zenPage.codeUnit = zen('codeCovered').getValue();
	zen('coverageDataProvider').reloadContentsAsynch(function() {
		zenPage.renderCodeCoverage('coverageDataProvider','coverageResults');
	});
}

}

