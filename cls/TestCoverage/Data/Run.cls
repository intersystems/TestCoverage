Class TestCoverage.Data.Run Extends %Persistent
{

/// Test paths included in this run
Property TestPaths As list Of %String(MAXLEN = "", STORAGEDEFAULT = "array");

/// Unit test results associated with this coverage report
Property TestResults As %UnitTest.Result.TestInstance;

/// List of metrics measured during test coverage (see datatype class for options)
Property Metrics As list Of TestCoverage.DataType.Metric(STORAGEDEFAULT = "array");

/// Subject of test coverage.
/// For example, an application or module name.
Property Subject As %String(MAXLEN = 255);

/// Changelist, timestamp, or other identifier at which these coverage results were obtained.
/// Any metric used for this should order changes in ascending order by point in time.
Property Ordering As %String;

/// Set to true if the test coverage data is for committed code (rather than pending/in-review changes)
Property IsCommitted As %Boolean [ InitialExpression = 0 ];

/// Index to easily find the first coverage run before/after a given point in time.
Index ComparisonIndex On (Subject, IsCommitted, Ordering);

/// Level of detail of the test coverage run
Property Detail As TestCoverage.DataType.Detail;

/// Given .INT code coverage for a test run, maps it to .CLS/.MAC.
ClassMethod MapRunCoverage(pRunIndex As %Integer) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tRun = ##class(TestCoverage.Data.Run).%OpenId(pRunIndex,,.tSC)
		$$$ThrowOnError(tSC)
		
		// It would be wonderful if there was support for something along the lines of (with a few made up non-functions):
		/*
			INSERT OR UPDATE INTO TestCoverage_Data.Coverage
				(Run,Hash,TestPath,CoveredLines,Ignore)
			SELECT :pRunIndex,map.ToHash,TestPath,$BITLOGIC(%BITLIST(CASE $BIT(source.CoveredLines,map.FromLine)
				WHEN 1 THEN map.ToLine ELSE NULL END)|oldCoverage.CoveredLines),
				source.Hash->Generated
			FROM TestCoverage_Data.Coverage source
			JOIN TestCoverage_Data.CodeUnitMap map
				ON source.Hash = map.FromHash
			LEFT JOIN TestCoverage_Data.Coverage oldCoverage
				ON oldCoverage.Run = source.Run
				AND oldCoverage.Hash = map.ToHash
				AND oldCoverage.TestPath = source.TestPath
			WHERE source.Run = :pRunIndex
				AND source.Ignore = 0
				AND source.Calculated = 0
			GROUP BY map.ToHash,source.TestPath
		*/
		
		// Here's a worse-performing approach with some extrinsic calls that ideally wouldn't be necessary:
		&SQL(
			INSERT OR UPDATE INTO TestCoverage_Data.Coverage
				(Run,Hash,TestPath,CoveredLines,Ignore)
			SELECT :pRunIndex,map.ToHash,%exact source.TestPath,TestCoverage.BITWISE_OR(
				TestCoverage.LIST_TO_BIT(%DLIST(
					CASE TestCoverage.BIT_VALUE(source.CoveredLines,map.FromLine)
					WHEN 1 THEN map.ToLine
					ELSE NULL END)),oldCoverage.CoveredLines),
				map.ToHash->Generated
			FROM TestCoverage_Data.Coverage source
			JOIN TestCoverage_Data.CodeUnitMap map
				ON source.Hash = map.FromHash
			LEFT JOIN TestCoverage_Data.Coverage oldCoverage
				ON oldCoverage.Run = source.Run
				AND oldCoverage.Hash = map.ToHash
				AND oldCoverage.TestPath = source.TestPath
			WHERE source.Run = :pRunIndex
				AND source.Ignore = 0
				AND source.Calculated = 0
			GROUP BY map.ToHash,source.TestPath)
		If (SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
		}
		
		// Copy any other metrics captured/requested as well.
		For i=1:1:tRun.Metrics.Count() {
			Set tMetric = tRun.Metrics.GetAt(i)
			Set tSQLStatement = "INSERT OR UPDATE INTO TestCoverage_Data.""Coverage_"_tMetric_""" "_
				"(Coverage,element_key,"""_tMetric_""") "_
				"SELECT target.ID,map.ToLine,NVL(oldMetric."""_tMetric_""",0) + metric."""_tMetric_""" "_
				"FROM TestCoverage_Data.Coverage source "_
				"JOIN TestCoverage_Data.CodeUnitMap map "_
				"	ON source.Hash = map.FromHash "_
				"JOIN TestCoverage_Data.""Coverage_"_tMetric_""" metric "_
				"	ON metric.Coverage = source.ID "_
				"	AND metric.element_key = map.FromLine "_
				"JOIN TestCoverage_Data.Coverage target "_
				"	ON target.Run = source.Run "_
				"	AND target.Hash = map.ToHash "_
				"	AND target.TestPath = source.TestPath "_
				"LEFT JOIN TestCoverage_Data.""Coverage_"_tMetric_""" oldMetric "_
				"	ON oldMetric.ID = target.ID "_
				"	AND oldMetric.element_key = map.ToLine "_
				"WHERE source.Run = ? "_
				"	AND source.Ignore = 0"_
				"	AND source.Calculated = 0"
			
			#dim tResult As %SQL.StatementResult
			Set tResult = ##class(%SQL.Statement).%ExecDirect(,tSQLStatement,pRunIndex)
			If (tResult.%SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Storage Default
{
<Data name="Metrics">
<Attribute>Metrics</Attribute>
<Structure>subnode</Structure>
<Subscript>"Metrics"</Subscript>
</Data>
<Data name="RunDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>TestResults</Value>
</Value>
<Value name="3">
<Value>Subject</Value>
</Value>
<Value name="4">
<Value>Ordering</Value>
</Value>
<Value name="5">
<Value>IsCommitted</Value>
</Value>
<Value name="6">
<Value>Detail</Value>
</Value>
</Data>
<Data name="TestPaths">
<Attribute>TestPaths</Attribute>
<Structure>subnode</Structure>
<Subscript>"TestPaths"</Subscript>
</Data>
<DataLocation>^TestCoverage.Data.RunD</DataLocation>
<DefaultData>RunDefaultData</DefaultData>
<IdLocation>^TestCoverage.Data.RunD</IdLocation>
<IndexLocation>^TestCoverage.Data.RunI</IndexLocation>
<StreamLocation>^TestCoverage.Data.RunS</StreamLocation>
<Type>%Library.CacheStorage</Type>
}

}

