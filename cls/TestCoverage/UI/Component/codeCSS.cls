/// Component to render CSS styles for all languages supported by %Library.SyntaxColor
/// (Supports using CSS-enabled output mode rather than generating <FONT> tags.)
Class TestCoverage.UI.Component.codeCSS Extends %ZEN.Component.component [ System = 3 ]
{

/// This is the XML namespace for this component.
Parameter NAMESPACE = "http://www.intersystems.com/zen/healthshare/test-coverage";

/// Generated to provide styles for all supported languages.
Method %DrawHTML() [ CodeMode = objectgenerator ]
{
	Do %code.WriteLine($c(9)_"&html<<style type=""text/css"">")
	Set sc = $$$OK
	Try {
		Set colorHelper = ##class(%Library.SyntaxColor).%New()
		Do colorHelper.Languages(.list)
		Set pointer = 0
		While $ListNext(list,pointer,language) {
			Set stream = ##class(%Stream.GlobalCharacter).%New()
			If ##class(%Library.SyntaxColor).%New().GetCSS(.stream,language) {
				Do stream.Rewind()
				Do %code.CopyFrom(stream)
			}
		}
	} Catch e {
		Set sc = e.AsStatus()
	}
	Do %code.WriteLine("</style>>")
	Quit sc
}

}

