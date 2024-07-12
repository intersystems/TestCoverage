Class TestCoverage.UI.AggregateResultViewer Extends TestCoverage.UI.Template
{

/// Displayed name of this page.
Parameter PAGENAME = "Unit Test Coverage - Aggregate Results";

/// Domain used for localization.
Parameter DOMAIN;

Property testIndex As %ZEN.Datatype.string(ZENURL = "Index");

/// This XML block defines the contents of this page.
XData Contents [ XMLNamespace = "http://www.intersystems.com/zen" ]
{
<page xmlns="http://www.intersystems.com/zen" xmlns:tc="http://www.intersystems.com/zen/healthshare/test-coverage" title="Unit Test Coverage - Aggregate Results">
<vgroup width="80%" align="center">
<vgroup labelPosition="left" align="left" enclosingClass="box" layout="horizontal">
<tc:select id="testIndex" value="#(%page.testIndex)#" label="Test Index" sql="select distinct Run from TestCoverage_Data_Aggregate.ByRun order by Run desc" onchange="zenPage.testFilterChanged(zenThis)" />
<spacer width="25%" />
<tc:testResultsLink id="testResultsLink" coverageRunId="#(%page.testIndex)#" />
</vgroup>
<vgroup labelPosition="left" align="left" enclosingClass="box" layout="none">
<altJSONSQLProvider id="aggregateDataProvider" maxRows="10000"
	sql="	select 'Overall' As Routine,
				ROUND(100*CoveredLines/ExecutableLines,2) PercentCoverage,
				ExecutableLines as ExecutableLines,
				CoveredLines As LinesCovered,
				CASE ExecutableMethods WHEN 0 THEN NULL ELSE ROUND(100*CoveredMethods/ExecutableMethods,2) END As MethodCoverage,
				ExecutableMethods As ExecutableMethods,
				CoveredMethods As MethodsCovered,
				'' as Info,
				1 as TopSortOrder
			from TestCoverage_Data_Aggregate.ByRun where ExecutableLines > 0 and Run = ?
			union all
			select CodeUnit->Name||'.'||CodeUnit->Type,
				ROUND((CoveredLines/ExecutableLines)*100,2),
				ExecutableLines,
				CoveredLines,
				CASE ExecutableMethods WHEN 0 THEN NULL ELSE ROUND((CoveredMethods/ExecutableMethods)*100,2) END,
				ExecutableMethods,
				CoveredMethods,
				CodeUnit /* for link to detail */,
				2
			from TestCoverage_Data_Aggregate.ByCodeUnit where ExecutableLines > 0 and Run = ?
			order by TopSortOrder,Routine">
<parameter paramName="1" value="#(%page.testIndex)#" />
<parameter paramName="2" value="#(%page.testIndex)#" />
</altJSONSQLProvider>

<tc:dataGrid id="aggregateDataGrid" controllerId="aggregateDataProvider" width="100%" ondrawcell="return zenPage.drawCell(value,row,col);">
<columnDescriptor caption="Code Unit" type="string" readOnly="true"/>

<columnDescriptor caption="% Lines" type="string" readOnly="true"/>
<columnDescriptor caption="# Lines" type="string" readOnly="true"/>
<columnDescriptor caption="# Covered" type="string" readOnly="true"/>

<columnDescriptor caption="% Methods" type="string" readOnly="true"/>
<columnDescriptor caption="# Methods" type="string" readOnly="true"/>
<columnDescriptor caption="# Covered" type="string" readOnly="true"/>

<columnDescriptor />
</tc:dataGrid>
</vgroup>
</vgroup>
</page>
}

ClientMethod testFilterChanged() [ Language = javascript ]
{
	zenPage.testIndex = zen('testIndex').getValue();
	zen('aggregateDataProvider').reloadContentsAsynch(function() {
		zen('aggregateDataProvider').raiseDataChange();
	});
	zen('testResultsLink').refreshContents(true);
}

ClientMethod drawCell(value, row, col) [ Language = javascript ]
{
	if ((col == 2) || (col == 5)) {
		// Fix value to 2 decimal places
		var text = (value === '') ? '' : parseFloat(value).toFixed(2);
		return {
			content:'<strong>'+text+'</strong>',
			align:'right'
		};
	} else if (col == 8) { //Info
		var html = [];
		if (value != '') {
			var testIndex = encodeURIComponent(zenPage.testIndex);
			var codeUnit = encodeURIComponent(value);
			var url = 'TestCoverage.UI.ResultDetailViewer.cls?testIndex='+testIndex+'&codeUnit='+codeUnit;
			html.push('<a target="_blank" href="'+url+'" class="elevated">');
			html.push('[detail]');
			html.push('</a>');
		}
		return {
			content:html.join('')
		};
	}
}

}
