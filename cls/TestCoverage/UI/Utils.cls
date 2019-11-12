Class TestCoverage.UI.Utils
{

Query ColoredText(pTestIndex As %String, pCodeUnit As %String, pTestPath As %String = "") As %Query(ROWSPEC = "PlainText:%String,ColoredHTML:%String,Covered:%Boolean,Executable:%Boolean") [ SqlProc ]
{
}

ClassMethod ColoredTextExecute(ByRef qHandle As %Binary, pTestIndex As %String, pCodeUnit As %String, pTestPath As %String = "") As %Status
{
	// The initial implementation of this class query used a process-private global.
	// It is faster to use local variables, and memory constraints should always be well out-of-reach for these.
	// Passing everything in qHandle also has a significant performance hit on method dispatch.
	#def1arg TempStorage %TempColoredText
	
	// Clean up TempStorage in case another query in the same process failed to.
	Kill $$$TempStorage
	Set qHandle = ""
	Set tSC = $$$OK
	Try {
		If '##class(TestCoverage.Data.CodeUnit).%ExistsId(pCodeUnit) {
			Quit
		}
		
		Set tCodeUnit = ##class(TestCoverage.Data.CodeUnit).%OpenId(pCodeUnit,,.tSC)
		$$$ThrowOnError(tSC)
		
		Set tSQL = "select CoveredLines from TestCoverage_Data.Coverage where Run = ? and Hash = ?"
		Set tArgs($i(tArgs)) = pTestIndex
		Set tArgs($i(tArgs)) = pCodeUnit
		If (pTestPath '= "") {
			Set tSQL = tSQL_" and coverage.TestPath = ?"
			Set tArgs($i(tArgs)) = pTestPath
		}
		Set tResult = ##class(%SQL.Statement).%ExecDirect(,tSQL,tArgs...)
		If (tResult.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE, tResult.%Message)
		}
		
		// Aggregate CoveredLines (bitwise OR)
		Set tCoveredLines = ""
		While tResult.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set tNextCoveredLines = tResult.%Get("CoveredLines")
			Set tCoveredLines = $BitLogic(tCoveredLines|tNextCoveredLines)
		}
		$$$ThrowOnError(tSC)
		
		// Mask by only treating "executable" lines as covered
		Set tCoveredLines = $BitLogic(tCoveredLines&tCodeUnit.ExecutableLines)
		
		// Create code stream and stash line data
		Set tCodeStream = ##class(%GlobalCharacterStream).%New()
		For tLineNumber=1:1:tCodeUnit.Lines.Count() {
			Set tText = tCodeUnit.Lines.GetAt(tLineNumber)
			Do tCodeStream.WriteLine(tText)
			Set $$$TempStorage($Increment($$$TempStorage)) = $ListBuild(tText,tText,$Bit(tCoveredLines,tLineNumber),$Bit(tCodeUnit.ExecutableLines,tLineNumber))
		}
		
		// Color the code stream.
		Set tColoredStream = ##class(%GlobalCharacterStream).%New()
		Set tColorer = ##class(%Library.SyntaxColor).%New()
		Set tLanguage = $Case($ZConvert(tCodeUnit.Type,"L"),"cls":"CLS","int":"MAC","inc":"INC",:"COS")
		Set tFlags = "PFES"_$Case(tLanguage,"CLS":"X",:"")
		Set tGood = tColorer.Color(tCodeStream,tColoredStream,tLanguage,tFlags,,,,.tColoringErrors,.tErrorEnv,.tColoringWarnings)
		If tGood {
			For tLineNumber=1:1 {
				Set tColoredLine = tColoredStream.ReadLine(,.tSC)
				$$$ThrowOnError(tSC)
				If (tColoredStream.AtEnd) {
					Quit
				}
				
				// Sometimes there are random extra lines inserted. Detect these by looking for a colored line length shorter
				// than the non-colored line.
				Set tRawLine = $ListGet($$$TempStorage(tLineNumber))
				If ($Length(tColoredLine) < $Length(tRawLine)) && $Increment(tLineNumber,-1) {
					Continue
				}
				
				// Remove line breaks
				Set tColoredLine = $Replace(tColoredLine,"<BR>","")
				Set $List($$$TempStorage(tLineNumber),2) = tColoredLine
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod ColoredTextFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ColoredTextExecute ]
{
	#def1arg TempStorage %TempColoredText
	Set qHandle = $Order($$$TempStorage(qHandle),1,Row)
	If (qHandle = "") {
		Set AtEnd = 1
	}
	Quit $$$OK
}

ClassMethod ColoredTextClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = ColoredTextExecute ]
{
	#def1arg TempStorage %TempColoredText
	Kill $$$TempStorage
	Kill qHandle
	Quit $$$OK
}

}

