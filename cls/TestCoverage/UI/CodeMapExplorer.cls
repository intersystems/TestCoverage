Class TestCoverage.UI.CodeMapExplorer Extends %ZEN.Component.page
{

Property generatedHash As %ZEN.Datatype.string;

Property sourceHash As %ZEN.Datatype.string;

XData Contents [ XMLNamespace = "http://www.intersystems.com/zen" ]
{
<page xmlns="http://www.intersystems.com/zen" xmlns:tc="http://www.intersystems.com/zen/healthshare/test-coverage" title="Unit Test Coverage - Code Map Explorer">
<!-- Generated-to-source mode -->
<hgroup labelPosition="left">
<tc:select id="fromCode" sql="select distinct FromHash,FromHash->Name||'.'||FromHash->Type from TestCoverage_Data.CodeUnitMap" label="From" onchange="zenPage.setProperty('generatedHash',zenThis.getValue());zen('toCode').refreshContents();"/>
<tc:select id="toCode" sql="select distinct ToHash,ToHash->Name||'.'||ToHash->Type from TestCoverage_Data.CodeUnitMap where FromHash = ?" label="To" onchange="zenPage.setProperty('sourceHash',zenThis.getValue());">
<parameter value="#(%page.generatedHash)#" />
</tc:select>
<button caption="Go" onclick="zen('codeTable').executeQuery();" />
</hgroup>
<tablePane id="codeTable" maxRows="1000" initialExecute="false" sql="
	select gen.element_key FromLine, gen.Lines FromCode, source.element_key ToLine, source.Lines ToCode from TestCoverage_Data.CodeUnit_Lines gen
	left join TestCoverage_Data.CodeUnitMap map
		on map.FromHash = gen.CodeUnit
		and map.FromLine = gen.element_key
		and map.ToHash = ?
	left join TestCoverage_Data.CodeUnit_Lines source
		on map.ToHash = source.CodeUnit
		and map.ToLine = source.element_key
	where gen.CodeUnit = ?
">
<parameter value="#(%page.sourceHash)#" />
<parameter value="#(%page.generatedHash)#" />
<column header="#" colName="FromLine" />
<column header="Generated" colName="FromCode" />
<column header="#" colName="ToLine" />
<column header="Source" colName="ToCode" />
</tablePane>
</page>
}

}

