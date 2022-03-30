Class UnitTest.TestCoverage.Unit.TestComplexity Extends %UnitTest.TestCase
{

Method TestMethodsInThisClass()
{
	#dim tCodeUnit As TestCoverage.Data.CodeUnit
	Set tClass = $classname()
	&sql(delete from TestCoverage_Data.CodeUnit where Name %STARTSWITH :tClass)
	Do $$$AssertTrue(SQLCODE>=0)
	Do $$$AssertStatusOK($System.OBJ.Compile($classname(),"ck-d"))
	Do $$$AssertStatusOK(##class(TestCoverage.Data.CodeUnit).GetCurrentByName(tClass_".1.INT"))
	If $$$AssertStatusOK(##class(TestCoverage.Data.CodeUnit).GetCurrentByName(tClass_".CLS",,.tCodeUnit)) {
		Set tKey = ""
		For {
			#dim tMethod As TestCoverage.Data.CodeSubUnit.Method
			Set tMethod = tCodeUnit.SubUnits.GetNext(.tKey)
			If (tKey = "") {
				Quit
			}
			If 'tMethod.%IsA("TestCoverage.Data.CodeSubUnit.Method") {
				Continue
			}
			Set tDescription = $$$comMemberKeyGet(tClass,$$$cCLASSmethod,tMethod.Name,$$$cMETHdescription)
			Set tExpectedComplexity = $Piece(tDescription," ",2)
			If (tExpectedComplexity = +tExpectedComplexity) {
				Do ..AssertEqualsViaMacro("Complexity("_tMethod.Name_"),"_tExpectedComplexity,tMethod.Complexity,tExpectedComplexity)
			}
		}
	}
}

/// Complexity: 1
Method AVerySimpleMethod()
{
	Quit 42
}

/// Complexity: 2 (1 + If)
Method IfStatementMethod(pSomething As %Boolean = 0)
{
	Set foo = "bar"
	If 'pSomething {
		Set foo = "actually no bar"
	}
	Quit foo
}

/// Complexity: 4 (1 + If + ElseIf + ElseIf)
Method IfElseIfStatementMethod(pSomething As %Boolean = 0)
{
	Set foo = "bar"
	If 'pSomething {
		Set foo = "actually no bar"
	} ElseIf pSomething = "w" {
	} ElseIf pSomething = "x" {
	} Else {
		// do nothing
	}
	Quit foo
}

/// Complexity: 3 (1 + If + &&)
Method IfWithShortCircuitAnd(pSomething As %Boolean = 0)
{
	Set foo = "bar"
	If 'pSomething && 'foo {
		Set foo = "actually no bar"
	}
	Quit foo
}

/// Complexity: 3 (1 + If + ,)
Method IfWithShortCircuitCommaAnd(pSomething As %Boolean = 0)
{
	Set foo = "bar"
	If pSomething,foo {
		Set foo = "actually no bar"
	}
	Quit foo
}

/// Complexity: 3 (1 + If + ||)
Method IfWithShortCircuitOr(pSomething As %Boolean = 0)
{
	Set foo = "bar"
	If '(pSomething || foo) {
		Set foo = "actually no bar"
	}
	Quit foo
}

/// Complexity: 2 (1 + If, non-short circuit operators not counted)
Method IfWithNonShortCircuitOperators(pSomething As %Boolean = 0)
{
	Set foo = "bar"
	If 'pSomething!..IfElseIfStatementMethod()&..ForLoopMethod() {
		Set foo = "actually no bar"
	}
	Quit foo
}

/// Complexity: 2 (1 + While)
Method WhileLoopMethod()
{
	Set foo = ""
	While (foo = "") {
		Set foo = foo_"a"
	}
	Quit foo
}

/// Complexity: 2 (1 + For)
Method ForLoopMethod()
{
	Set foo = ""
	For i=1:1:5 {
		Set foo = foo_"a"
	}
	Return foo
}

/// Complexity: 3 (1 + Throw + Catch)
Method TryThrowCatchMethod()
{
	Set tSC = $$$OK
	Try {
		Throw ##class(%Exception.General).%New("Nope!")
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Complexity: 4 (1 + For + If + Quit)
Method EarlyQuitMethod()
{
	Set tSC = $$$OK
	For i=1:1:5 {
		If (i = 4) {
			Quit
		}
	}
	Quit tSC
}

/// Complexity: 4 (1 + For + If + Return)
Method EarlyReturnMethod()
{
	Set tSC = $$$OK
	For i=1:1:5 {
		If (i = 4) {
			Return tSC
		}
	}
	Quit tSC
}

/// Complexity: 4 (1 + For + If + Continue)
Method ForLoopContinueMethod()
{
	Set tSC = $$$OK
	For i=1:1:5 {
		If (i = 4) {
			Continue
		}
	}
	Quit tSC
}

/// Complexity: 4 (1 + While + If + Continue)
Method WhileLoopContinueMethod()
{
	Set tSC = $$$OK
	While ($Increment(i) < 6) {
		If (i = 4) {
			Continue
		}
	}
	Quit tSC
}

/// Complexity: 4 (1 + For + Continue + :)
Method PostConditionalMethod()
{
	Set tSC = $$$OK
	For i=1:1:5 {
		Continue:i=4
	}
	Quit tSC
}

/// Complexity: 3 (1 + two non-default $Select cases)
Method SelectMethod(pArgument As %String)
{
	Quit $Select(pArgument=2:4,pArgument=3:9,1:1)
}

/// Complexity: 1 (1, with a $Select with only a default case)
Method TrivialSelectMethod(pArgument As %String)
{
	Quit $Select(1:42)
}

/// Complexity: 4 (1 + three non-default $Case cases)
/// Has an extra white space before :1 to make sure that doesn't break it.
Method CaseMethod(pArgument As %String)
{
	Quit $Case(pArgument,2:4,3:9,4:16, :1)
}

/// Complexity: 1 (1, with a $Case with only a default case)
Method TrivialCaseMethod(pArgument As %String)
{
	Quit $Case(pArgument,:42)
}

/// Complexity: 4 (1 + two non-default $Case cases + for)
/// Ensures that the ":" delimiters in the for loop are treated properly
Method FunctionWithAppropriateScope(pArgument As %String)
{
	Set tSC = $$$OK
	Set foo = $Case(pArgument,2:4,3:9,:1)
	For i=1:1:5 {
	}
	Quit tSC
}

/// Complexity: 7 (1 + UCQ)
/// Was 2 on earlier IRIS versions; UCQ adds a bit.
Method MethodWithEmbeddedSQL()
{
	&sql(select top 1 1 into :foo)
	If (foo = 0) {
		Write !,"After embedded SQL"
	}
	Quit foo
}

/// Complexity: 3 (1 + throw + postconditional)
Method MethodWithComplexMacros(pStatus As %Status)
{
	$$$ThrowOnError(pStatus)
}

}

