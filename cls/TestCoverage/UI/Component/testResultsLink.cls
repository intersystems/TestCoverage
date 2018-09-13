Class TestCoverage.UI.Component.testResultsLink Extends %ZEN.Component.link [ System = 3 ]
{

/// This is the XML namespace for this component.
Parameter NAMESPACE = "http://www.intersystems.com/zen/healthshare/test-coverage";

/// ID of the instance of <class>TestCoverage.Data.Run</class> for which the associated test results should be shown.
Property coverageRunId As %ZEN.Datatype.string(ZENEXPRESSION = 1);

/// Text to display for the link.<br>
/// This value is interpreted as text, not HTML.<br>
/// Overridden to add a default.
Property caption As %ZEN.Datatype.caption(ZENEXPRESSION = 1) [ InitialExpression = "View Test Results" ];

/// Overridden to default to "_blank"
Property target As %ZEN.Datatype.string [ InitialExpression = "_blank" ];

/// Overridden to add ZENSETTING=0, which avoids invoking setProperty after this is
/// changed during a server-side operation;
/// this property is maintained automatically based on the presence and validity of
/// <property>coverageRunId</property>
Property disabled As %ZEN.Datatype.boolean(ZENSETTING = 0) [ InitialExpression = 0 ];

Method %DrawHTML()
{
	Try {
		Set tCoverageRunId = $$$ZENVAL(..coverageRunId)
		
		Set tResultsExist = 0
		If (tCoverageRunId '= "") {
			Set tCoverageRun = ##class(TestCoverage.Data.Run).%OpenId(tCoverageRunId,,.tSC)
			$$$ThrowOnError(tSC)
			If $IsObject(tCoverageRun.TestResults) {
				Set tResultsExist = 1
				Set tQuery("$NAMESPACE") = $namespace
				Set tQuery("Index") = tCoverageRun.TestResults.%Id()
				Set ..href = ##class(%CSP.Page).Link("/csp/sys/%25UnitTest.Portal.Indices.zen",.tQuery)
			}
		}
		
		Set ..disabled = 'tResultsExist
		If 'tResultsExist {
			Set ..href = "#"
		}
		
		Do ##super()
	} Catch e {
		Do ##class(%ZEN.Utils).%DisplayErrorHTML($This,e.AsStatus())
	}
}

}

