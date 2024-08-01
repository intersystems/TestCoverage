Class UnitTest.TestCoverage.Unit.TestCoverageList Extends %UnitTest.TestCase
{

/// helper function to find the samplecovlist.list's path
ClassMethod FindCoverageList(directory As %String = "") As %String
{

  set stmt = ##class(%SQL.Statement).%New()
  set status = stmt.%PrepareClassQuery("%File", "FileSet")
  if $$$ISERR(status) {write "%Prepare failed:" do $SYSTEM.Status.DisplayError(status) quit}  

  set rset = stmt.%Execute(directory) 
  if (rset.%SQLCODE '= 0) {write "%Execute failed:", !, "SQLCODE ", rset.%SQLCODE, ": ", rset.%Message quit}

  while rset.%Next()
  {
    set name = rset.%Get("Name")
    set type = rset.%Get("Type")

    if (type = "F") {
        do ##class(%File).Deconstruct(name, .dirs)
        if (dirs(dirs) = "samplecovlist.list") {
            return name 
        }
     } elseif (type = "D"){
        set retVal = ..FindCoverageList(name)
        if (retVal '= "") {
            return retVal 
        }
    }
  }
  if (rset.%SQLCODE < 0) {write "%Next failed:", !, "SQLCODE ", rset.%SQLCODE, ": ", rset.%Message quit}
  return "" // didn't find it in this directory
}

Method TestGettingCoverageList()
{
    set tFile = ..FindCoverageList(^UnitTestRoot) // finds the samplecovlist.list 
    do ##class(TestCoverage.Manager).GetCoverageTargetsForFile(tFile, .tTargetArray)

    Set CorrectCoverageTargets("CLS", "TestCoverage.Data.CodeSubUnit") = ""
    Set CorrectCoverageTargets("CLS", "TestCoverage.Data.CodeSubUnit.Method") = ""
    Set CorrectCoverageTargets("CLS","TestCoverage.Data.CodeUnit")=""
    Set CorrectCoverageTargets("CLS","TestCoverage.Data.CodeUnitMap")=""
    Set CorrectCoverageTargets("CLS","TestCoverage.Data.Coverage")=""
    Set CorrectCoverageTargets("CLS","TestCoverage.Data.Run")=""
    Set CorrectCoverageTargets("CLS","TestCoverage.Manager")=""
    Set CorrectCoverageTargets("MAC","UnitTest.TestCoverage.Unit.CodeUnit.G1")=""
    Set CorrectCoverageTargets("MAC","UnitTest.TestCoverage.Unit.sampleRoutine")=""
    Do $$$AssertEquals(..CompareArrays(.tTargetArray, .CorrectCoverageTargets, .pMessage), 1, "tTargetarray equals CorrectCoverageTargets")
    Do $$$LogMessage(pMessage)
}

/// Taken from Tim's Developer Community post
/// Returns true if arrays <var>first</var> and <var>second</var> have all the same subscripts and all
/// the same values at those subscripts. <br />
/// If <var>first</var> and <var>second</var> both happen to be either undefined or unsubscripted variables,
/// returns true if they're both undefined or have the same value.<br />
/// <var>pMessage</var> has details of the first difference found, if any.
ClassMethod CompareArrays(ByRef first, ByRef second, Output pMessage) As %Boolean [ ProcedureBlock = 0 ]
{
    New tEqual,tRef1,tRef2,tRef1Data,tRef1Value,tRef2Data,tRef2Value
    
    Set pMessage = ""
    Set tEqual = 1
    Set tRef1 = "first"
    Set tRef2 = "second"
    While (tRef1 '= "") || (tRef2 '= "") {
        #; See if the subscript is the same for both arrays.
        #; If not, one of them has a subscript the other doesn't, and they're not equal.
        If ($Piece(tRef1,"first",2) '= $Piece(tRef2,"second",2)) {
            Set tEqual = 0
            Set pMessage = "Different subscripts encountered by $Query: "_
                $Case(tRef1,"":"<end>",:tRef1)_"; "_$Case(tRef2,"":"<end>",:tRef2)
            Quit
        }
        
        Kill tRef1Value,tRef2Value
        Set tRef1Data = $Data(@tRef1,tRef1Value)
        Set tRef2Data = $Data(@tRef2,tRef2Value)
        #; See if the $Data values are the same for the two.
        #; This is really only useful to detect if one of the arrays is undefined on the first pass;
        #; $Query only returns subscripts with data.
        #; This will catch only one being defined, or one being an array and
        #; ​the other being a regular variable.
        If (tRef1Data '= tRef2Data) {
            Set tEqual = 0
            Set pMessage = "$Data("_tRef1_")="_tRef1Data_"; $Data("_tRef2_")="_tRef2Data
            Quit
        } ElseIf (tRef1Data#2) && (tRef2Data#2) {
            #; See if the value at the subscript is the same for both arrays.
            #; If not, they're not equal.
            If (tRef1Value '= tRef2Value) {
                Set tEqual = 0
                Set pMessage = tRef1_"="_@tRef1_"; "_tRef2_"="_@tRef2
                Quit
            }
        }
        
        Set tRef1 = $Query(@tRef1)
        Set tRef2 = $Query(@tRef2)
    }
    Quit tEqual
}

}
