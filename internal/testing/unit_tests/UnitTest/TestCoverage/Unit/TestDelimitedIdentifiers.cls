Include TestCoverage

Class UnitTest.TestCoverage.Unit.TestDelimitedIdentifiers Extends %UnitTest.TestCase
{

Property InitialDelimitedIdentifiersSetting As %Boolean;

Property Run As TestCoverage.Data.Run;

Method TestWithDelimitedIdentifiers()
{
	Do $System.SQL.SetDelimitedIdentifiers(0,.old)
	Set ..InitialDelimitedIdentifiersSetting = old
	Do $$$AssertStatusOK($System.OBJ.CompilePackage("TestCoverage","ck-d/nomulticompile"))
	
	Set ..Run = ##class(TestCoverage.Data.Run).%New()
	Set ..Run.Detail = 1 // Force calculation of rollups
	For metric = $$$METRICS {
		Do ..Run.Metrics.Insert(metric)
	}
	Do $$$AssertStatusOK(..Run.%Save())
	
	// Other things that are likely to break:
	// Dynamic SQL in TestCoverage.Data.Run:MapRunCoverage
	Set sc = $$$OK
	Try {
		Do ##class(TestCoverage.Data.Run).MapRunCoverage(..Run.%Id())
	} Catch e {
		Set sc = e.AsStatus()
	}
	Do $$$AssertStatusOK(sc,"No exceptions thrown by TestCoverage.Data.Run:MapRunCoverage.")
	
	// Dynamic SQL in TestCoverage.Utils:AggregateCoverage
	Set sc = $$$OK
	Try {
		Do ##class(TestCoverage.Utils).AggregateCoverage(..Run.%Id())
	} Catch e {
		Set sc = e.AsStatus()
	}
	Do $$$AssertStatusOK(sc,"No exceptions thrown by TestCoverage.Utils:AggregateCoverage.")
}

/// Clean up: Delimited Identifiers setting, run ID
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
	Set sc = $$$OK
	If (..InitialDelimitedIdentifiersSetting '= "") {
		Set sc = $System.SQL.SetDelimitedIdentifiers(..InitialDelimitedIdentifiersSetting,.old)
		If (old '= ..InitialDelimitedIdentifiersSetting) {
			// Recompile with original setting, just to be safe.
			Set sc = $$$ADDSC(sc,$System.OBJ.Compile("TestCoverage","ck-d/nomulticompile"))
		}
	}
	If $IsObject(..Run) {
		Set sc = $$$ADDSC(sc,##class(TestCoverage.Data.Run).%DeleteId(..Run.%Id()))
	}
	Quit sc
}

}

