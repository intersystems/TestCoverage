Class TestCoverage.UI.Utils
{

Query ColoredText(pTestIndex As %String, pCodeUnit As %String, pTestPath As %String = "") As %Query(ROWSPEC = "PlainText:%String,ColoredHTML:%String,Covered:%Boolean,Executable:%Boolean,RawLine:%String") [ SqlProc ]
{
}

ClassMethod ColoredTextExecute(ByRef qHandle As %Binary, pTestIndex As %String, pCodeUnit As %String, pTestPath As %String = "") As %Status
{
	Set tSC = $$$OK
	Try {
		If '##class(TestCoverage.Data.CodeUnit).%ExistsId(pCodeUnit) {
			Set qHandle = ""
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
			Set qHandle($i(qHandle)) = $ListBuild(tText,tText,$Bit(tCoveredLines,tLineNumber),$Bit(tCodeUnit.ExecutableLines,tLineNumber))
		}
		
		// Color the code stream.
		Set tColoredStream = ##class(%GlobalCharacterStream).%New()
		Set tColorer = ##class(%Library.SyntaxColor).%New()
		Set tLanguage = $Case($ZConvert(tCodeUnit.Type,"L"),"cls":"CLS","int":"MAC","inc":"INC",:"COS")
		Set tFlags = "PFE"_$Case(tLanguage,"CLS":"X",:"")
		Set tGood = tColorer.Color(tCodeStream,tColoredStream,tLanguage,tFlags,,,,.tColoringErrors,.tErrorEnv,.tColoringWarnings)
		If tGood {
			// TODO: Something with coloring/environment errors/warnings?
			
			// Extract colored lines (HTML) into qHandle subscripts
			
			// This code ensures that each line contains HTML that is valid in itself; for example, the output may have:
			// <FONT COLOR="#123456">foo<BR>ba<U>r<BR>ba</U>z</FONT>
			
			// This is normalized to three lines with:
			// <FONT COLOR="#123456">foo</FONT>
			// <FONT COLOR="#123456">bar</FONT>
			// <FONT COLOR="#123456">baz</FONT>
			
			// Care is taken to avoid leaving certain common tags (e.g., <U> to denote errors) unmatched on a given line.
			
			For tColoredLineIndex=1:1 {
				Set tColoredLine = tColoredStream.ReadLine(,.tSC)
				Set tOriginalColoredLine = tColoredLine
				$$$ThrowOnError(tSC)
				If (tColoredStream.AtEnd) {
					Quit
				}
				If $Extract(tColoredLine,1,7) = "</FONT>" {
					Set $Extract(tColoredLine,1,7) = ""
				} Else {
					// Extract last font color from previous line and prepend it (if found).
					Merge tPrevLine = qHandle(tColoredLineIndex - 1)
					If $Data(tPrevLine) {
						Set tPrevLine = $ListGet(tPrevLine,2)
						Set tIndex = 0
						Set tSearchIndex = 0
						Set tSearchString = "<FONT COLOR=""#"
						For {
							Set tNextIndex = $Find(tPrevLine,tSearchString,tSearchIndex)
							If tNextIndex = 0 {
								Quit
							}
							Set tSearchIndex = tNextIndex
							If ($Extract(tPrevLine,tSearchIndex+6,tSearchIndex+16) '= """ BGCOLOR=""") {
								// Avoid propagating coloring of errors to the next line (use the previous font from that line instead)
								Set tIndex = tSearchIndex
							}
						}
						If (tIndex '= 0) {
							// Last occurrence of '<FONT COLOR=""#' in previous line
							// (this may have been prepended itself!)
							Set tStartFont = tSearchString_$Extract(tPrevLine,tIndex,$Find(tPrevLine,">",tIndex+1)-1)
							Set tColoredLine = tStartFont_tColoredLine
						}
					}
				}
				
				// Strip all <U> and </U> if unmatched
				If $Length(tColoredLine,"</U>") '= $Length(tColoredLine,"<U>") {
					Set tColoredLine = $Replace(tColoredLine,"<U>","")
					Set tColoredLine = $Replace(tColoredLine,"</U>","")
				}
				
				// Ensure all <FONT> tags on line are closed
				Set tOpenedTags = $Length(tColoredLine,"<FONT")
				Set tClosedTags = $Length(tColoredLine,"</FONT>")
				If (tOpenedTags > tClosedTags) {
					// Add <FONT> as many times as it is missing.
					Set tColoredLine = tColoredLine_$Replace($Justify("",tOpenedTags-tClosedTags)," ","</FONT>")
				}
				
				// Remove line breaks
				Set tColoredLine = $Replace(tColoredLine,"<BR>","")
				Set $List(qHandle(tColoredLineIndex),2) = tColoredLine
				
				// For debugging purposes, also report the original HTML for each line.
				Set $List(qHandle(tColoredLineIndex),5) = tOriginalColoredLine
			}
		}
		
		Set qHandle = ""
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod ColoredTextFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ColoredTextExecute ]
{
	Set qHandle = $Order(qHandle(qHandle),1,Row)
	If (qHandle = "") {
		Set AtEnd = 1
	}
	Quit $$$OK
}

ClassMethod ColoredTextClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = ColoredTextExecute ]
{
	Quit $$$OK
}

}

