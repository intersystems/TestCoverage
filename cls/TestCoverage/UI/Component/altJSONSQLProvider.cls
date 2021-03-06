Class TestCoverage.UI.Component.altJSONSQLProvider Extends %ZEN.Auxiliary.altJSONSQLProvider [ System = 3 ]
{

/// This is the XML namespace for this component.
Parameter NAMESPACE = "http://www.intersystems.com/zen/healthshare/test-coverage";

/// Overridden to deal with a few issues on older platform versions
/// (minimal modifications, all commented as such)
Method %DrawJSON() As %Status [ Internal ]
{
	Set ..contentType = "array"
	// override base method to get information from SQL statement
	Set tSC = $$$OK
	Try {
		#; convert parameters to local array
		Set key = ..parameters.Next("")
		While (key'="") {
			Set value = ..parameters.GetAt(key).value
			Set tParms(key) = $$$ZENVAL(value)
			Set key = ..parameters.Next(key)
		}
		Set tOrigSQL = ..sql
		Set tSQL = ..sql

		If (..OnGetSQL '= "") {
			Set tSC = ..%OnGetSQL(.tParms,.tSQL)
			If $$$ISERR(tSC) {
				Write "null"
				Quit
			}
			Set ..sql = tSQL
		}

		Set tInfo = ##class(%ZEN.Auxiliary.QueryInfo).%New()
		Merge tInfo.parms=tParms
		Set tRS = ..%CreateResultSet(.tSC,tInfo)
		If $$$ISERR(tSC)||'$IsObject(tRS) {
			Write "null"
			Quit
		}

		// find number and name of columns
		Kill tColInfo
		If tRS.%IsA("%Library.ResultSet") {
			Set tCols = tRS.GetColumnCount()
			For c = 1:1:tCols { 
				Set tColInfo(c,"name") = tRS.GetColumnHeader(c)
			}
		}
		Else {
			Set tCols = tRS.%ResultColumnCount
			For c = 1:1:tCols {
				Set tColInfo(c,"name") = tRS.%Metadata.columns.GetAt(c).label
			}
		}
		Set ..sql = tOrigSQL

 		Set aet = ##class(%DynamicAbstractObject).%FromJSON("{"""_..arrayName_""":[]}")
 		Set arrayNode = aet.%Get(..arrayName)

		// fetch and emit JSON
		// n.b. this should be pushed into the result set itself
		Set tRow = 0
		While (tRS.%Next(.tSC) && ((..maxRows = 0) || (tRow < ..maxRows))) {
			Quit:$$$ISERR(tSC)
			Set tRow = tRow + 1
			Set node = ##class(%DynamicObject).%New()
			For c = 1:1:tCols {
				Set tVal = tRS.%GetData(c)
				
				// MODIFICATION IN OVERRIDE:
				// To avoid JS errors on clients, insert an "invisible space" into any "</script>" tags specifically.
				Set tVal = $Replace(tVal,"</script>","</scr"_$c(8203)_"ipt>")
				Set tVal = $Replace(tVal,"</SCRIPT>","</SCR"_$c(8203)_"IPT>")
				// END MODIFICATION.
				
				If ($IsValidNum(tVal)) {
					Do node.%Set($Get(tColInfo(c,"name")),$Num(tVal),"number")
				}
				Else {
					Do node.%Set($Get(tColInfo(c,"name")),tVal)
				}
			}
			Do arrayNode.%Push(node)
		}
		
		// MODIFICATION IN OVERRIDE:
		// Support larger text and avoid old I/O redirection issues by outputting to stream.
		Set tStream = ##class(%Stream.TmpCharacter).%New()
		Do aet.%ToJSON(.tStream)
		Set tSC = tStream.OutputToDevice()
		// END MODIFICATION.
	}
	Catch(ex) {
		Write "null"
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}

