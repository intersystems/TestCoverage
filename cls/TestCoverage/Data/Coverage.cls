IncludeGenerator TestCoverage

Class TestCoverage.Data.Coverage Extends %Persistent
{

Index UniqueCoverageData On (Run, Hash, TestPath) [ Unique ];

Index MeaningfulCoverageData On (Run, Calculated, Ignore, Hash, TestPath) [ Data = CoveredLines, Unique ];

/// Reference to the test coverage tracking run for which this coverage data was collected.
Property Run As TestCoverage.Data.Run [ Required ];

/// Path through test cases/suites
Property TestPath As %String(COLLATION = "EXACT", MAXLEN = 300, TRUNCATE = 1) [ Required ];

/// Target code unit, uniquely identified by hash.
Property Hash As TestCoverage.Data.CodeUnit [ Required ];

/// If set to 1, this coverage data should be ignored in reports/aggregates.
Property Ignore As %Boolean [ InitialExpression = 0 ];

/// If set to 1, this coverage data was calculated as a rollup based on underlying data.
Property Calculated As %Boolean [ InitialExpression = 0 ];

Index Run On Run [ Type = bitmap ];

Index TestPath On TestPath [ Type = bitmap ];

Index Hash On Hash [ Type = bitmap ];

Index Ignore On Ignore [ Type = bitmap ];

Index Calculated On Calculated [ Type = bitmap ];

ForeignKey RunFK(Run) References TestCoverage.Data.Run() [ OnDelete = cascade ];

ForeignKey HashFK(Hash) References TestCoverage.Data.CodeUnit(Hash);

// METRICS

/// Bitstring of "Line Covered" flags
Property CoveredLines As TestCoverage.DataType.Bitstring;

/// List of "RtnLine" counts subscripted by line number
Property RtnLine As array Of %Integer;

/// List of "Time" measurements from line-by-line monitor, subscripted by line number
Property Time As array Of TestCoverage.DataType.Timing [ SqlFieldName = _TIME ];

/// List of "TotalTime" measurements from line-by-line monitor, subscripted by line number
Property TotalTime As array Of TestCoverage.DataType.Timing;

ClassMethod StoreIntCoverage(pRun As %Integer, pTestPath As %String, pName As %String, pType As %String, ByRef pCache) As %Status
{
	// pType must be either INT or PY 
	Set tSC = $$$OK
	Try {
		#dim tResult As %SQL.StatementResult
		Set tSC = ##class(TestCoverage.Data.CodeUnit).GetCurrentByName(pName_"."_pType,,.tCodeUnit,.pCache)
		$$$ThrowOnError(tSC)
		
		If ..UniqueCoverageDataExists(pRun,tCodeUnit.Hash,pTestPath,.tID) {
			Set tInstance = ..%OpenId(tID,,.tSC)
			$$$ThrowOnError(tSC)
		} Else {
			Set tInstance = ..%New()
			Set tSC = tInstance.RunSetObjectId(pRun)
			$$$ThrowOnError(tSC)
			Set tInstance.TestPath = pTestPath
			Set tInstance.Hash = tCodeUnit
		}
		
		Set tCoveredLines = tInstance.CoveredLines
		if (pType = "INT")
		{
			Set tAvailableMetrics = ..GetAvailableMetrics()
			Set tPointer = 0
			While $ListNext(tAvailableMetrics,tPointer,tMetricKey) {
				If tInstance.Run.Metrics.Find(tMetricKey) {
					Set tMetrics(tMetricKey) = $Property(tInstance,tMetricKey)
				}
			}
			// ROWSPEC = "LineNumber:%Integer,LineCovered:%Boolean,RtnLine:%Integer,Time:%Numeric,TotalTime:%Numeric"
			Set tResult = ##class(TestCoverage.Utils).LineByLineMonitorResultFunc(pName)
			While tResult.%Next(.tSC) {
				$$$ThrowOnError(tSC)
				Set tLineNumber = tResult.%Get("LineNumber")
				If tResult.%Get("LineCovered") {
					Set $Bit(tCoveredLines,tLineNumber) = 1
				}
				Set tMetricKey = ""
				For {
					Set tMetricKey = $Order(tMetrics(tMetricKey),1,tMetric)
					If (tMetricKey = "") {
						Quit
					}
					Do tMetric.SetAt(tResult.%Get(tMetricKey) + tMetric.GetAt(tLineNumber),tLineNumber)
				}
			}
			$$$ThrowOnError(tSC)
		}
		Else { // If pType = "PY"
			//^IRIS.TEMPCJG(148,1)="EP.sysSettrace", ^IRIS.TEMPCJG(148,2)="fun_generator", ^IRIS.TEMPCJG(148,3)=120
			if $Data(^IRIS.TEMPCJG(pName)) {
				for i = 1:1:(^IRIS.TEMPCJG(pName)-1) {
					Set tLineNumber = ^IRIS.TEMPCJG(pName, i)
					Set $Bit(tCoveredLines, tLineNumber) = 1
				}
			}
			
		}
		
		Set tInstance.CoveredLines = $BitLogic(tInstance.CoveredLines|tCoveredLines)
		
		Set tSC = tInstance.%Save()
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod GetAvailableMetrics() As %List [ CodeMode = objectgenerator ]
{
	// Note: this is implemented as a generator method to avoid referencing an include file in a persistent class.
	// Doing so makes shipping this tool as a deployed Studio project difficult, because include files cannot be deployed,
	// and dynamic queries against this class will end up referencing the include file.
	#define QuotedMetrics ##quote($$$METRICS)
	Do %code.WriteLine(" Quit $ListBuild("_$$$QuotedMetrics_")")
	Quit $$$OK
}

Storage Default
{
<Data name="CoverageDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>TestPath</Value>
</Value>
<Value name="4">
<Value>Hash</Value>
</Value>
<Value name="5">
<Value>Ignore</Value>
</Value>
<Value name="6">
<Value>Calculated</Value>
</Value>
<Value name="7">
<Value>CoveredLines</Value>
</Value>
</Data>
<Data name="RtnLine">
<Attribute>RtnLine</Attribute>
<Structure>subnode</Structure>
<Subscript>"RtnLine"</Subscript>
</Data>
<Data name="Time">
<Attribute>Time</Attribute>
<Structure>subnode</Structure>
<Subscript>"Time"</Subscript>
</Data>
<Data name="TotalTime">
<Attribute>TotalTime</Attribute>
<Structure>subnode</Structure>
<Subscript>"TotalTime"</Subscript>
</Data>
<DataLocation>^TestCoverage.Data.CoverageD</DataLocation>
<DefaultData>CoverageDefaultData</DefaultData>
<IdLocation>^TestCoverage.Data.CoverageD</IdLocation>
<IndexLocation>^TestCoverage.Data.CoverageI</IndexLocation>
<StreamLocation>^TestCoverage.Data.CoverageS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
