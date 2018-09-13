Class UnitTest.TestCoverage.Unit.TestIsExecutable Extends %UnitTest.TestCase
{

Method TestTryCatch()
{
	Do ..RunTestOnMethod("TryCatch1")
	Do ..RunTestOnMethod("TryCatch2")
}

Method TestDo()
{
	Do ..RunTestOnMethod("Do1")
	Do ..RunTestOnMethod("Do2")
}

Method RunTestOnMethod(pMethodName As %Dictionary.CacheIdentifier)
{
	Do $$$LogMessage("Testing executable flags for method: "_pMethodName)
	Merge tLines = ^oddDEF($classname(),"m",pMethodName,$$$cMETHimplementation)
	Do ##class(TestCoverage.Utils).GetRoutineLineExecutableFlags(.tLines,.tFlags)
	For tLine=1:1:tLines {
		Set tExecutable = $Extract(tLines(tLine),*)
		Set tRealLine = $Replace($ZStrip($Extract(tLines(tLine),1,*-2),">W"),$c(9),"  ")
		Set tMsg = "Line "_$Select(tExecutable:"was",1:"NOT")_" executable: "_tRealLine
		Do $$$AssertEquals($Get(tFlags(tLine)),tExecutable,tMsg)
	}
}

ClassMethod TryCatch1()
{
	Try {						;0
		Set foo = "Bar"			;1
	} Catch e {					;1
		Write e.AsStatus()		;1
	}							;0
}

ClassMethod TryCatch2()
{
	Try {						;0
		Set foo = "Bar"			;1
	}							;1
	Catch e {					;0
		Write e.AsStatus()		;1
	}							;0
}

ClassMethod Do1()
{
	Do {						;0
		Set foo = "Bar"			;1
		Do ..TryCatch1()		;1
	} While 0					;1
}

ClassMethod Do2()
{
	Do							;0
	{							;0
		Set foo = "Bar"			;1
		Do ..TryCatch1()		;1
	}							;0
	While 0						;1
}

}

