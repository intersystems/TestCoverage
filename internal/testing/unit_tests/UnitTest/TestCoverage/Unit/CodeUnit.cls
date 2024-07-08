Class UnitTest.TestCoverage.Unit.CodeUnit Extends %UnitTest.TestCase
{

Method TestCodeUnitCreation()
{
	Set tSC = $$$OK
	Try {
		Set tResult = ##class(%SQL.Statement).%ExecDirect(,
			"delete from TestCoverage_Data.CodeUnit where Name %STARTSWITH ?",$classname())
		If (tResult.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
		}

		Do $$$AssertStatusOK($System.OBJ.Compile($classname(),"ck-d"))
		
		#dim tCodeUnit As TestCoverage.Data.CodeUnit
		Set tClsName = $classname()_".CLS"
		Set tIntName = $classname()_".1.INT"
		Set tPyName = $classname()_".PY"
		Set tSC = ##class(TestCoverage.Data.CodeUnit).GetCurrentByName(tIntName,$Namespace,.tIntCodeUnit)
		Do $$$AssertStatusOK(tSC,"Found test coverage data for "_tIntName)
		Do $$$AssertEquals(tIntCodeUnit.Name,$classname()_".1")
		Do $$$AssertEquals(tIntCodeUnit.Type,"INT")
		
		Set tGenIntName = $classname()_".G1.INT"
		Set tSC = ##class(TestCoverage.Data.CodeUnit).GetCurrentByName(tGenIntName,$Namespace,.tGenCodeUnit)
		Do $$$AssertStatusOK(tSC,"Found test coverage data for "_tGenIntName)
		Do $$$AssertEquals(tGenCodeUnit.Name,$classname()_".G1")
		Do $$$AssertEquals(tGenCodeUnit.Type,"INT")
		
		
		Set tSC = ##class(TestCoverage.Data.CodeUnit).GetCurrentByName(tClsName,$Namespace,.tClsCodeUnit)
		Do $$$AssertStatusOK(tSC,"Found test coverage data for "_tClsName)
		Do $$$AssertEquals(tClsCodeUnit.Name,$classname())
		Do $$$AssertEquals(tClsCodeUnit.Type,"CLS")
		
		Set tSC = ##class(TestCoverage.Data.CodeUnit).GetCurrentByName(tPyName,$Namespace,.tPyCodeUnit)
		Do $$$AssertStatusOK(tSC,"Found test coverage data for "_tPyName)
		Do $$$AssertEquals(tPyCodeUnit.Name,$classname())
		Do $$$AssertEquals(tPyCodeUnit.Type,"PY")

		Set tSC = tClsCodeUnit.UpdatePyExecutableLines($classname(),.tPyCodeUnit)
		Do $$$AssertStatusOK(tSC,"Found updated executable line data for "_tClsName)

		Set tConstantReturnValueLine = tClsCodeUnit.MethodMap.GetAt("SampleConstantReturnValue")
		Set tCodeGeneratorLine = tClsCodeUnit.MethodMap.GetAt("SampleCodeGenerator")
		Set tNormalMethodLine = tClsCodeUnit.MethodMap.GetAt("SampleNormalMethod")
		Set tPythonMethodLine = tClsCodeUnit.MethodMap.GetAt("SamplePythonMethod")
		
		Do $$$AssertNotEquals(tConstantReturnValueLine,"")
		Do $$$AssertNotEquals(tCodeGeneratorLine,"")
		Do $$$AssertNotEquals(tNormalMethodLine,"")
		Do $$$AssertNotEquals(tPythonMethodLine,"")
		
		// tTestLines(line number) = $ListBuild(description, executable (default 1), mapped (default 1), mapped from hash (if relevant), mapped from line (if relevant))
		Set tTestLines(tConstantReturnValueLine+2) = $ListBuild("SampleConstantReturnValue+1",0,0)
		Set tTestLines(tCodeGeneratorLine+2) = $ListBuild("SampleCodeGenerator+1",,,tGenCodeUnit.Hash,tGenCodeUnit.MethodMap.GetAt("SampleCodeGenerator")+1, "INT")
		Set tTestLines(tCodeGeneratorLine+3) = $ListBuild("SampleCodeGenerator+2",,,tGenCodeUnit.Hash,tGenCodeUnit.MethodMap.GetAt("SampleCodeGenerator")+2, "INT")
		Set tTestLines(tCodeGeneratorLine+4) = $ListBuild("SampleCodeGenerator+3",,,tGenCodeUnit.Hash,tGenCodeUnit.MethodMap.GetAt("SampleCodeGenerator")+3, "INT")
		Set methodLabel = $Select($System.Version.GetMajor()<2023:"z",1:"")_"SampleNormalMethod"
		Set tTestLines(tNormalMethodLine+2) = $ListBuild("SampleNormalMethod+1",,,tIntCodeUnit.Hash,tIntCodeUnit.MethodMap.GetAt(methodLabel)+1, "INT")
		Set tTestLines(tNormalMethodLine+3) = $ListBuild("SampleNormalMethod+2",,,tIntCodeUnit.Hash,tIntCodeUnit.MethodMap.GetAt(methodLabel)+2, "INT")
		Set tTestLines(tPythonMethodLine+2) = $ListBuild("SamplePythonMethod+1",,,tPyCodeUnit.Hash,tPyCodeUnit.MethodMap.GetAt("SamplePythonMethod")+1, "PY")
		Set tTestLines(tPythonMethodLine+3) = $ListBuild("SamplePythonMethod+2",,,tPyCodeUnit.Hash,tPyCodeUnit.MethodMap.GetAt("SamplePythonMethod")+2, "PY")
		Set tLine = ""
		For {
			Set tLine = $Order(tTestLines(tLine),1,tInfo)
			If (tLine = "") {
				Quit
			}
			
			// Overwrite with defined values, leave defaults in AssertLineHandledCorrectly for undefined values (passing byref)
			Kill tDescription, tExecutable, tMapped, tExpectedFromHash, tExpectedFromLine, tType
			Set $ListBuild(tDescription, tExecutable, tMapped, tExpectedFromHash, tExpectedFromLine, tType) = tInfo
			Do ..AssertLineHandledCorrectly(tClsCodeUnit, tLine, .tDescription, .tExecutable, .tMapped, .tExpectedFromHash, .tExpectedFromLine, .tType)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Do $$$AssertStatusOK(tSC,"No unexpected errors occurred.")
}

Method AssertLineHandledCorrectly(pClassCodeUnit As TestCoverage.Data.CodeUnit, pLine As %Integer, pDescription As %String = {"Line "_pLine}, pExecutable As %Boolean = 1, pMapped As %Boolean = 1, pExpectedFromHash As %String = "", pExpectedFromLine As %Integer = "", pType As %String = "INT") As %Boolean
{
	Set tAllGood = 1
	If pExecutable {
		Set tAllGood = $$$AssertTrue($Bit(pClassCodeUnit.ExecutableLines,pLine),"Line is executable: "_pDescription) && tAllGood
	} Else {
		Set tAllGood = $$$AssertNotTrue($Bit(pClassCodeUnit.ExecutableLines,pLine),"Line is not executable: "_pDescription) && tAllGood
	}
	
	&sql(select count(*),FromHash,FromLine into :tCount,:tFromHash,:tFromLine
		from TestCoverage_Data.CodeUnitMap
		where ToHash = :pClassCodeUnit.Hash and ToLine = :pLine and FromHash->Type = :pType)
	If (SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
	}
	Set tAllGood = $$$AssertTrue(tCount>=pMapped,"Line is "_$Select(pMapped:"",1:"not ")_"mapped: "_pDescription) && tAllGood
	Set tAllGood = $$$AssertNotTrue(tCount>1,"Only one line is mapped to "_pDescription) && tAllGood
	If (pExpectedFromHash '= "") {
		Set tAllGood = $$$AssertEquals($Get(tFromHash),pExpectedFromHash,pDescription_" mapped from expected routine.") && tAllGood
		Set tAllGood = $$$AssertEquals($Get(tFromLine),pExpectedFromLine,pDescription_" mapped from expected line.") && tAllGood
	}
	Quit tAllGood
}

ClassMethod SampleConstantReturnValue()
{
	Quit 42
}

ClassMethod SampleCodeGenerator() [ CodeMode = objectgenerator ]
{
	Do %code.WriteLine(" Set x = $classname() //SampleCodeGenerator")
	Do %code.WriteLine(" Quit "_$$$QUOTE($zdt($h,3)))
	Quit $$$OK
}

ClassMethod AnotherSampleCodeGenerator() [ CodeMode = objectgenerator ]
{
	Do %code.WriteLine(" Set x = $classname() //AnotherSampleCodeGenerator")
	Do %code.WriteLine(" Quit "_$$$QUOTE($zdt($h,3)))
	Quit $$$OK
}

ClassMethod TheThirdSampleCodeGenerator() [ CodeMode = objectgenerator ]
{
	Do %code.WriteLine(" Set x = $classname() //TheThirdSampleCodeGenerator")
	Do %code.WriteLine(" Quit "_$$$QUOTE($zdt($h,3)))
	Quit $$$OK
}

ClassMethod SampleNormalMethod()
{
	Set y = $classname()
	Quit y
}

ClassMethod SamplePythonMethod() [ Language = python ]
{
	import iris
	return 50
}

}
