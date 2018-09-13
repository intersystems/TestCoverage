Class TestCoverage.Utils.ComplexityParser Extends %RegisteredObject
{

Property CodeStream As %Stream.Object [ Private ];

Property Complexity As %Integer [ InitialExpression = 1, Private ];

Property State [ MultiDimensional, Private ];

Method %OnNew(pStream As %Stream.Object) As %Status [ Private, ServerOnly = 1 ]
{
	Set ..CodeStream = pStream
	Set ..State = 1
	Quit $$$OK
}

/// This method throws exceptions directly.
Method GetComplexity() As %Integer
{
	Set tSC = ##class(%Library.SyntaxColorReader).FromCode(..CodeStream,"COS","A",.tSCReader)
	$$$ThrowOnError(tSC)
	Set tHasNextLine = tSCReader.NextLine(.tNextLineTokenList)
	While tHasNextLine {
		Set tLineTokenList = tNextLineTokenList
		Set tHasNextLine = tSCReader.NextLine(.tNextLineTokenList)
		Do ..ProcessTokenList(.tLineTokenList,'tHasNextLine)
	}
	Quit ..Complexity
}

Method ProcessTokenList(pTokenList As %List, pIsLastLine As %Boolean)
{
	Set tPointer = 0
	While $ListNext(pTokenList,tPointer,tToken) {
		Do ..ProcessToken(tToken, pIsLastLine)
	}
}

Method ProcessToken(pToken As %List, pIsLastLine As %Boolean)
{
	// Ironically, this is a very complex method.
	
	Set tLanguage = $ListGet(pToken,1)
	Set tType = $ListGet(pToken,2)
	Set tText = $ZConvert($ListGet(pToken,3),"L")
	
	// Skip white space.
	If (tType = "White Space") {
		Quit
	}
	
	Set tLastToken = $Get(..State("LastToken"))
	Set ..State("LastToken") = pToken
	
	If (tLanguage '= "COS") {
		// no-op
	} ElseIf (tType = "Operator") {
		// Interested in short-circuit logical operators only (because there is a different code path depending on the value of the first operand).
		If (tText = "||") || (tText = "&&") {
			Set ..Complexity = ..Complexity + 1
			Quit
		}
	} ElseIf (tType = "Command") {
		Set ..Complexity = ..Complexity + $Case(tText,
			"if":1,
			"elseif":1,
			"for":1,
			"while":1,
			"throw":1,
			"catch":1,
			"continue":1,
			"quit":'pIsLastLine,
			"return":'pIsLastLine,
			:0)
		Set ..State(..State,"Command") = tText
	} ElseIf (tType = "Delimiter") {
		If (tText = ":") {
			Set tFunction = $Get(..State(..State,"Function"))
			Set tLastText = $ListGet(tLastToken,3)
			If (tFunction = "$select") && (tLastText '= 1) {
				// Count all but trivial case. (Attempt to figure out if it's the trivial case is a bit lazy.)
				Set ..Complexity = ..Complexity + 1
			} ElseIf (tFunction = "$case") && (tLastText '= ",") {
				// Count all but default case.
				Set ..Complexity = ..Complexity + 1
			} ElseIf ($ListGet(tLastToken,2) = "Command") {
				// Postconditional
				Set ..Complexity = ..Complexity + 1
			}
		} ElseIf (tText = "(") {
			If ($ListGet(tLastToken,2) '= "Function") {
				Set ..State($Increment(..State)) = ""
			}
		} ElseIf (tText = ")") {
			Kill ..State(..State)
			Set ..State = ..State - 1
		} ElseIf (tText = ",") {
			// See if "," is used with if/elseif as a short-circuit and operator
			// ..State will have been incremented if it is in a method/function call
			Set tCommand = $Get(..State(..State,"Command"))
			If (tCommand = "if") || (tCommand = "elseif") {
				Set ..Complexity = ..Complexity + 1
			}
		}
	} ElseIf (tType = "Function") {
		Set ..State($Increment(..State),"Function") = tText
	}
}

}

