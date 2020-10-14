/// Launches tests using any of the following methods:<br><br>
/// <b>RunTest</b>: Runs a set of tests and deletes all test classes afterwards.<br><br> 
/// <b>RunTestSuites</b>: Same as <b>RunTest</b>, but requires 3 arguments, all of which can be null.<br><br>
/// <b>DebugRunTestCase</b>: Can be used after <b>DebugLoadTestSuite</b>.  It runs tests and does not delete the test classes afterwards, like <b>RunTest</b> does.<br><br> 
/// 
/// Setup: Set the global variable <b>^UnitTestRoot</b> to a root directory that contains your test suites.  
/// This must point to a valid directory.  Example: <b>Set ^UnitTestRoot="C:\MyUnittests"</b> (adding a final slash is optional).<br><br>
/// 
/// Specifically, the <b>RunTest</b> method does the following:<br>
/// <ol type=1>
/// <li>Loads and compiles any test files in the directory specified by the first argument, <i>testspec</i>.
/// If the loadxml qualifier is on, all <b>.xml</b> or <b>.XML</b> files will be loaded.<br>
/// If the loadudl qualifier is on, all udl files will be loaded.
/// <br><br>
/// <li>For each class that is a subclass of <b>%UnitTest.TestCase</b>, <b>RunTest</b><br><br>
/// <ol type=A>
/// <li>Runs the <b>OnBeforeAllTests()</b> method<br><br>
/// <li>For each method named <b>Test*</b>, such as <b>TestXyz</b>, <b>RunTest</b><br><br>
/// <ol type=i>
/// <li>Runs the method <b>OnBeforeOneTest()</b> <br>
/// <li>Runs the method <b>TestXyz()</b><br>
/// <li>Runs the method <b>OnAfterOneTest()</b> <br><br>
/// </ol>
/// <li>Repeats steps i through iii for all the other methods named <b>Test*</b><br><br>
/// <li>Runs <b>OnAfterAllTests()</b> method<br><br>
/// </ol>
/// <li>Repeats steps A through D for each class that is a subclass of <b>%UnitTest.TestCase</b>.<br><br>
/// <li>Deletes all the classes loaded during execution.<br><br>
/// <li>Repeats step 1 through 4 recursively (for all sub-directories) through the specified directory (assuming that the /<b>recursive</b> qualifier is on and skipping any directory whose name begins with an underscore).<br>
/// </ol>
/// The loading, running and deletion actions each can be skipped by specifying /noload, /norun and /nodelete qualifiers.<br>
/// Unit test logs testcase output to the global <b>^UnitTest.Result.</b> Results displayed on CSP pages come from this global.<br><br>
/// Note: This reference material draws from the article <b>Unit Testing in Cache</b></a> by Ramon Jimenez.
Class TestCoverage.ManagerBase Extends %RegisteredObject [ System = 3 ]
{

Property LogIndex;

/// Set to true if the <b>/debug</b> qualifier is on.
Property Debug;

/// Set to true if the <b>/display=all</b> qualifier is set.
Property Display;

/// Set to true if unexpected public variables should trigger an error.
Property ReportVariableLeaks;

/// Set to true if the <b>/loadxml</b> qualifier is set.
Property LoadXML;

/// Set to true if the <b>/loadudl</b> qualifier is set. UDL files are .cls, .mac,
/// .int, .inc, or the upper case extensions.
Property LoadUDL;

/// The directory that contains the current test.
Property CurrentDir;

/// Set by the third argument, <i>userparam</i>, of the <b>RunTest</b> method, if specified.
Property UserParam As %String;

/// Allow users to store additional information, like platform, product version, etc. for each test.
/// This information can be later cross-referenced in the result.
/// This array is populated from the first level subscripts of the <i>userparam</i> argument.
Property UserFields As array Of %String;

/// Private property for internal use only
Property TheStack [ MultiDimensional, Private ];

/// Private property for internal use only
Property TempLogIndex [ Private ];

/// Private property to hold information about this namespace so we can cleanup
Property NSInfo [ Internal, MultiDimensional, Private ];

/// Private property to hold information about the environment we need to reset when exiting
Property Environment [ Internal, MultiDimensional, Private ];

/// Runs classes that extend <b>%UnitTest.TestCase</b> that contain test methods.  Creates a log on each run, stored in <b>^UnitTest.Result</b>.<br> 
/// <dl>
/// <dt><i>testspec</i> 
/// <dd><i>testspec</i> takes the form of <i>testsuite [ :testcase [ :testmethod ] ]</i>. 
/// <br><br><i>testsuite</i> is a directory (and optionally, subdirectories) that contains tests. By default <b>RunTest</b> runs all tests found here recursively. <i>testspec</i> must be a child directory of the directory named by the global <b>^UnitTestRoot</b>.  
///  <b>^UnitTestRoot</b> must specify a valid directory because <b>RunTest</b> checks for its existence before running tests.  If <i>testspec</i> is not specified, then the <b>^UnitTestRoot</b> directory is used.  Any subdirectory whose name begins with an underscore ( _ ) is skipped.
/// <br><br><i>testcase</i> is a class that extends <b>%UnitTest.TestCase</b> (contains tests) in the form <i>package.class</i> and is an optional argument. 
/// <br><br><i>testmethod</i> is a method name and is an optional argument.
/// <br><br><i>testspec</i> can also be an array of testsuite, or if you pass in a global name the global is an array of testsuites. In addition it also supports a comma separated set of values.
/// <br><br>
/// <dt><i>qualifiers</i> 
/// <dd>Any of the following command-line arguments can be combined as a single string, such as <b>/noload/norecursive</b>. All are optional.<br><br>
/// The first four (<b>debug</b>, <b>load</b>, <b>run</b>, and <b>recursive</b>) are negatable Booleans.  They can be turned on with <i>/arg</i> or off by adding <b>no</b> in the front, as <b>/noload</b> or adding <b>=0</b> to the end, as <b>/load=0</b>.<br><br> 
/// 
/// <b>/debug</b>: Run in debug mode, which causes a break if a test fails. Default is <b>/nodebug</b>. <br><br>
/// <b>/load</b>: Load use cases from the specified <i>testspec</i>. Default is <b>/load</b>. If <b>/load</b> and <b>/run</b> are both on, then all loaded classes, routines, and CSP files are deleted after the tests are run. To prevent them from being deleted at the end, load them with <b>DebugLoadTestSuite</b> and run them with <b>DebugRunTestCase</b>.<br><br>
/// <b>/run</b>: Run the test suite.  Use <b>/norun</b> if you only want to load, but not run, a suite into a namespace. Default is <b>/run</b>.<br><br>
/// <b>/recursive</b>: Recurse the specified directory when loading test classes. Default is <b>/recursive</b>.<br><br>
/// <b>/display=all</b>: Display extended information when loading exported test class definitions. <b>/display=none</b> displays limited information. Default is <b>/display=all</b>. <br><br>
/// <b>/autoload</b>: Automatically load sub-directories with the given name when loading test classes.
/// Default is <b>/autoload=_autoload</b>.
/// When this qualifier is set, classes are loaded from the given sub-directory of the current directory and its ancestors.
/// This makes it possible to use a class in multiple test suites without copying it to each of their directories.<br><br>
/// <b>/nodelete</b>: Do not delete loaded classes when the test is complete.<br><br>
/// 
/// <dt><i>userparam</i> 
/// <dd>An arbitrary argument passed in by the caller of the <b>UnitTest</b>.  The top node of this variable becomes the value for the <b>UserParam</b> property of the <b>Manager</b>.
/// The first level subscripts and their values are used to populate the <b>UserFields</b> array.
/// </dl>
/// <br><br>
/// Example of RunTest:<br>
/// <pre>
///  set ^UnitTestRoot = "c:\test"
///  do ##class(TestCoverage.ManagerBase).RunTest("sql\sqlprocs")
///  do ##class(TestCoverage.ManagerBase).RunTest("sql\sqlprocs","/debug/recursive=0")
/// </pre>
/// Note: If any of your code needs to run in the <b>%SYS</b> namespace, <b>zn</b> to the <b>%SYS</b> namespace, run the code, then return to another namespace. 
/// @API.Method
ClassMethod RunTest(testspec As %String, qspec As %String, ByRef userparam) As %Status
{
	Set sc=..RunTestSuites($g(testspec),.qspec,.userparam)
	If $$$ISERR(sc) Do $system.Status.DisplayError(sc)
	Quit sc
}

/// Loads, but does not run tests in the <i>testsuite</i>. You can use <b>DebugLoadTestSuite</b> to load tests and then use <b>DebugRunTestCase</b> to run a test over and over again, without having to reload the tests. If you are a developer, use <b>DebugLoadTestSuite</b> with <b>DebugRunTestCase</b> to load once and then run your test many times as you debug your code. 
ClassMethod DebugLoadTestSuite(testsuite As %String = "", qspec As %String = "") As %Status
{
	Quit ..RunTest(testsuite,"/norecursive"_qspec_"/load/norun/nodelete")
}

/// Runs a test case, but does not load.
/// <i>testsuite</i> and <i>testcase</i> are required.
/// <i>testcase</i> is in the form <i>package.class.</i>
/// <i>testmethod</i> is a method within the class.
/// See <b>DebugLoadTestSuite</b> for use to test code during development.
ClassMethod DebugRunTestCase(testsuite As %String = "", testcase As %String = "", qspec As %String = "", testmethod As %String = "", ByRef userparam) As %Status
{
	Quit ..RunTest(testsuite_":"_testcase_":"_testmethod,"/norecursive"_qspec_"/noload/run/nodelete",.userparam)
}

ClassMethod PurgeLog() As %Status
{
	Quit ..PurgeResult()
}

ClassMethod PurgeResult() As %Status
{
	Lock +^UnitTest.Result
	Kill ^UnitTest.Result
	Lock -^UnitTest.Result
	Quit $$$OK
}

/// Wipe all data from this namespace and all PPG information also. Useful in cleaning a namespace
/// before running unit tests. Never do this on a production system!
ClassMethod WipeNamespace()
{
	If $namespace="%SYS" Write "Not in %SYS namespace",! Quit
	#; Free any locks we have
	Lock
	Set manager=..%New()
	#; Call Cleanup to make sure we do not have any $tlevel etc
	Do manager.Cleanup()
	Set manager.Display="log,error"
	Set manager.NSInfo("$zs")=$zs
	Set manager.NSInfo("gbl","UnitTestRoot")="", manager.NSInfo("gbl","UnitTest.Result")="",manager.NSInfo("gbl","UnitTest.ResultI")=""
	Set sc=manager.CleanNamespace() If $$$ISERR(sc) Do DisplayError^%apiOBJ(sc)
	Write !,"Rebuilding Extent Index...",!
	Set sc=$SYSTEM.OBJ.RebuildExtentIndex()  If $$$ISERR(sc) Do DisplayError^%apiOBJ(sc)
}

/// Same as <b>RunTest</b>, but requires three arguments.  These arguments can be null, as ("","","").
ClassMethod RunTestSuites(testspec As %String, qspec, ByRef userparam) As %Status
{
	Set manager=..%New()
	If manager=$$$NULLOREF Quit %objlasterror
	;
	Set sc=$$$qualifierParseAlterDefault("UnitTest","/keepsource",.qspec,.qstruct) q:$$$ISERR(sc) sc
	;
	Kill ^CacheTemp.UnitState
	Set cleanup=0
	Set manager.Debug=$$$qualifierGetValue(qstruct,"debug")
	Set manager.Display=$s($$$qualifierGetValue(qstruct,"displaylog"):"log",1:"")_","_$s($$$qualifierGetValue(qstruct,"displayerror"):"error",1:"")
	Set manager.ReportVariableLeaks=$Get($$$qualifierGetValue(qstruct,"findleakedvariables"),0)
	Set manager.LoadUDL=$Get($$$qualifierGetValue(qstruct,"loadudl"),0)
	Set manager.LoadXML=$Get($$$qualifierGetValue(qstruct,"loadxml"),1)
	Set manager.UserParam=$g(userparam)
	Set key="" For  Set key=$o(userparam(key)) Quit:key=""  do manager.UserFields.SetAt($g(userparam(key)),key)
	If $Get($$$qualifierGetValue(qstruct,"cleanup"),1),$$$qualifierGetValue(qstruct,"run"),'manager.Debug,$$$qualifierGetValue(qstruct,"delete") {
		Set sc=manager.RecordNamespace() If $$$ISERR(sc) Quit sc
		Set cleanup=1
	}
	;
	Set root=..Root()
	;
	If $get(testspec)'="" {
		If $extract(testspec)="^" {
			Merge testspec=@testspec
		} Else {
			For i=1:1:$length(testspec,",") {
				Set test=$zstrip($piece(testspec,",",i),"<>W")
				Set:test'="" testspec(test)=""
			}
		}
	} ElseIf $data(testspec)\10=0 {
		Set testspec(" ")=""
	}
	If $data(testspec)\10=0 {
		Do manager.PrintLine("Nothing passed in to test or global empty")
		Quit $$$ERROR($$$GeneralError,"Nothing to test")
	}
	;
	Set zhBegin=$zh
	Set suite=""
	Set sc = ..OnBeforeAllTests(manager,root,.qstruct,.userparam)
	If $$$ISERR(sc) {
		Set tDummySuite = $classname()_":OnBeforeAllTests"
		Do manager.LogStateBegin(tDummySuite)
		Do manager.LogStateStatus(sc,tDummySuite)
		Do manager.LogStateEnd(0)
	} Else {
		For {
			Set suite=$order(testspec(suite)) Quit:suite=""
			Kill subdirs
			Set testsuite=$p(suite,":",1)
			Set testsuite=$tr(testsuite,"/.","\\")
			If testsuite=" " Set testsuite=""
			Set dir=..AddSubDirectoryNames(root,testsuite)
			Set sc=$$$OK
			If $$$qualifierGetValue(qstruct,"recursive")=0 {
				If ##class(%File).DirectoryExists(dir)=0 {
					Set sc=$$$ERROR($$$DirectoryNameInvalid,dir)
				} Else {
					Set subdirs(dir)=$lb(dir,testsuite)
				}
			} Else {
			 	Set sc=..GetSubDirectories(root,dir,1,testsuite,.subdirs,.qstruct)
			}
			If $$$ISERR(sc) {
				Do manager.LogStateBegin(testsuite)
				Do manager.LogStateStatus(sc,"Finding directories")
				Set status(" "_testsuite)=""
				Set status=manager.LogStateEnd(0)
				Continue
			}
			;
			Set dir=""
			For {
				Set dir=$o(subdirs(dir)) Quit:dir=""
				#; If we have already run this directory no need to do it again
				If $data(haverun(dir)) Continue
				Set haverun(dir)=""
				Set status=manager.RunOneTestSuite($li(subdirs(dir),1),$li(subdirs(dir),2),suite,.qstruct)
				If status=0 {
					Set status(" "_$tr($li(subdirs(dir),2),"\","/"))=""
				}
			}
			If cleanup {
				Do manager.CleanNamespace()
			}
		}
	}
	
	Set sc = ..OnAfterAllTests(manager,root,.qstruct,.userparam)
	If $$$ISERR(sc) {
		Set tDummySuite = $classname()_":OnAfterAllTests"
		Do manager.LogStateBegin(tDummySuite)
		Do manager.LogStateStatus(sc,tDummySuite)
		Do manager.LogStateEnd(0)
	}
	;
	#; Need to make a list of suites that failed and report these at the end. Is this logged under suite or testsuite from the loop above?
	If $$$qualifierGetValue(qstruct,"run") {
		Do manager.SaveResult($zh-zhBegin,.userparam)
		Set manager.Display="log,error"
		Do manager.PrintURL()
	}
	If $data(status)\10 {
		Do manager.PrintLine("Some tests FAILED in suites:")
		Set status="",list=""
		For {
			Set status=$order(status(status)) Quit:status=""
			Set list=list_$extract(status,2,*)_","
			If $length(list)>10000 {
				Do manager.PrintLine("  "_$extract(list,1,*-1))
				Set list=""
			}
		}
		If list'="" Do manager.PrintLine("  "_$extract(list,1,*-1))
	} Else {
		Do manager.PrintLine("All PASSED")
	}
	;
	Kill ^CacheTemp.UnitState
	Quit $$$OK
}

ClassMethod AddSubDirectoryNames(root As %String, testsuite As %String) As %String [ Private ]
{
	Set dir=root
	For i=1:1:$l(testsuite,"\") Set test=$Piece(testsuite,"\",i),dir=##Class(%File).SubDirectoryName(dir,test)
	set dir=##class(%File).NormalizeDirectory(dir)
	Quit dir
}

ClassMethod LastSubDirectoryName(dir As %String) As %String [ Private ]
{
	Set rs=##class(%ResultSet).%New("%File:ParseDirectory")
	Set sc=rs.Execute(dir)
	If $$$ISERR(sc) Quit sc
	Set lastdir=""
	while rs.Next() {
		Set lastdir=rs.GetData(1)
	}
	Quit lastdir
}

ClassMethod GetSubDirectories(root, topdir As %String, level As %Integer, suite As %String, ByRef subdirs As %String, qspec As %String) As %Status [ Private ]
{
	Set sc=$$$qualifierParse("UnitTest",.qspec,.qstruct) q:$$$ISERR(sc) sc
	Set topdir=##Class(%File).NormalizeDirectory(topdir)
	If ##class(%File).DirectoryExists(topdir)=0 Quit $$$ERROR($$$DirectoryNameInvalid,topdir)
	;
	Set rs=##class(%ResultSet).%New("%File:FileSet")
	Set fileset="",sep=""
	If $Get($$$qualifierGetValue(qstruct,"loadxml"),1) Set fileset="*.xml;*.XML",sep=";"
	If $Get($$$qualifierGetValue(qstruct,"loadudl"),0) Set fileset=fileset_sep_"*.cls;*.mac;*.int;*.inc;*.CLS;*.MAC;*.INT;*.INC"
	Set sc=rs.Execute(topdir,fileset,"")
	If $$$ISOK(sc),rs.Next() Set subdirs(topdir)=$lb(topdir,suite)
	Kill rs
	;
	Set rs=##class(%ResultSet).%New("%File:FileSet")
	Set sc=rs.Execute(topdir,"*.*","",1)
	If $$$ISERR(sc) Quit sc
	;
	While rs.Next() {
		If rs.Data("Type")'="D" Continue
		set dir=##Class(%File).NormalizeDirectory(rs.Data("Name"))
		Set lastsub=..LastSubDirectoryName(dir)
		If lastsub="."||(lastsub="..")||($extract(lastsub)="_") Continue  ; skip any subdirectory start with "_"
		Set newsuite=$select(suite="":"",1:suite_"\")_lastsub
		Set sc=..GetSubDirectories(root,dir,level+1,newsuite,.subdirs,.qstruct)
		If $$$ISERR(sc) Quit
	}
	Quit sc
}

Method RunOneTestSuite(dir As %String, suite As %String, testspec As %String, qstruct)
{
	Do $zu(115,5,0) // reset runtime mode between each test
	Set ..CurrentDir=##Class(%Library.File).NormalizeDirectory(dir)
	Set testcase=$p(testspec,":",2)
	Set testmethod=$p(testspec,":",3)
	Do ..PrintLine("===============================================================================",0)
	Do ..PrintLine("Directory: "_dir,0)
	Do ..PrintLine("===============================================================================",0)
	;
	Set zhsBegin=$zh
	Do ..LogStateBegin(suite)
	Set ^CacheTemp.UnitState=$lb(dir)
	; Check internal ISC naming conventions if ^ISC.CheckUnitNames is true
	If $g(^ISC.CheckUnitNames),$$$qualifierGetValue(qstruct,"load") {
		Do ..CheckNameStructure(dir)
	}
	;
	Set flags="c/nodisplay"
	If ..Display["log" Set flags=flags_"/display=log"
	If ..Display["error" Set flags=flags_"/display=error"
	If $$$qualifierAmend("Compiler",.qstruct,flags,.qstructLoad)
	Set sc=$$$OK
	;
	Set fileset="",sep=""
	If ..LoadXML Set fileset="*.xml;*.XML",sep=";"
	If ..LoadUDL Set fileset=fileset_sep_"*.cls;*.mac;*.int;*.inc;*.CLS;*.MAC;*.INT;*.INC"
	;
	Set sc = ..OnBeforeAutoLoad(dir, suite, testspec, .qstruct)
	If $$$ISERR(sc) Do ..LogStateStatus(sc,$classname()_":OnBeforeAutoLoad") Goto exit
	If $$$qualifierGetValue(qstruct,"load") {
		If $$$qualifierGetValue(qstruct,"autoload")]"" {
			Set sc=..AutoLoad(..CurrentDir,$$$qualifierGetValue(qstruct,"autoload"),.autoloadArray,.qstructLoad)
			If $$$ISERR(sc) Do ..LogStateStatus(sc,"$system.OBJ.ImportDir") Goto exit
		}
		Set sc=$system.OBJ.ImportDir(dir,fileset,.qstructLoad,,0,.classLoaded,0)
	} Else {
		If testcase="" {
			Set sc=$system.OBJ.ImportDir(dir,fileset,.qstructLoad,,0,.classLoaded,1)
		} Else {
			Set classLoaded(testcase_".cls")=""
		}
	}
	If $$$ISERR(sc) Do ..LogStateStatus(sc,"$system.OBJ.ImportDir") Goto exit
	;
	Set key="" For {
		Set key=$o(classLoaded(key)) Quit:key=""
		If ($p(key,".",*)="cls") Set classArray($p(key,".",1,*-1))=""
	}
	;
	If $d(classArray)=0 Do ..PrintLine("No classes found for testsuite "_suite,1) Goto exit
	If testcase'="" {
		If $d(classArray(testcase))=0 {
			Do ..LogStateStatus($$$ERROR($$$GeneralError,"TestCase '"_testcase_"' does not exist in TestSuite"),"RunOneTest")
		} ElseIf $$$comClassDefined(testcase)=0 {
			Do ..LogStateStatus($$$ERROR($$$CompiledClassDoesNotExist,testcase),"RunOneTest")
		}
	}
	;
	Set sc=..OnBeforeTestSuite(dir, suite, testspec, .qstruct)
	If $$$ISERR(sc) Do ..LogStateStatus(sc,$classname()_":OnBeforeTestSuite") Goto exit
	If $$$qualifierGetValue(qstruct,"run")=0 {
		Do ..PrintLine("Skipping running testsuite "_suite,1)
	} Else {
		#If $$$comMemberDefined("%SYSTEM.Context.SQL",$$$cCLASSmethod,"ClearStats")
		#; Clear SQL stats
		Do $system.Context.SQL().ClearStats()
		#EndIf
		Set class="" For {
			Set class=$o(classArray(class)) Quit:class=""
			If testcase'="",class'=testcase Continue
			If $system.CLS.IsMthd(class,"%Extends") && $classmethod(class,"%Extends","%UnitTest.TestCase") && '$$$comClassKeyGet(class,$$$cCLASSabstract) {
				Do ..RunOneTestCase(suite,class,testmethod)
			}
		}
	}
	;
	Set ^CacheTemp.UnitState=$lb(dir)
	Set sc=$$$OK
	
	If $$$qualifierGetValue(qstruct,"delete")=0 {
		Do ..PrintLine("Skipping deleting classes ",1)
	} Else {
		Merge classLoaded=autoloadArray
		Set key="" For {
			Set key=$order(classLoaded(key)) Quit:key=""
			If $piece(key,".",*)'="cls" Continue
			s class=$piece(key,".",1,*-1)
			; Invoke the %DeleteExtent method now...
			If $system.CLS.IsMthd(class,"%DeleteExtent") {
				If $parameter(class,"CONNECTION")'="",($$$EXTtype($$$pEXT,class)="%Library.CacheSQLStorage") Continue  // Class is linked, won't delete extent.
				Try {
					Set sc2=$classmethod(class,"%DeleteExtent")
				} Catch exception {
					Set sc2=exception.AsStatus()
				}
				If $$$ISOK(sc2) {
					Set sc2=##class(%ExtentMgr.Util).DeleteExtentDefinitionIfExists(class)
				}
				If $$$ISERR(sc2) {
					Do ..PrintLine("Could not delete extent of "_class)
				}
			}
		}
		Set key="" For {
			Set key=$order(classLoaded(key)) Quit:key=""
			Set ext=$zconvert($piece(key,".",*),"U")
			If ext="CLS" {
				Set sc=$$Delete^%apiOBJ(key,"-d",,1)
			} ElseIf $$IsCSPName^%occXMLExport(key) {
				Set sc=##class(%RoutineMgr).Delete(key)
			} ElseIf $lf($lb("MAC","INT","INC","OBJ","BAS"),ext) {
				Set sc=##class(%Routine).Delete(key,,1)
			} Else {
				Continue
			}
			If $$$ISERR(sc) {
				Do ..PrintLine("Could not delete "_key)
			}
		}
	}
	;
exit
	Set sc=..OnAfterTestSuite(dir, suite, testspec, .qstruct)
	If $$$ISERR(sc) Do ..LogStateStatus(sc,$classname()_":OnAfterTestSuite")
	Set status=..LogStateEnd($zh-zhsBegin)
	Do ..PrintLine("",0)
	Set ..CurrentDir=""
	;
	Quit status
}

Method RunOneTestCase(suite As %String, class As %String, test As %String = "")
{
	New
	New $namespace Set zhcDuration=0
	Set zhcBegin=$zh
	Do ..LogStateBegin(suite,class)
	Set testcase=$classmethod(class,"%New",$this)
	Set testcase.Debug=..Debug,debug=..Debug
	#; For test development: set CurrentDir based on ^UnitTestRoot and package name so it will be correct even in the context of DebugRunTestCase()
	If ""=..CurrentDir {
		Set root=..Root()
		Set tCurrentDir=..AddSubDirectoryNames(root,$G(suite)_"\")
		If ##class(%File).DirectoryExists(tCurrentDir) {
			Set ..CurrentDir=tCurrentDir
			Do ..PrintLine("Setting CurrentDir = '"_tCurrentDir_"'",2)
		} Else {
			Do ..PrintLine("Not Setting Manager.CurrentDir; Directory '"_tCurrentDir_"' does not exist",2)
		}
	}
	Set ^CacheTemp.UnitState=$lb(suite,class)
	Set sc=..Record(.state) If $$$ISERR(sc) Do ..LogStateStatus(sc,"Record") Goto exit
	Set sc=..OnBeforeTestCase(suite, class)
	If $$$ISERR(sc) Do ..LogStateStatus(sc,$classname()_":OnBeforeTestCase") Goto exit
	If debug {
		Set sc=testcase.OnBeforeAllTests()
	} Else {
		Try {
			Set sc=testcase.OnBeforeAllTests()
		} Catch exception {
			Set sc=exception.AsStatus()
		}
	}
	If $$$ISERR(sc) {
		Do ..LogStateStatus(sc,"OnBeforeAllTests")
		Goto exit
	}
	set tFoundMethod=0
	Set method="Tess" ; One before 'Test' which we are searching for
	For {
		Set method=$$$comMemberNext(class,$$$cCLASSmethod,method) Quit:method=""
		If $extract(method,1,4)]"Test" Quit
		If test'=""&&(method'=test) Continue
		If '$system.CLS.IsMthd(class,method) Continue
		Set ^CacheTemp.UnitState=$lb(suite,class,method)
		set tFoundMethod=1
		Do ..LogStateBegin(suite,class,method)
		Set success=0,zhmDuration=0
		If ..ReportVariableLeaks Do ..GetCurrentPublicVariableSet(.preTestVars)
		Set sc=..OnBeforeOneTest(suite, class, method)
		If $$$ISERR(sc) {
			Do ..LogStateStatus(sc,$classname()_":OnBeforeOneTest")
		} Else {
			If debug {
				Set sc=testcase.OnBeforeOneTest(method)
			} Else {
				Try {
					Set sc=testcase.OnBeforeOneTest(method)
				} Catch exception {
					Set sc=exception.AsStatus()
				}
			}
			If $$$ISERR(sc) || (testcase.SkipTest) {
				Do ..LogStateStatus(sc,"OnBeforeOneTest")
			} Else {
				Set zhmBegin=$zh,sc=$$$OK
				If debug {
					Do $method(testcase,method)
				} Else {
					Try {
						Do $method(testcase,method)
					} Catch exception {
						Set sc=exception.AsStatus()
					}
				}
				Set zhmDuration=$zh-zhmBegin
				If $$$ISERR(sc) {
					Do ..LogStateStatus(sc,method)
				} Else {
					Do ..LogMessage("Duration of execution: "_zhmDuration_" sec.")
				}
				If debug {
					Set sc=testcase.OnAfterOneTest(method)
				} Else {
					Try {
						Set sc=testcase.OnAfterOneTest(method)
					} Catch exception {
						Set sc=exception.AsStatus()
					}
				}
				If $$$ISERR(sc) Do ..LogStateStatus(sc,"OnAfterOneTest")
			}
		}
		Set sc=..OnAfterOneTest(suite, class, method)
		If $$$ISERR(sc) Do ..LogStateStatus(sc,$classname()_":OnAfterOneTest")
		Set testcase.SkipTest = 0
		Do ..LogStateEnd(zhmDuration)
		If ..ReportVariableLeaks {
			Do ..GetCurrentPublicVariableSet(.postTestVars)
			Do ..ValidateVariables(.preTestVars, .postTestVars)
		}
	}
	Set ^CacheTemp.UnitState=$lb(suite,class)
	If tFoundMethod=0,test'="" {
		Do ..LogStateStatus($$$ERROR($$$GeneralError,"TestMethod '"_test_"' does not exist in TestCase '"_class_"'."),"RunOneTestCase")
	}
	If debug {
		Set sc=testcase.OnAfterAllTests()
	} Else {
		Try {
			Set sc=testcase.OnAfterAllTests()
		} Catch exception {
			Set sc=exception.AsStatus()
		}
	}
	If $$$ISERR(sc) Do ..LogStateStatus(sc,"OnAfterAllTests")
exit
	Set sc=..OnAfterTestCase(suite, class)
	If $$$ISERR(sc) Do ..LogStateStatus(sc,$classname()_":OnAfterTestCase")
	Set zhcDuration=$zh-zhcBegin
	Set sc=..Cleanup(.state,1) If $$$ISERR(sc) Do ..LogStateStatus(sc,"Cleanup")
	Do ..LogStateEnd(zhcDuration)
}

ClassMethod GetCurrentPublicVariableSet(ByRef GetCurrentPublicVariableSetset) [ Internal, Private ]
{
	Kill GetCurrentPublicVariableSetset
	Set %="%"
	For  {
		Set % = $ORDER(@%) QUIT:%=""
		If $L(%, "GetCurrentPublicVariableSet") = 1 Set GetCurrentPublicVariableSetset(%) = ""
	}
}

ClassMethod SubtractVariableSet(ByRef c, ByRef a, ByRef b) [ Internal, Private ]
{
	Kill c
	Merge c = a
	Set var = ""
	For  {
		Set var = $o(b(var)) QUIT:var=""
		Kill c(var)
	}
}

Method ValidateVariables(ByRef preTestVars, ByRef postTestVars) [ Internal, Private ]
{
	Do ..SubtractVariableSet(.newVars, .postTestVars, .preTestVars)
	Set var = ""
	For  {
		Set var = $O(newVars(var)) QUIT:var=""
		If ..IsAllowedPublicVariable(var) CONTINUE
		Set qval = $$Quote^%qcr($g(@var))
		Do ..LogStateStatus($$$ERROR($$$GeneralError,"Unexpected new public variable introduced: " _ var _ ". $d("_var_") = " _ $d(@var) _ " $g("_var_") = " _ $e(qval,1,256) _ $select($l(qval) > 256:"...",1:"")),"RunOneTestCase")
	}
}

ClassMethod IsAllowedPublicVariable(var) [ Internal, Private ]
{
	RETURN:var="%SAX" 1
	RETURN:var="%objcn" 1
	RETURN:var="%objlasterror" 1
	RETURN:var="SQLCODE" 1
	RETURN:var="%msg" 1
	RETURN:var="%ROWCOUNT" 1
	RETURN:var="%ROWID" 1
	RETURN:var="%qrc" 1
	RETURN:var="%sqlcontext" 1
	RETURN:$e(var,1,$L("%SQLGateway"))="%SQLGateway" 1
	RETURN:var="%JDBCGateway" 1
	RETURN:var="%objsync" 1
	RETURN 0
}

Method Record(ByRef State As %String) As %Status
{
	Kill State
	#; Check for any locks left by the test in this process
	Set rset=##class(%ResultSet).%New("%SYS.LockQuery:List"),locks=""
	Do rset.Execute("P"_$job)
	While rset.Next() {
		Set lock=rset.Data("LockString")
		If lock'="" Set State("lock",lock)=""
	}
	Quit $$$OK
}

Method Cleanup(ByRef State As %String, kill = 0) As %Status
{
	#; Remove any public variables and close any open objects
	If kill Kill (State)
	Set sc=$$$OK
	If $tlevel {
		Set rc=$$$ERROR($$$GeneralError,"Transaction left open after test: "_$tlevel)
		Set sc=$$$ADDSC(sc,rc)
		While $tlevel { Tcommit }
	}
	If $zu(139) {
		Set rc=$$$ERROR($$$GeneralError,"A test left a transactions suspended")
		Set sc=$$$ADDSC(sc,rc)
		Do $zu(139,0)
	}
	If $$CURRENT^%SYS.NOJRN()'=1 {
		Set rc=$$$ERROR($$$GeneralError,"A test disabled journalling in this process")
		Set sc=$$$ADDSC(sc,rc)
		Do ENABLE^%SYS.NOJRN()
	}
	#; Check for any locks left by the test in this process
	Set rset=##class(%ResultSet).%New("%SYS.LockQuery:List"),locks=""
	Do rset.Execute("P"_$job)
	While rset.Next() {
		Set lock=rset.Data("LockString")
		If $data(State("lock",lock)) Continue
		Set locks=locks_lock_","
		If $length(locks)>512 Set locks=locks_"...," Quit
	}
	If locks'="" {
		Set rc=$$$ERROR($$$GeneralError,"Locks left after unit test run: "_$extract(locks,1,*-1))
		Set sc=$$$ADDSC(sc,rc)
	}
	Set $ECode="",$ZError=""
	Try {
		Do resetProcessState^%SYS.cspServer2()
	} Catch e {
		//Ignore, may not be possible on older versions.
	}
	#; Cleanup any $sortbegin there are active
	Set tmp=$sortend(,0)
	If tmp {
		Set rc=$$$ERROR($$$GeneralError,"Test left $sortbegin open without closing it")
		Set sc=$$$ADDSC(sc,rc)
	}
	#if $System.CLS.IsMthd("%SYS.NLS.Format","UseLocale")
	If ##class(%SYS.NLS.Format).UseLocale() {
		Do ##class(%SYS.NLS.Format).UseLocale(0)
		Set rc=$$$ERROR($$$GeneralError,"Modified 'UseLocale' to 1 and did not restore it after (##class(%SYS.NLS.Format).UseLocale())")
		Set sc=$$$ADDSC(sc,rc)
	}
	#endif
	Quit sc
}

Method SaveResult(duration, ByRef userparam)
{
	If $g(^UnitTest.Result)="" Lock +^UnitTest.Result Set ^UnitTest.Result=$o(^UnitTest.Result(""),-1) Lock -^UnitTest.Result
	Set i%LogIndex=$i(^UnitTest.Result)
	Set userfields="",key="" for  {
		Set value=..UserFields.GetNext(.key) Quit:key=""  Set userfields=userfields_$lb($lb(key,value))
	}
	Set ^UnitTest.Result(i%LogIndex)=$listbuild($zdatetime($H,3),+$g(duration),$zu(110),$p($zu(86),"*",2),$zv,$znspace,..UserParam,userfields)
	Merge ^UnitTest.Result(i%LogIndex)=^||TempLog(i%TempLogIndex)
	; temporarily comment out the building of indices due to large amount of disk usage
	Do ##class(%UnitTest.Result.TestInstance).FileIndicesRecursive(i%LogIndex)
	Do ..OnAfterSaveResult(.userparam)
	Quit
}

Method LogStateBegin(testsuite, testcase, testmethod)
{
	If $g(testsuite)="" Set testsuite="(root)"
	Set i%TheStack=$g(i%TheStack)+1
	Set i%TheStack(i%TheStack,"suite")=$g(testsuite)
	Set i%TheStack(i%TheStack,"case")=$g(testcase)
	Set i%TheStack(i%TheStack,"method")=$g(testmethod)
	If $g(testmethod)'="" {
		Set ^||TempLog(i%TempLogIndex,testsuite,testcase,testmethod)=$lb(1)
		Do ..PrintLine(testmethod_"() begins ...",3)
	} Elseif $g(testcase)'="" {
		Set ^||TempLog(i%TempLogIndex,testsuite,testcase)=$lb(1)
		Do ..PrintLine(testcase_" begins ...",2)
	} Else {
		Set ^||TempLog(i%TempLogIndex,testsuite)=$lb(1)
		Do ..PrintLine(testsuite_" begins ...",1)
	}
	Quit
}

/// Record the end of a test and also return the status of this 
Method LogStateEnd(duration) As %Integer
{
	Set suite=i%TheStack(i%TheStack,"suite")
	Set case=i%TheStack(i%TheStack,"case")
	Set method=i%TheStack(i%TheStack,"method")
	Kill i%TheStack(i%TheStack)
	Set i%TheStack=i%TheStack-1
	; status precedence order: failed, skipped, passed
	set sp(0)=3,sp(2)=2,sp(1)=1,sphighest=3
	If method'="" {
	 	Set status=$li(^||TempLog(i%TempLogIndex,suite,case,method),1) Quit:status=sphighest status
	 	Set altered=0,action="" For  Set action=$o(^||TempLog(i%TempLogIndex,suite,case,method,action)) Quit:action=""  Do  Quit:status=sphighest
	 	. Set one=$li(^||TempLog(i%TempLogIndex,suite,case,method,action),1) if sp(one)>sp(status) set status=one,altered=1
	 	If altered Set ^||TempLog(i%TempLogIndex,suite,case,method)=$lb(status,duration,"","There are "_..GetTestState(status)_" TestAsserts")
	 	Else       Set $li(^||TempLog(i%TempLogIndex,suite,case,method),2)=duration
	 	Do ..PrintLine($tr(method,"\","/")_" "_..GetTestState(status),3)
	} Elseif case'="" {
	 	Set status=$li(^||TempLog(i%TempLogIndex,suite,case),1) Quit:status=sphighest status
	 	Set altered=0,method="" For  Set method=$o(^||TempLog(i%TempLogIndex,suite,case,method)) Quit:method=""  Do  Quit:status=sphighest
	 	. Set one=$li(^||TempLog(i%TempLogIndex,suite,case,method),1) if sp(one)>sp(status) set status=one,altered=1
	 	If altered Set ^||TempLog(i%TempLogIndex,suite,case)=$lb(status,duration,"","There are "_..GetTestState(status)_" TestMethods")
		Else       Set $li(^||TempLog(i%TempLogIndex,suite,case),2)=duration
	 	Do ..PrintLine($tr(case,"\","/")_" "_..GetTestState(status),2)
	} Elseif suite'=""{
	 	Set status=$li(^||TempLog(i%TempLogIndex,suite),1) Quit:status=sphighest status
	 	Set altered=0,case="" For  Set case=$o(^||TempLog(i%TempLogIndex,suite,case)) Quit:case=""  Do  Quit:status=sphighest
	 	. Set one=$li(^||TempLog(i%TempLogIndex,suite,case),1) if sp(one)>sp(status) set status=one,altered=1
	 	If altered Set ^||TempLog(i%TempLogIndex,suite)=$lb(status,duration,"","There are "_..GetTestState(status)_" TestCases")
		Else       Set $li(^||TempLog(i%TempLogIndex,suite),2)=duration
	 	Do ..PrintLine($tr(suite,"\","/")_" "_..GetTestState(status),1)
	}
	Quit status
}

ClassMethod GetTestState(level) As %String
{
	quit $s(level=1:"passed",level=2:"skipped",1:"failed")
}

Method LogStateStatus(status, action)
{
	If $$$ISOK(status) Quit
	Do $system.Status.DecomposeStatus(status,.errorarray,"-d") Set errortext=$g(errorarray(1))
	Set testsuite=i%TheStack(i%TheStack,"suite")
	Set testcase=i%TheStack(i%TheStack,"case")
	Set testmethod=i%TheStack(i%TheStack,"method")
	Set message="0:"_action_":"_errortext
	If testmethod'="" {
		Set ^||TempLog(i%TempLogIndex,testsuite,testcase,testmethod)=$lb(0,0,action,errortext)
	} Elseif testcase'="" {
		Set ^||TempLog(i%TempLogIndex,testsuite,testcase)=$lb(0,0,action,errortext)
	} Else {
		Set ^||TempLog(i%TempLogIndex,testsuite)=$lb(0,0,action,errortext)
	}
	If ..Display["error" {
		Do ..PrintErrorLine("LogStateStatus:"_message)
	} Else {
		Do ..PrintLine("LogStateStatus:"_message)
	}
	If '..Debug Quit
	Break  Quit
}

Method LogAssert(success, action, description, extra)
{
	Set testsuite=i%TheStack(i%TheStack,"suite")
	Set testcase=i%TheStack(i%TheStack,"case")
	Set testmethod=i%TheStack(i%TheStack,"method")
	If testmethod="" Quit
	Set next=$o(^||TempLog(i%TempLogIndex,testsuite,testcase,testmethod,""),-1)+1
	Set ^||TempLog(i%TempLogIndex,testsuite,testcase,testmethod,next)=$lb(success,action,description)
	Set line=action_":"_description_" ("_..GetTestState(success)_")"
	If 'success,..Display["error" {
		Do ..PrintErrorLine(line,.extra)
	} Else {
		Do ..PrintLine(line,4)
	}
}

Method LogMessage(message)
{
	Set testsuite=i%TheStack(i%TheStack,"suite")
	Set testcase=i%TheStack(i%TheStack,"case")
	Set testmethod=i%TheStack(i%TheStack,"method")
	If testmethod="" Quit
	Set next=$o(^||TempLog(i%TempLogIndex,testsuite,testcase,testmethod,""),-1)+1
	Set ^||TempLog(i%TempLogIndex,testsuite,testcase,testmethod,next)=$lb(1,"LogMessage",$g(message))
	Do ..PrintLine("LogMessage:"_$g(message),4)
}

Method PrintLine(text, level = 0)
{
	If ..Display'["log" Quit
	Write !
	Write $j("",level*2)
	Write $g(text)
}

Method PrintErrorLine(text, extra)
{
	If ..Display'["error" Quit
	Write !,$get(text),"  <<==== **FAILED**",!
	Write i%TheStack(i%TheStack,"suite"),":"
	Write i%TheStack(i%TheStack,"case"),":"
	Write i%TheStack(i%TheStack,"method"),":"
	If $get(extra)'="" {
		Write !,extra
	}
}

Method PrintURL()
{
	Set s = ##class(%RoutineMgr).GetWebServerPort(.p, .h, .up, .url)
	if $E(url,$L(url))="/" {
		set url=$E(url,1,$L(url)-1)
	}
	If ($$$ISERR(s)) || ($G(url)="") Set url = "http://127.0.0.1:57772"
	set url=url_$$getDefaultApp^%SYS.cspServer2("%SYS")
	Do ..PrintLine("Use the following URL to view the result:")
	Do ..PrintLine(url_"/%25UnitTest.Portal.Indices.cls?Index="_i%LogIndex_"&$NAMESPACE="_$zconvert($namespace,"O","URL"))
	Quit
}

/// This method is obsolete, use method <b>GetTestStatus</b>
Method IsSuccess(suite, case, method, action) As %Boolean
{
	quit ..GetTestStatus(.suite,.case,.method,.action)=1
}

/// Returns result for a given <b>suite, case, method, and action</b>.
Method GetTestStatus(suite, case, method, action) As %Integer
{
	; no need to recurse. LogStateEnd has already scanned and set the correct status
	If $d(action) Quit $li(^||TempLog(i%TempLogIndex,suite,case,method,action),1)
	If $d(method) Quit $li(^||TempLog(i%TempLogIndex,suite,case,method),1)
	If $d(case)   Quit $li(^||TempLog(i%TempLogIndex,suite,case),1)
	If $d(suite)  Quit $li(^||TempLog(i%TempLogIndex,suite),1)
	Quit 0
}

Method %OnNew(initvalue As %CacheString) As %Status [ Private, ProcedureBlock = 1, ServerOnly = 1 ]
{
	Set i%TempLogIndex=$i(^||TempLog)
	#; Record information we will reset when exiting to make sure we are not changing the environment
	Merge i%Environment("sql-sys")=^%SYS("sql","sys")
	#; We will restore this when restoring sql-sys settings in %OnClose
	#If $$$comMemberDefined("%SYSTEM.Context.SQL",$$$cCLASSproperty,"DisableStatCollection")
	Set i%Environment("stat-col")=$system.Context.SQL().DisableStatCollection
	Set $system.Context.SQL().DisableStatCollection=1
	#EndIf
	Set i%Environment("callererrorinfo")=$lb(^%oddENV($$$cENVcallererrorinfo))
	#if $System.CLS.IsMthd("%SYS.NLS.Format","UseLocale")
	Set i%Environment("uselocale")=##class(%SYS.NLS.Format).UseLocale(0)
	#endif
	ZKill ^%oddENV($$$cENVcallererrorinfo)
	Do ..Record(.state)
	Merge i%Environment("lockstate")=state
	Quit $$$OK
}

Method %OnClose() As %Status [ Private, ProcedureBlock = 1, ServerOnly = 1 ]
{
	Kill ^||TempLog(i%TempLogIndex)
	Merge lockstate=i%Environment("lockstate")
	If $ld(i%Environment("callererrorinfo"),1) {
		Set ^%oddENV($$$cENVcallererrorinfo)=$list(i%Environment("callererrorinfo"))
	} Else {
		ZKill ^%oddENV($$$cENVcallererrorinfo)
	}
	#if $System.CLS.IsMthd("%SYS.NLS.Format","UseLocale")
	Do ##class(%SYS.NLS.Format).UseLocale(i%Environment("uselocale"))
	#endif
	#If $$$comMemberDefined("%SYSTEM.Context.SQL",$$$cCLASSproperty,"DisableStatCollection")
	Set $system.Context.SQL().DisableStatCollection=i%Environment("stat-col")
	#EndIf
	Set sc=..Cleanup(.lockstate) If $$$ISERR(sc) Write "ERROR closing ",$classname(),! Do DisplayError^%apiOBJ(sc)
	Merge env=i%Environment("sql-sys")
	#; Look through these values one at a time rather than just doing a kill and merge in case other processes are running at this same time
	Set i=""
	For {
		Set i=$order(env(i)) Quit:i=""
		Set data=$data(env(i),val)
		If data#10=1 {
			If val'=$get(^%SYS("sql","sys",i)) Set ^%SYS("sql","sys",i)=val
		}
		If data\10=1 {
			Set j=""
			For {
				Set j=$order(env(i,j),1,val) Quit:j=""
				If val'=$get(^%SYS("sql","sys",i,j)) Set ^%SYS("sql","sys",i,j)=val
			}
		}
	}
	Set i=""
	For {
		Set i=$order(^%SYS("sql","sys",i)) Quit:i=""
		If '$data(env(i)) Kill ^%SYS("sql","sys",i) Continue
		Set j=""
		For {
			Set j=$order(^%SYS("sql","sys",i,j)) Quit:j=""
			If '$data(env(i,j)) Kill ^%SYS("sql","sys",i,j)
		}
	}
	Quit $$$OK
}

/// Returns the root directory of the unit test hierarchy, usually <b>^UnitTestRoot</b>.
ClassMethod Root() As %String
{
	Set root=##class(%File).NormalizeDirectory($$$envSourceDir)_"internal/testing/unit_tests/"
	Set root=$g(^UnitTestRoot,root)
	Quit ##class(%File).NormalizeDirectory(root)
}

/// For each directory from <method>Root</method> down to <parameter>dir</parameter>, import the contents of sub-directory <parameter>sub</parameter>, 
/// returning classes in <parameter>classArray</parameter>.
/// This method is part of the implementation of the <b>/autoload</b> qualifier.
ClassMethod AutoLoad(dir As %String, sub As %String, ByRef classArray As %String, qstruct As %String) As %Status [ Internal ]
{
	s ret=$$$OK
	s root=..Root(),pwd=dir,prev="",dirlist=""
	s listonly=($$$qualifierGetValue(qstruct,"load")=0)
	; walk up the directory tree looking for /autoload directories
	f  q:prev=root!(pwd=prev)  d
	. s setup=##class(%File).SubDirectoryName(pwd,sub)
	. s:##class(%File).DirectoryExists(setup) dirlist=$lb(setup)_dirlist
	. s prev=pwd,pwd=##class(%File).ParentDirectoryName(pwd)
	; walk back down the directory tree loading /autoload directories
	Set fileset="",sep=""
	If $Get($$$qualifierGetValue(qstruct,"loadxml"),1) Set fileset="*.xml;*.XML",sep=";"
	If $Get($$$qualifierGetValue(qstruct,"loadudl"),0) Set fileset=fileset_sep_"*.cls;*.mac;*.int;*.inc;*.CLS;*.MAC;*.INT;*.INC"
	f i=1:1:$ll(dirlist) d
	. s status=$system.OBJ.ImportDir($lg(dirlist,i),fileset,.qstruct,,1,.classArray,listonly)
	. s:$$$ISOK(ret) ret=status
	q ret
}

/// This method converts old format data in ^UnitTestLog to the new ^UnitTest.Result format.<br>
/// pLogIndex is the test instance index in ^UnitTestLog.<br>
/// pResultNamespace is the namespace for ^UnitTest.Result.<br>
/// pMachine, pConfiguration, pVersion and pUserParam are the new information ^UnitTest.Result collects 
/// but ^UnitTestLog does not. You can provide this information manually here when doing the conversion.<br>
/// pUserParam is used the same way as the userparam argument which is the 3rd argument to the RunTest method. 
/// The top node of pUserParam becomes UserParam and the first level subscripts and their values are used to populate the UserFields array.
ClassMethod ConvertLogData(pLogIndex, pResultNamespace = "", pMachine = "", pConfiguration = "", pVersion = "", pUserParam = "", pKillLog = 0) As %Status
{
	if pResultNamespace="" set pResultNamespace=$znspace
	lock +^|pResultNamespace|UnitTest.Result
	set tResultIndex=$o(^|pResultNamespace|UnitTest.Result(""),-1)+1
	lock -^|pResultNamespace|UnitTest.Result
	;
	write !,"Converting ^UnitTestLog("_pLogIndex_") to ^UnitTest.Result("_tResultIndex_") ... "
	;
	set iduration=0
	set suite="" for  {
		set suite=$o(^UnitTestLog(pLogIndex,suite),1,sdata) quit:suite=""
		set sduration=0
		set case="" for  {
			set case=$o(^UnitTestLog(pLogIndex,suite,case),1,cdata) quit:case=""
			set cduration=0
			set method="" for  {
				set method=$o(^UnitTestLog(pLogIndex,suite,case,method),1,mdata) quit:method=""
				set assert="" for  {
					set assert=$o(^UnitTestLog(pLogIndex,suite,case,method,assert),1,adata) quit:assert=""
					set status=$p(adata,":",1)
					set action=$p(adata,":",2)
					set message=$p(adata,":",3,999)
					set ^|pResultNamespace|UnitTest.Result(tResultIndex,suite,case,method,assert)=$lb(status,action,message)
				}
				set status=$p(mdata,":",1)
				set duration=+$p(adata,"1:LogMessage:Duration of execution: ",2)
				set action=$p($p(mdata,":",2),"()",1)
				set description=$p(mdata,":",3,999)
				set ^|pResultNamespace|UnitTest.Result(tResultIndex,suite,case,method)=$lb(status,duration,action,description)
				set cduration=cduration+duration
			}
			set status=$p(cdata,":",1)
			set action=$p($p(cdata,":",2),"()",1)
			set description=$p(cdata,":",3,999)
			set ^|pResultNamespace|UnitTest.Result(tResultIndex,suite,case)=$lb(status,cduration,action,description)
			set sduration=sduration+cduration
		}
		set status=$p(sdata,":",1)
		set action=$p($p(sdata,":",2),"()",1)
		set description=$p(sdata,":",3,999)
		set ^|pResultNamespace|UnitTest.Result(tResultIndex,suite)=$lb(status,sduration,action,description)
		set iduration=iduration+sduration
	}
	set datetime=$zdatetime(^UnitTestLog(pLogIndex),3)
	set userfieldslist="",key="" for  {
		set key=$o(pUserParam(key)) quit:key=""
		set userfieldslist=userfieldslist_$lb($lb(key,$g(pUserParam(key))))
	}
	set ^|pResultNamespace|UnitTest.Result(tResultIndex)=$lb(datetime,iduration,pMachine,pConfiguration,pVersion,$znspace,$g(pUserParam),userfieldslist)
	if pKillLog kill ^UnitTestLog(pLogIndex)
	;
	do ..ConvertStatus(tResultIndex,pResultNamespace)
	;
	quit $$$OK
}

/// This method updates the status at each level recursively based on the status of the children
/// If pIndex is omitted, all the TestInstances will be converted.
ClassMethod ConvertStatus(pIndex, pNamespace) As %Status
{
	If $g(pNamespace)="" Set pNamespace=$znspace
	If $g(pIndex)="" {
		Set tIndex="" For  {
			Set tIndex=$o(^|pNamespace|UnitTest.Result(tIndex)) Quit:tIndex=""
			Do ..ConvertStatus(tIndex,pNamespace)
		}
	} Else {
		Write !,"Converting Status for TestInstance "_pIndex_" ..."
		Do ..setRecursiveStatus(pNamespace,pIndex)
	}
	Quit $$$OK
}

ClassMethod setRecursiveStatus(pNamespace, pIndex, pSuite, pCase, pMethod) As %Integer
{
	; status precedence order: failed, skipped, passed
	set sp(0)=3,sp(2)=2,sp(1)=1,sphighest=3,status=1
	If $g(pMethod)'="" {
		Set status=$li(^|pNamespace|UnitTest.Result(pIndex,pSuite,pCase,pMethod),1) Quit:status=sphighest status
		Set duration=$li(^|pNamespace|UnitTest.Result(pIndex,pSuite,pCase,pMethod),2)
		Set altered=0,action="" For  {
			Set action=$o(^|pNamespace|UnitTest.Result(pIndex,pSuite,pCase,pMethod,action)) Quit:action=""
			Set one=$li(^|pNamespace|UnitTest.Result(pIndex,pSuite,pCase,pMethod,action),1) if sp(one)>sp(status) set status=one,altered=1
			Quit:status=sphighest
		}
		If altered {
			Set ^|pNamespace|UnitTest.Result(pIndex,pSuite,pCase,pMethod)=$lb(status,duration,"","There are "_..GetTestState(status)_" TestAsserts")
			Write !,"  altered status for ",pIndex,":"_pSuite_":"_pCase_":"_pMethod_" to "_..GetTestState(status)
		}
		Quit status
	} Elseif $g(pCase)'="" {
		Set status=$li(^|pNamespace|UnitTest.Result(pIndex,pSuite,pCase),1) Quit:status=sphighest status
		Set duration=$li(^|pNamespace|UnitTest.Result(pIndex,pSuite,pCase),2)
		Set altered=0,tMethod="" For  {
			Set tMethod=$o(^|pNamespace|UnitTest.Result(pIndex,pSuite,pCase,tMethod)) Quit:tMethod=""
			Set one=..setRecursiveStatus(pNamespace,pIndex,pSuite,pCase,tMethod) if sp(one)>sp(status) set status=one,altered=1
		}
		If altered {
			Set ^|pNamespace|UnitTest.Result(pIndex,pSuite,pCase)=$lb(status,duration,"","There are "_..GetTestState(status)_" TestMethods")
			Write !,"  altered status for ",pIndex,":"_pSuite_":"_pCase_" to "_..GetTestState(status)
		}
		Quit status
	} Elseif $g(pSuite)'="" {
		Set status=$li(^|pNamespace|UnitTest.Result(pIndex,pSuite),1) Quit:status=sphighest status
		Set duration=$li(^|pNamespace|UnitTest.Result(pIndex,pSuite),2)
		Set altered=0,tCase="" For  {
			Set tCase=$o(^|pNamespace|UnitTest.Result(pIndex,pSuite,tCase)) Quit:tCase=""
			Set one=..setRecursiveStatus(pNamespace,pIndex,pSuite,tCase) if sp(one)>sp(status) set status=one,altered=1
		}
		If altered {
			Set ^|pNamespace|UnitTest.Result(pIndex,pSuite)=$lb(status,duration,"","There are "_..GetTestState(status)_" TestCases")
			Write !,"  altered status for ",pIndex,":"_pSuite_" to "_..GetTestState(status)
		}
		Quit status
	} Else {
		Set tSuite="" For  {
			Set tSuite=$o(^|pNamespace|UnitTest.Result(pIndex,tSuite)) Quit:tSuite=""
			Set one=..setRecursiveStatus(pNamespace,pIndex,tSuite) if sp(one)>sp(status) set status=one
		}
		Quit status
	}
	Quit 0
}

/// This method is used internally by Intersystems.
/// It checks unit test file names against internal source control requirements.
/// You should not make direct use of it within your applications.
/// There is no guarantee made about either the behavior or future operation of this method.
Method CheckNameStructure(dir As %String) [ Internal, Private ]
{
	try {
		s basenm=..Root()
		s rs=##class(%ResultSet).%New("%File:FileSet")
		Set fileset="",sep=""
		If ..LoadXML Set fileset="*.xml;*.XML",sep=";"
		If ..LoadUDL Set fileset=fileset_sep_"*.cls;*.CLS"
		s sc=rs.Execute(dir,fileset)
		if $$$ISERR(sc){
			d ..LogStateStatus(sc,"Source Control Naming Convention Check Failed")
			q
		}
		for {
			q:'rs.Next()
			s file=rs.Data("Name")
			//If Emacs-style *.xml~ backup files are present on a Windows system, they are found by the FileSet query.  Skip them here.
			continue:$case($zcvt($e(file,*-3,*),"l"),".xml":0,".cls":0,:1)
			s sc=$system.OBJ.Load(file,"-d",,.elmntlst,1)
			if $$$ISERR(sc) {
				d ..LogStateStatus(sc,"Source Control Naming Convention Check Failed")
				continue
			}
			s elmntcnt=0
			s hasclass=0
			s shortfile=$e(file,$l(basenm)+1,*-4)
			s shortfile=$tr(shortfile,"_\/]","%...")
			//Check to see if the file name corresponds to a syntactically valid class name - if it does, we want it to contain a class.
			s validfilename=$ZNAME(shortfile,4)
			s idx=$o(elmntlst(""))
			for {
				q:idx=""
				s elmntcnt=elmntcnt+1
				//If any of the elements in the file is a class, check that the class name matches the file name.
				if $zcvt($e(idx,*-3,*),"l")=".cls" {
					s hasclass=1
					s clsnm=$e(idx,1,*-4)
					if shortfile'=clsnm {
						s sc=$$$ERROR($$$GeneralError,"Expected "_file_" to contain a class named "_$tr(shortfile,"_","%")_" rather than "_clsnm)
						d ..LogStateStatus(sc,"Source Control Naming Convention Check Failed")
					}
				}
				s idx=$o(elmntlst(idx))
			}
			//Expect that a file with a file name that corresponds to a syntactically correct class name should contain a class.
			if validfilename,'hasclass {
				s sc=$$$ERROR($$$GeneralError,"Expected "_file_" to contain a class element because it corresponds to a valid class name")
				d ..LogStateStatus(sc,"Source Control Naming Convention Check Failed")
			}
			//Expect each file that contains a class to have exactly one element.
			if hasclass,elmntcnt'=1 {
				s sc=$$$ERROR($$$GeneralError,"More than one element, including at least one class, found in "_file)
				d ..LogStateStatus(sc,"Source Control Naming Convention Check Failed")
			}
		}
	}
	catch excpt {
		s sc=excpt.AsStatus()
		d ..LogStateStatus(sc,"Source Control Naming Convention Check Failed")
	}
}

/// Internal method to log list of globals, routines in this namespace so we can cleanup after the tests
Method RecordNamespace() As %Status [ Private ]
{
	New %gbl
	Set rtndb=$$GetGlobalSourceDatabase^%SYS.SECURITY($name(^ROUTINE("DemoRtn")))
	Set datadb=$$GetGlobalSourceDatabase^%SYS.SECURITY($name(^X))
	Set sc=$$GetGlobalDirectoryInfo^%SYS.DATABASE(datadb,$name(%gbl)) If $$$ISERR(sc) Quit sc
	#; Make sure we do not clean up the test results
	Set i%NSInfo("gbl","UnitTest.Result")="",i%NSInfo("gbl","UnitTest.ResultI")="",i%NSInfo("gbl","UnitTestRoot")=""
	#; Also leave the ^ERRORS global
	Set i%NSInfo("gbl","ERRORS")=""
	Set i=""
	For {
		Set i=$order(%gbl(i)) Quit:i=""
		If $data(@("^|"""_datadb_"""|"_i)) {
			Set i%NSInfo("gbl",i)=""
		}
	}
	Set i=""
	For {
		Set i=$order(^oddEXT(i)) Quit:i=""
		Set i%NSInfo("ext",i)=""
	}
	Merge i%NSInfo("rtn")=^|rtndb|rINDEX,i%NSInfo("cls")=^|rtndb|rINDEXCLASS
	Set i%NSInfo("$zs")=$zs
	
	#; Get list of existing PPGs
	#dim rset As %Library.ResultSet
	set rset=##class(%ResultSet).%New()
	set rset.ClassName="%SYS.ProcessQuery"
	set rset.QueryName="PPG"
	set sc=rset.Execute("*",-1,"N")
	if $$$ISERR(sc) Quit sc
	While rset.Next() {
		set ppg=rset.Data("key")
		Set i%NSInfo("ppg",ppg)=""
	}
	Quit $$$OK
}

/// Internal method to clean the namespace after running a suite of tests
Method CleanNamespace() As %Status [ Private ]
{
	New %gbl
	Set rtndb=$$GetGlobalSourceDatabase^%SYS.SECURITY($name(^ROUTINE("DemoRtn")))
	Set datadb=$$GetGlobalSourceDatabase^%SYS.SECURITY($name(^X))
	#; In case partition size was changed
	Set $zs=i%NSInfo("$zs")
	#; Remove routine/classes first
	Set cls=""
	For {
		Set cls=$order(^|rtndb|rINDEXCLASS(cls)) Quit:cls=""
		If '$data(i%NSInfo("cls",cls)) {
			Set name=$listget(^|rtndb|rINDEXCLASS(cls),2)
			Set remove(name)=""
		}
	}
	If $data(remove) {
		Do ..PrintLine("Removing classes left after test run:")
		Do Delete^%apiOBJ(.remove,"d")
	}
	Kill remove
	Set rtn="",first=1
	For {
		Set rtn=$order(^|rtndb|rINDEX(rtn)) Quit:rtn=""
		#; Assume unit test did not change type of rtn
		If '$data(i%NSInfo("rtn",rtn)) {
			For type="MAC","INT","MVI","BAS","INC","OBJ" {
				If '$data(^|rtndb|rINDEX(rtn,type)) Continue
				If '$data(i%NSInfo("rtn",rtn,type)) {
					If first {
						Set first=0
						Do ..PrintLine("Removing routines left after test run:")
					}
					Do ..PrintLine(rtn_"."_type,2)
					Set sc=$$Delete^%apiRTN(rtn_"."_type,0,0,0,0)
				}
			}
		}
	}
	If 'first Do ..PrintLine("")
	
	#; Now remove any new globals
	Set sc=$$GetGlobalDirectoryInfo^%SYS.DATABASE(datadb,$name(%gbl)) If $$$ISERR(sc) Quit sc
	Set i="",first=1
	For {
		Set i=$order(%gbl(i)) Quit:i=""
		If $extract(i,1,$length("DeepSee"))="DeepSee" Continue
		Set upper=$zconvert(i,"U")
		If $extract(upper)="Z"||($extract(upper,1,2)="%Z"),$extract(upper,1,3)'="ZEN",$extract(upper,1,4)'="%ZEN" Continue
		If $extract(upper,1,12)="TESTCOVERAGE" Continue
		If '$data(i%NSInfo("gbl",i)) {
			If $data(@("^|"""_datadb_"""|"_i)) {
				If first {
					Set first=0
					Do ..PrintLine("Globals left after suite ran, killing them:")
				}
				Do ..PrintLine("^"_i,2)
			}
			Kill @("^|"""_datadb_"""|"_i)
		}
	}
	If 'first Do ..PrintLine("")
	#; Take care of PPG's
	#dim rset As %Library.ResultSet
	set rset=##class(%ResultSet).%New(),first=1
	set rset.ClassName="%SYS.ProcessQuery"
	set rset.QueryName="PPG"
	set sc=rset.Execute("*",-1,"N")
	if $$$ISERR(sc) Quit sc
	While rset.Next() {
		set ppg=rset.Data("key")
		If $data(i%NSInfo("ppg",ppg)) Continue
		If ppg="%ISC.WorkQueueMgr"||(ppg="TempLog")||(ppg="%ISCQueryTemp") Continue
		If first {
			Set first=0
			Do ..PrintLine("Removing PPGs left after suite ran:")
		}
		Do ..PrintLine("^||"_ppg,2)
		Kill @("^||"_ppg)
	}
	If $data(i%NSInfo("ext")) {
		Set i=""
		For {
			Set i=$order(^oddEXT(i)) Quit:i=""
			If '$data(i%NSInfo("ext",i)) {
				Kill ^oddEXT(i)
			}
		}
	}
	#; Purge all cached queries and unfreeze all frozen plan and clear SQL stats
	Do Purge^%SYS.SQLSRV()
	#if $System.CLS.IsMthd("%SYSTEM.SQL","FreezePlans")
	Do $SYSTEM.SQL.FreezePlans(0,1,,.Errors)
	#endif
	Try { Do Purge^%SYS.PToolsDEP($NAMESPACE,"") } Catch e {}
	Try { Do clearStatsSQL^%SYS.PTools($NAMESPACE,"") } Catch e {}
	Quit $$$OK
}

//  <dd>when globalName is null "", the file list is simply executed

/// Run tests based on a list in a file
/// <dl>
/// <dt>
/// <var>globalName</var>
/// <dd>globalName is the global in whose nodes test names and directory names will be stored
/// <dd>globalName must start with "^" or be null ""
/// <dd>when globalName starts with "^" a global of that name is loaded
/// </dt>
/// <dt>
/// <var>fileName</var>
/// <dd>fileName is a file whose lines contain the test names and/or directory names to be executed
/// </dt>
/// <dt><i>qualifiers</i> 
/// <dd>Any of the following command-line arguments can be combined as a single string, such as <b>/noload/norecursive</b>. All are optional.<br><br>
/// The first four (<b>debug</b>, <b>load</b>, <b>run</b>, and <b>recursive</b>) are negatable Booleans.  They can be turned on with <i>/arg</i> or off by adding <b>no</b> in the front, as <b>/noload</b> or adding <b>=0</b> to the end, as <b>/load=0</b>.<br><br> 
/// 
/// <b>/debug</b>: Run in debug mode, which causes a break if a test fails. Default is <b>/nodebug</b>. <br><br>
/// <b>/load</b>: Load use cases from the specified <i>testspec</i>. Default is <b>/load</b>. If <b>/load</b> and <b>/run</b> are both on, then all loaded classes, routines, and CSP files are deleted after the tests are run. To prevent them from being deleted at the end, load them with <b>DebugLoadTestSuite</b> and run them with <b>DebugRunTestCase</b>.<br><br>
/// <b>/run</b>: Run the test suite.  Use <b>/norun</b> if you only want to load, but not run, a suite into a namespace. Default is <b>/run</b>.<br><br>
/// <b>/recursive</b>: Recurse the specified directory when loading test classes. Default is <b>/recursive</b>.<br><br>
/// <b>/display=all</b>: Display extended information when loading exported test class definitions. <b>/display=none</b> displays limited information. Default is <b>/display=all</b>. <br><br>
/// <b>/autoload</b>: Automatically load sub-directories with the given name when loading test classes.
/// Default is <b>/autoload=_autoload</b>.
/// When this qualifier is set, classes are loaded from the given sub-directory of the current directory and its ancestors.
/// This makes it possible to use a class in multiple test suites without copying it to each of their directories.<br><br>
/// <b>/nodelete</b>: Do not delete loaded classes when the test is complete.<br><br>
/// 
/// <dt><i>userparam</i> 
/// <dd>An arbitrary argument passed in by the caller of the <b>UnitTest</b>.  The top node of this variable becomes the value for the <b>UserParam</b> property of the <b>Manager</b>.
/// The first level subscripts and their values are used to populate the <b>UserFields</b> array.
/// </dl>
/// <br><br>
ClassMethod RunTestsFromFileList(globalName As %String, fileName As %String, qualifiers, userparam)
{
	Set globalName=$g(globalName)
	QUIT:$e(globalName)'="^"&&($e(globalName)'="")
	s file = ##class(%FileCharacterStream).%New()
	s file.Filename = fileName
	
	if globalName="" {
		// just execute tests named in file, tests separated by line terminators
		while ('file.AtEnd) {
			s test = file.ReadLine()
			s test = $zstrip(test,"<>W")
			if ($L(test) > 0) && ($E(test,1) '= "#") {
				d ..RunTest(test, .qualifiers, $G(userparam))
			}
		}
	} else {
		// read tests in file into a global which is then executed
		while ('file.AtEnd) {
			s test = file.ReadLine()
			s test = $zstrip(test,"<>W")
			if ($L(test) > 0) && ($E(test,1) '= "#") {
				s @globalName@(test)=""
			}
		}
		d ..RunTest(globalName, .qualifiers, $G(userparam))
		
	}
	q
}

/// Called at the end of SaveResult() to perform any result aggregation tasks required by subtasks.
Method OnAfterSaveResult(ByRef userparam)
{
}

/// Called before any unit tests are run.
/// If an error status is returned, no unit tests are run.
ClassMethod OnBeforeAllTests(manager As TestCoverage.ManagerBase, dir As %String, ByRef qstruct, ByRef userparam) As %Status
{
	Quit $$$OK
}

/// Called after all unit tests are run.
/// If an error status is returned, it is logged.
ClassMethod OnAfterAllTests(manager As TestCoverage.ManagerBase, dir As %String, ByRef qstruct, ByRef userparam) As %Status
{
	Quit $$$OK
}

/// Called before autoload, which occurs before each test suite is run.
/// If an error status is returned, it is logged and the test suite is not run.
Method OnBeforeAutoLoad(dir As %String, suite As %String, testspec As %String, ByRef qstruct) As %Status
{
	Quit $$$OK
}

/// Called a test suite is run.
/// If an error status is returned, it is logged and the test suite is not run.
/// This is called after autoload.
Method OnBeforeTestSuite(dir As %String, suite As %String, testspec As %String, ByRef qstruct) As %Status
{
	Quit $$$OK
}

/// Called after a test suite is run.
/// If an error status is returned, it is logged.
Method OnAfterTestSuite(dir As %String, suite As %String, testspec As %String, ByRef qstruct) As %Status
{
	Quit $$$OK
}

/// Called before a test case (class extending <class>%UnitTest.TestCase</class>) is run.
/// If an error status is returned, it is logged and the test case is not run.
Method OnBeforeTestCase(suite As %String, class As %String) As %Status
{
	Quit $$$OK
}

/// Called after a test case (class extending <class>%UnitTest.TestCase</class>) is run.
/// If an error status is returned, it is logged.
Method OnAfterTestCase(suite As %String, class As %String) As %Status
{
	Quit $$$OK
}

/// Called before a test (method starting with "Test" in a class extending <class>%UnitTest.TestCase</class>) is run.
/// If an error status is returned, it is logged and the test is not run.
Method OnBeforeOneTest(suite As %String, class As %String, method As %String) As %Status
{
	Quit $$$OK
}

/// Called after a test (method starting with "Test" in a class extending <class>%UnitTest.TestCase</class>) is run.
/// If an error status is returned, it is logged.
Method OnAfterOneTest(suite As %String, class As %String, method As %String) As %Status
{
	Quit $$$OK
}

}
