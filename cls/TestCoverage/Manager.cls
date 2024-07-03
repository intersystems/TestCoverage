Include (%occErrors, %syPidtab, TestCoverage)

/// To run a usual set of unit tests with code coverage, simply call <method>RunTest</method>() the same way as you would for %UnitTest.Manager. <br />
/// To run with higher/lower coverage detail, use (for a valid logical value of <property>CoverageDetail</property>): <br />
/// <example>
/// Set tCoverageParams("CoverageDetail") = 3 // Log details at the test method level.
/// Do ##class(TestCoverage.Manager).RunTest(,,.tCoverageParams)
/// </example>
/// <br />
/// For use in code based on a known (pre-loaded) unit test package, see documentation for <method>RunAllTests</method>. This also serves as a useful example for how to pass other related user parameters.
Class TestCoverage.Manager Extends %UnitTest.Manager
{

/// Level of detail at which test coverage is tracked.
/// <ol start="0">
/// <li>Overall</li>
/// <li>Suite</li>
/// <li>Class</li>
/// <li>Method</li>
/// </ol>
Property CoverageDetail As TestCoverage.DataType.Detail [ InitialExpression = 1 ];

/// If set to true, timing data is tracked as well as code coverage.
Property Timing As %Boolean [ InitialExpression = 0, Internal, Private ];

/// Set to true (1) if coverage targets should be loaded dynamically from the unit test root.
Property DynamicTargets As %Boolean [ InitialExpression = 1, Internal, Private ];

/// Current list of objectscript targets (routines, classes, .int code, etc.) for line-by-line monitoring
Property CoverageTargets As %List [ Internal, Private ];

/// Current list of compiled Python targets for line-by-line monitoring
Property PyCoverageTargets As %List [ Internal, Private ];

/// All classes considered at any point during this unit test run
/// Top-level node has $ListBuild list; also has subscripts with individual class names for a quicker lookup
Property CoverageClasses As %List [ Internal, MultiDimensional, Private ];

/// All routines considered at any point during this unit test run
/// Top-level node has $ListBuild list; also has subscripts with individual routine names for a quicker lookup
Property CoverageRoutines As %List [ Internal, MultiDimensional, Private ];

/// All compiled python files considered at any point during this unit test run
/// Top-level node has $ListBuild list; also has subscripts with individual routine names for a quicker lookup
Property CoveragePythons As %List [ Internal, MultiDimensional, Private ];

/// Last known coverage.list file
Property LastCoverageListFile As %String(MAXLEN = "") [ Internal, Private ];

Property CurrentTestSuite As %String(MAXLEN = 255) [ Internal, Private ];

Property CurrentTestClass As %String(MAXLEN = 255) [ Internal, Private ];

Property CurrentTestMethod As %String(MAXLEN = 255) [ Internal, Private ];

Property SourceNamespace As %String(MAXLEN = 255) [ Internal, Private ];

Property ProcessIDs As %List [ Internal, Private ];

Property Run As TestCoverage.Data.Run;

/// Known coverage targets (already snapshotted). <br />
/// Value at subscript is set to 1 if there are executable lines of code in the target, 0 if not.
Property KnownCoverageTargets [ MultiDimensional, Private ];

/// Cache of (name, type) -> hash
Property Hashes [ MultiDimensional ];

Property Monitor As TestCoverage.Utils.LineByLineMonitor [ InitialExpression = {##class(TestCoverage.Utils.LineByLineMonitor).%New()}, Private ];

/// Runs unit tests that have been loaded, with code coverage enabled. <br />
/// Note that if coverage is to be tracked for lots of code, it may be necessary to increase the "gmheap" setting
/// (under Configuration - Additional Settings - Advanced Memory in the Management Portal). <br />
/// <ul>
/// <li><var>pPackage</var> has the top-level package containing all the unit test classes to run. These must already be loaded.</li>
/// <li><var>pLogFile</var> (optional) may specify a file to log all output to.</li>
/// <li><var>pCoverageClasses</var> (optional) has a $ListBuild list or %DynamicArray of class names within which to track code coverage. By default, none are tracked.</li>
/// <li><var>pCoverageRoutines</var> (optional) has a $ListBuild list or %DynamicArray of routine names within which to track code coverage. By default, none are tracked.</li>
/// <li><var>pCoverageLevel</var> (optional) is 0 to track code coverage overall; 1 to track it per test suite (the default); 2 to track it per test class; 3 to track it per test method.
/// Note that overall tracking is always available; more granular tracking requires more time and disk space.</li>
/// <li><var>pLogIndex</var> (optional) allows for aggregation of code coverage results across unit test runs. To use this, get it back as output from the first test run, then pass it to the next.</li>
/// <li><var>pSourceNamespace</var> (optional) specifies the namespace in which classes were compiled, defaulting to the current namespace. This may be required to retrieve some metadata.</li>
/// <li><var>pPIDList</var> (optional) has a $ListBuild list of process IDs to monitor. If this is empty, all processes are monitored. By default, this is just the current process.</li>
/// <li><var>pTiming</var> (optional) may be set to 1 to also collect timing information per line.</li>
/// </ul>
/// Granular data is stored in <class>TestCoverage.Data.Coverage</class>; aggregated data is stored per class in <class>TestCoverage.Data.Aggregate.ByCodeUnit</class> and for the whole run in <class>TestCoverage.Data.Aggregate.ByRun</class>.
/// @API.Method
ClassMethod RunAllTests(pPackage As %String = "", pLogFile As %String = "", pCoverageClasses As %List = "", pCoverageRoutines As %List = "", pCoverageLevel As %Integer = 1, ByRef pLogIndex As %Integer, pSourceNamespace As %String = {$Namespace}, pPIDList = {$ListBuild($Job)}, pTiming As %Boolean = 0) As %Status
{
	#dim tUnitTestManager As TestCoverage.Manager
	Set tSuccess = 1
	Try {
		Set tLogFileOpen = 0
		Set tOldIO = $io
		If (pLogFile '= "") {
			Open pLogFile:"WNS":10
			Set tLogFileOpen = 1
			Use pLogFile
		}
		
		Set tTestSuite = $Replace(pPackage,"/",".")
		Set tSpec = "/noload/nodelete"
		Merge tCoverageParams("LogIndex") = pLogIndex // Set only if defined.
		Set tCoverageParams("CoverageClasses") = $SELECT($CLASSNAME(pCoverageClasses) = "%Library.DynamicArray":..ArrayToList(pCoverageClasses), 1:pCoverageClasses)
		Set tCoverageParams("CoverageRoutines") = $SELECT($CLASSNAME(pCoverageRoutines) = "%Library.DynamicArray":..ArrayToList(pCoverageRoutines), 1:pCoverageRoutines)
		Set tCoverageParams("CoverageDetail") = pCoverageLevel
		Set tCoverageParams("SourceNamespace") = pSourceNamespace
		Set tCoverageParams("ProcessIDs") = pPIDList
		Set tCoverageParams("Timing") = pTiming
		Do ..RunTest(tTestSuite,tSpec,.tCoverageParams)
		
		Set tFailed = 0
		&sql(select top 1 1
					into :tFailed
			   from %UnitTest_Result.TestSuite s
			   join %UnitTest_Result.TestCase c
			     on s.Id = c.TestSuite
			  where s.TestInstance = :tCoverageParams("UseLogIndex") and c.Status = 0)
		If (SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
		}
		If (SQLCODE = 100) {
			// No results.
			Set tFailed = 0
		}

		If (tFailed '= 0) {
			Set tSuccess = 0
		}
	} Catch e {
		Set tSuccess = 0
		Write e.DisplayString(),!
	}
	Use tOldIO
	Close:tLogFileOpen pLogFile
	Quit $Select(tSuccess:1,1:$$$ERROR($$$GeneralError,"One or more errors occurred in unit tests."))
}

ClassMethod ArrayToList(pDynamicArray As %DynamicArray) As %List
{
	Set tList = ""
	Set tIter = pDynamicArray.%GetIterator()
	While tIter.GetNext(, .value) {
		Set tList = tList _ $LISTBUILD(value)
	}
	Quit tList
}

/// write ##class(TestCoverage.Manager).HasPython("EP.sysSettrace")
/// 1
ClassMethod HasPython(pClassName As %String) As %Boolean
{
	return $data(^ROUTINE(pClassName _ ".py", 0, 0)) > 0
}

Method SetCoverageTargets(pClasses As %List = "", pRoutines As %List = "", pInit As %Boolean = 0) [ Private ]
{
	Set tList = "", tPtr = 0
	Set tPyList = ""
	While $ListNext(pClasses,tPtr,tClass) {
		// Use a wildcard to include all .int files associated with the class.
		Set tList = tList_$ListBuild(tClass_".CLS")
		Do ..AddCoverageClass(tClass)
		If (..HasPython(tClass)) {
			set tPyList = tPyList _ $ListBuild(tClass)
		}
	}
	While $ListNext(pRoutines,tPtr,tRoutine) {
		Set tList = tList_$ListBuild(tRoutine_".MAC")
		Do ..AddCoverageRoutine(tRoutine)
	}
	Set ..CoverageTargets = ..GetObjectCodeForSourceNames(tList)
	Set ..PyCoverageTargets = tPyList 
	If pInit {
		// Set flag to determine code coverage dynamically.
		Set ..DynamicTargets = (tList = "")
	}
}

Method CoverageTargetsSet(%value) As %Status [ Internal, Private ]
{
	If (%value '= $Get(i%CoverageTargets)) {
		If ##class(TestCoverage.Utils.LineByLineMonitor).IsRunning() {
			For tLevel=1:1:..CoverageDetail {
				Set tContext($Increment(tContext)) = $Case(tLevel,
					1:..CurrentTestSuite,
					2:..CurrentTestClass,
					3:..CurrentTestMethod)
			}
			$$$ThrowOnError(..EndCoverageTracking(tContext...))
		}
		Set i%CoverageTargets = %value
		$$$ThrowOnError(..StartCoverageTracking())
	}
	Quit $$$OK
}

Method StartCoverageTracking() As %Status [ Private ]
{
	Set tSC = $$$OK
	New $Namespace
	Try {
		If (..CoverageTargets '= "") {
			Set $Namespace = ..SourceNamespace
			
			Set tRelevantTargets = ""
			Set tPyRelevantTargets = ""
			Set tNewTargets = ""
			Set tPointer = 0
			While $ListNext(..CoverageTargets,tPointer,tCoverageTarget) {
				If '$Data(..KnownCoverageTargets(tCoverageTarget),tIsRelevant)#2 {
					Set tNewTargets = tNewTargets_$ListBuild(tCoverageTarget)
				} ElseIf tIsRelevant {
					Set tRelevantTargets = tRelevantTargets_$ListBuild(tCoverageTarget)
					// check if the relevant old targets have python components
					Set tOther = ##class(%Library.RoutineMgr).GetOther(tCoverageTarget,"INT",-1)
					If (tOther '= "") && ($Piece(tOther,".",*) = "CLS") {
						set tName = $piece(tOther, ".", 1, *-1)
						If (..HasPython(tName)) {
							set tPyRelevantTargets = tPyRelevantTargets _ $ListBuild(tName)
						}
					}
				}
			}
			
			If (tNewTargets '= "") {
				$$$StartTimer("Taking snapshot of code and CLS/MAC/INT mappings")
				Set tSC = ##class(TestCoverage.Utils).Snapshot(tNewTargets, .tNewRelevantTargets, .tNewPyRelevantTargets)
				$$$StopTimer
				$$$ThrowOnError(tSC)
			
				Set tPointer = 0
				While $ListNext(tNewTargets,tPointer,tNewTarget) {
					Set ..KnownCoverageTargets(tNewTarget) = 0
				}
				
				Set tPointer = 0
				While $ListNext(tNewRelevantTargets,tPointer,tRelevantTarget) {
					Set ..KnownCoverageTargets(tRelevantTarget) = 1
					Set tRelevantTargets = tRelevantTargets_$ListBuild(tRelevantTarget)
				}

				Set tPointer = 0
				While $ListNext(tNewPyRelevantTargets,tPointer,tPyRelevantTarget) {
					Set tPyRelevantTargets = tPyRelevantTargets_$ListBuild(tPyRelevantTarget)
				}
			}
			
			If (tRelevantTargets = "") {
				Write !,"WARNING: Nothing found to monitor for routine(s): "_$ListToString(tNewTargets)
			}
			
			// If we are to monitor all process IDs, actually use all except for the SuperServer (Routine = '%SYS.SERVER')
			// Workaround for versions without RFD1682
			Set tProcessIDs = ..ProcessIDs
			If (tProcessIDs = "") {
				&sql(select %DLIST(Pid) into :tProcessIDs from %SYS.ProcessQuery where Routine <> '%SYS.SERVER')
				If (SQLCODE < 0) {
					Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
				}
			
				// Extra check to make sure that monitor is stopped (another chance to get problem processes to unmap from shared memory)
				// Sometimes the monitor does not stop right away if there are other processes that are being monitored.
				// The root cause of this is unknown and could use further investigation at some point.
				Set tMaxAttempts = 5
				For {
					Set tUnmappedAll = $zu(84,0,0)
					Hang 1
					If (tUnmappedAll) {
						Quit
					}
					If ($Increment(tUnmapCounter) > tMaxAttempts) {
						Set tMsg = $$$FormatText("Some process(es) still holding on to shared memory for line by line monitor after %1 attempts to release. See console log or cstat -p-1 for details.",tMaxAttempts)
						$$$ThrowStatus($$$ERROR($$$GeneralError,tMsg))
					}
				}
			}
			Set tMetrics = $ListBuild("RtnLine") _ $Select(..Timing:$ListBuild("Time","TotalTime"),1:"")
			$$$ThrowOnError(..Monitor.StartWithScope(tRelevantTargets, tPyRelevantTargets, tMetrics,tProcessIDs))
		}
	} Catch e { 
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method UpdateCoverageTargetsForTestDirectory(pDirectory As %String) As %Status [ Private ]
{
	Set tSC = $$$OK
	Try {
		// Look for a file named "coverage.list" in pDirectory and its ancestors.
		Set tDir = pDirectory
		Set tParent = ""
		Set tListFile = ""
		For {
			If (tDir = tParent) {
				// When we get to the root, the parent is the same as the directory itself.
				Quit
			} ElseIf (tParent '= "") {
				Set tDir = tParent
			}
			
			// Does a file exist there?
			Set tFile = tDir _ "coverage.list"
			If ##class(%File).Exists(tFile) {
				Set tListFile = tFile
				Quit
			}
			Set tParent = ##class(%File).ParentDirectoryName(tDir)
		}
		
		// If this is the last file we checked, quit here.
		If (tListFile = ..LastCoverageListFile) {
			Quit
		}
		Set ..LastCoverageListFile = tListFile
		
		// If we found it, read in coverage list from there.
		Set tCoverageTargetList = ""
		Set tPyCoverageTargetList = ""
		If (tListFile '= "") {
			Do ..PrintLine("Tracking code coverage on resources listed in "_tListFile)
			Do ..GetCoverageTargetsForFile(tListFile, .tCoverageTargets)
			
			For tType = "CLS","MAC" {
				Set tCoverageTargetKey = ""
				For {
					Set tCoverageTargetKey = $Order(tCoverageTargets(tType,tCoverageTargetKey))
					If (tCoverageTargetKey = "") {
						Quit
					}
					Set tCoverageTargetList = tCoverageTargetList _ $ListBuild(tCoverageTargetKey_"."_tType)
					
					If (tType = "CLS") {
						Do ..AddCoverageClass(tCoverageTargetKey)
						If (..HasPython(tCoverageTargetKey)) {
							Set tPyCoverageTargetList = $get(tPyCoverageTargetList) _ $ListBuild(tCoverageTargetKey)
						}
					} Else {
						Do ..AddCoverageRoutine(tCoverageTargetKey)
					}
				}
			}
		}
		
		Set tObjectCodeList = ..GetObjectCodeForSourceNames(tCoverageTargetList)
		Set ..CoverageTargets = tObjectCodeList // Also restarts the monitor if it is running and updates data on covered routines/classes
		Set ..PyCoverageTargets = tPyCoverageTargetList // no need to get the compiled names, it's already correct 
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method AddCoverageClass(pClassName As %Dictionary.CacheClassname) [ Private ]
{
	If '$Data(..CoverageClasses(pClassName)) {
		Set ..CoverageClasses = $Get(..CoverageClasses) _ $ListBuild(pClassName)
		Set ..CoverageClasses(pClassName) = ""
		If (..HasPython(pClassName)) {
			Set ..CoveragePythons = $Get(..CoveragePythons) _ $ListBuild(pClassName)
			Set ..CoveragePythons(pClassName) = ""
		}
	}
}

Method AddCoverageRoutine(pRoutineName As %String) [ Private ]
{
	If '$Data(..CoverageRoutines(pRoutineName)) {
		Set ..CoverageRoutines = $Get(..CoverageRoutines) _ $ListBuild(pRoutineName)
		Set ..CoverageRoutines(pRoutineName) = ""
	}
}

ClassMethod GetCoverageTargetsForFile(pFileName As %String, Output pTargetArray) [ Private ]
{
	Kill pTargetArray
	
	Set tFileStream = ##class(%Stream.FileCharacter).%New()
	Do tFileStream.LinkToFile(pFileName)
	While 'tFileStream.AtEnd {
		Set tFileLines($Increment(tFileLines)) = tFileStream.ReadLine()
	}
	
	For tLineIndex=1:1:$Get(tFileLines) {
		Set tLine = tFileLines(tLineIndex)
		
		// Skip blank lines
		If (tLine = "") {
			Continue
		}
		
		// Skip comment lines
		Set tFirstChar = $Extract(tLine)
		If (tFirstChar = "/") || (tFirstChar = ";") || (tFirstChar = "#") {
			Continue
		}
		
		Set tExclude = 0
		If (tFirstChar = "-") {
			// "-" at the beginning of a line indicates that the following class/routine/package
			// should be *excluded* from coverage tracking
			Set tExclude = 1
			Set tLine = $Extract(tLine,2,*)
		}
		
		Set tName = $Piece(tLine,".",1,*-1)
		Set tExtension = $ZConvert($Piece(tLine,".",*),"U")
		
		Kill tNames
		If (tExtension = "MAC") {
			If (tName [ "*") {
				Do ..SearchRoutines(tLine,.tNames)
			} Else {
				Set tNames(tName) = ""
			}
		} ElseIf (tExtension = "PKG") {
			Set tSC = $System.OBJ.GetPackageList(.tNames,tName)
			$$$ThrowOnError(tSC)
			Set tExtension = "CLS"
		} ElseIf (tExtension = "CLS") {
			If (tName = "*") {
				// TODO: support special case of *.CLS
			} Else {
				Set tNames(tName) = ""
			}
		}
		
		If $Data(tNames) {
			Set tNameKey = ""
			For {
				Set tNameKey = $Order(tNames(tNameKey))
				If (tNameKey = "") {
					Quit
				}
				If (tExclude) {
					Kill pTargetArray(tExtension,tNameKey)
				} Else {
					Set pTargetArray(tExtension,tNameKey) = ""
				}
			}
		}
	}
}

ClassMethod SearchRoutines(pSearchExpr As %String, Output pRoutines) [ Private ]
{
	// %Monitor.System.LineByLine:Start uses this, so why not?
	// Probably better than using a Studio list API in terms of what is/isn't hidden,
	// especially working with system routines.
	Do {
		Set tData = ""
		Set tAtEnd = '$$LIST^%R(pSearchExpr,32767,0,.tData,.tContext)
		Set tPointer = 0
		While $ListNext(tData,tPointer,tRoutine) {
			Set pRoutines($Piece(tRoutine,".",1,*-1)) = ""
		}
	} While 'tAtEnd
}

Method GetObjectCodeForSourceNames(pSourceNameList As %List) As %List [ Private ]
{
	New $Namespace
	Set $Namespace = ..SourceNamespace
	Set tOutputNameList = ""
	Set tPointer = 0
	While $ListNext(pSourceNameList,tPointer,tSourceName) {
		Set tName = $Piece(tSourceName,".",1,*-1)
		Set tType = $Piece(tSourceName,".",*)
		Set tOthers = $ListFromString(##class(%Library.RoutineMgr).GetOther(tName,tType,1))
		Set tOtherPointer = 0
		While $ListNext(tOthers,tOtherPointer,tOtherName) {
			Set tOutputNameList = tOutputNameList_$ListBuild($Piece(tOtherName,".",1,*-1))
		}
}
	Quit tOutputNameList
}

Method EndCoverageTracking(pTestSuite As %String = "", pTestClass As %String = "", pTestMethod As %String = "") As %Status [ Private ]
{
	Set tSC = $$$OK
	Try {
		If (..CoverageTargets '= "") {
			// Pause the monitor.
			Set tSC = ..Monitor.Pause()
			Do ##class(TestCoverage.Utils.LineByLineMonitor).PyStop()
			If $$$ISERR(tSC) {
				If $System.Status.GetErrorCodes(tSC) = $$$MonitorNotRunning {
					// Not really an error, and nothing to do in this case.
					Set tSC = $$$OK
					Quit
				} Else {
					$$$ThrowStatus(tSC)
				}
			}
			
			Set tTarget = $ListBuild($$$TestPathAllTests) // detail = 0
			If (pTestSuite '= "") {
				Set tTarget = $ListBuild(pTestSuite) // detail > 0
			}
			If (pTestClass '= "") {
				Set tTarget = tTarget_$ListBuild(pTestClass)
			}
			If (pTestMethod '= "") {
				Set tTarget = tTarget_$ListBuild(pTestMethod)
			}
			Set tTarget = $ListToString(tTarget,":")
			Do ..Run.TestPaths.Insert(tTarget)
			$$$ThrowOnError(..Run.%Save())
			Set tTestIndex = ..Run.%Id()
			
			$$$StartTimer("Collecting coverage data for "_tTarget)
			Merge tCache = ..Hashes
			Set tRtnCount = ..Monitor.GetRoutineCount()
			For i=1:1:tRtnCount {
				Set tRtnName = ..Monitor.GetRoutineName(i)
				Set tSC = ##class(TestCoverage.Data.Coverage).StoreIntCoverage(tTestIndex,tTarget,tRtnName,"INT",.tCache)
				$$$ThrowOnError(tSC)
			}

			Set tPyClasses = ..Monitor.PythonClassList
			Set tPointer = 0
			While $ListNext(tPyClasses, tPointer, tClass) {
				Set tSC = ##class(TestCoverage.Data.Coverage).StoreIntCoverage(tTestIndex,tTarget,tClass,"PY",.tCache)
				$$$ThrowOnError(tSC)
			}
			Merge ..Hashes = tCache

			$$$StopTimer
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	
	Quit tSC
}

/// Called at the end of SaveResult() to perform any result aggregation tasks required by subtasks.
Method OnAfterSaveResult(ByRef userparam)
{
	Try {
		Quit:'$IsObject(..Run)
		
		// Associate to unit test results.
		Do ..Run.TestResultsSetObjectId(..LogIndex)
		$$$ThrowOnError(..Run.%Save())
		
		Set tRunIndex = ..Run.%Id()
		If (tRunIndex '= "") {
			Set userparam("LogIndex") = tRunIndex
			
			$$$StartTimer("Mapping to class/routine coverage")
			Set tSC = ##class(TestCoverage.Data.Run).MapRunCoverage(tRunIndex)
			$$$ThrowOnError(tSC)
			$$$StopTimer
			
			$$$StartTimer("Aggregating coverage data")
			Set tSC = ##class(TestCoverage.Utils).AggregateCoverage(tRunIndex)
			$$$ThrowOnError(tSC)
			$$$StopTimer
			
			Do ##class(TestCoverage.Utils).ShowAggregateCoverage(tRunIndex)

			If $Data(userparam("CoverageReportClass"),tReportClass)#2 && $Data(userparam("CoverageReportFile"),tReportFile)#2 {
				$$$ThrowOnError($classmethod(tReportClass,"GenerateReport",tRunIndex,tReportFile))
			}
		}
	} Catch e {
		// Swallow exceptions.
		Write !,$System.Status.GetErrorText(e.AsStatus())
	}
	Quit
}

/// Called before any unit tests are run.
/// If an error status is returned, no unit tests are run.
ClassMethod OnBeforeAllTests(manager As TestCoverage.Manager, dir As %String, ByRef qstruct, ByRef userparam) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tCoverageClasses = $Get(userparam("CoverageClasses"))
		Set tCoverageRoutines = $Get(userparam("CoverageRoutines"))
		Set tCoverageDetail = $Get(userparam("CoverageDetail"))
		Set tSourceNamespace = $Get(userparam("SourceNamespace"),$Namespace)
		Set tProcessIDs = $Get(userparam("ProcessIDs"),$ListBuild($Job))
		If (tProcessIDs = "*") {
			Set tProcessIDs = ""
		} ElseIf (tProcessIDs = "") || '$ListValid(tProcessIDs) {
			Set tProcessIDs = $ListBuild($Job)
		}
		Set tTiming = $Get(userparam("Timing"),0)
		Set tSubject = $Get(userparam("Subject"))
		Set tIsCommitted = $Get(userparam("IsCommitted"),0)
		Set tOrdering = $Get(userparam("Ordering"))
		
		Set manager.SourceNamespace = tSourceNamespace
		Set manager.ProcessIDs = tProcessIDs
		Set manager.Timing = tTiming
		Do manager.SetCoverageTargets(tCoverageClasses,tCoverageRoutines,1)
		If (tCoverageDetail '= "") {
			If (tCoverageDetail '= +tCoverageDetail) {
				// If we were passed a display value...
				Set tCoverageDetail = ..CoverageDetailDisplayToLogical(tCoverageDetail)
			}
			If '..CoverageDetailIsValid(tCoverageDetail) {
				// Invalid coverage detail.
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid code coverage detail level: %1",userparam("CoverageDetail")))
				Quit
			}
			Set manager.CoverageDetail = tCoverageDetail
		}
		If $Data(userparam("LogIndex"),tRunIndex) {
			Set manager.Run = ##class(TestCoverage.Data.Run).%OpenId(tRunIndex,,.tSC)
			$$$ThrowOnError(tSC)
		} Else {
			Set manager.Run = ##class(TestCoverage.Data.Run).%New()
			Do manager.Run.Metrics.Insert("RtnLine")
			If manager.Timing {
				Do manager.Run.Metrics.Insert("Time")
				Do manager.Run.Metrics.Insert("TotalTime")
			}
		}
		Set manager.Run.Detail = manager.CoverageDetail
		Set manager.Run.Subject = tSubject
		Set manager.Run.IsCommitted = tIsCommitted
		Set manager.Run.Ordering = tOrdering
		
		If manager.DynamicTargets && (dir '= "") {
			// Determine coverage targets based on directory contents (looking for coverage.list in that directory or the nearest ancestor containing it).
			Set tSC = manager.UpdateCoverageTargetsForTestDirectory(dir)
			$$$ThrowOnError(tSC)
		}
		
		If (manager.CoverageDetail = 0) {
			Set tSC = manager.StartCoverageTracking()
			$$$ThrowOnError(tSC)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Called after all unit tests are run.
/// If an error status is returned, it is logged.
/// <var>manager</var> is an instance of this class.
ClassMethod OnAfterAllTests(manager As TestCoverage.Manager, dir As %String, ByRef qstruct, ByRef userparam) As %Status
{
	Set tSC = $$$OK
	Try {
		If (manager.CoverageDetail = 0) {
			Set tSC = manager.EndCoverageTracking()
		}
		Do manager.Monitor.Stop()
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Called before autoload, which occurs before each test suite is run.
/// If an error status is returned, it is logged and the test suite is not run.
Method OnBeforeAutoLoad(dir As %String, suite As %String, testspec As %String, ByRef qstruct) As %Status
{
	Set tSC = $$$OK
	Try {
		// TODO: Flag to capture code coverage of compiling autoload classes? (e.g., to cover generators?)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Called before a test suite is run.
/// If an error status is returned, it is logged and the test suite is not run.
/// This is called after autoload.
Method OnBeforeTestSuite(dir As %String, suite As %String, testspec As %String, ByRef qstruct) As %Status
{
	Set tSC = $$$OK
	Try {
		If ..DynamicTargets && (dir '= "") {
			// Determine coverage targets based on directory contents (looking for coverage.list in that directory or the nearest ancestor containing it).
			Set tSC = ..UpdateCoverageTargetsForTestDirectory(dir)
			$$$ThrowOnError(tSC)
		}
		Set ..CurrentTestSuite = $Case(suite,"":"(root)",:suite)
		Set ..CurrentTestClass = ""
		Set ..CurrentTestMethod = ""
		If (..CoverageDetail = 1) {
			Set tSC = ..StartCoverageTracking()
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Called after a test suite is run.
/// If an error status is returned, it is logged.
Method OnAfterTestSuite(dir As %String, suite As %String, testspec As %String, ByRef qstruct) As %Status
{
	Set tSC = $$$OK
	Try {
		If (..CoverageDetail = 1) {
			Set tSC = ..EndCoverageTracking($Case(suite,"":"(root)",:suite))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Called before a test case (class extending <class>%UnitTest.TestCase</class>) is run.
/// If an error status is returned, it is logged and the test case is not run.
Method OnBeforeTestCase(suite As %String, class As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set ..CurrentTestClass = class
		Set ..CurrentTestMethod = ""
		If (..CoverageDetail = 2) {
			Set tSC = ..StartCoverageTracking()
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Called after a test case (class extending <class>%UnitTest.TestCase</class>) is run.
/// If an error status is returned, it is logged.
Method OnAfterTestCase(suite As %String, class As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		If (..CoverageDetail = 2) {
			Set tSC = ..EndCoverageTracking(suite, class)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Called before a test (method starting with "Test" in a class extending <class>%UnitTest.TestCase</class>) is run.
/// If an error status is returned, it is logged and the test is not run.
Method OnBeforeOneTest(suite As %String, class As %String, method As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set ..CurrentTestMethod = method
		If (..CoverageDetail = 3) {
			Set tSC = ..StartCoverageTracking()
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Called after a test (method starting with "Test" in a class extending <class>%UnitTest.TestCase</class>) is run.
/// If an error status is returned, it is logged.
Method OnAfterOneTest(suite As %String, class As %String, method As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		If (..CoverageDetail = 3) {
			Set tSC = ..EndCoverageTracking(suite, class, method)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method PrintURL()
{
	Do ##super()
	
	If $IsObject(..Run) {
		Set tURL = ..GetURL(..Run.%Id())
		If (tURL '= "") {
			Do ..PrintLine("Use the following URL to view test coverage data:")
			Do ..PrintLine(tURL)
		} Else {
			Do ..PrintLine("WARNING: No default web application found for namespace '"_$Namespace_"' - test coverage results cannot be viewed.")
		}
	}
	Quit
}

/// Returns the URL to the aggregate result viewer. <br />
/// <var>pRunID</var> is the test coverage run index.
/// <var>pHost</var> contains the host/protocol to use.
/// <var>pPath</var> contains the rest of the URL after that.
ClassMethod GetURL(pRunID As %String, Output pHost As %String, Output pPath As %String) As %String
{
	Set tSC = ##class(%Library.RoutineMgr).GetWebServerPort(.tPort,.tServer,.tURLPrefix)
	$$$ThrowOnError(tSC)
	Set pHost = $ZConvert($Get(^%SYS("WebServer","Protocol"),$Select(tPort=443:"https",1:"http")),"l")
	Set pHost = pHost_"://"_$Get(^%SYS("HealthShare","NetworkHostName"),tServer)
	// Ports 80 and 443 are defaults for their respective protocols; in other cases, port needs to be explicit.
	Set pHost = pHost _ $Case(tPort,80:"",443:"",:":"_tPort)
	Set tDefaultApp = $System.CSP.GetDefaultApp($Namespace)
	If (tDefaultApp = "") || (((tDefaultApp = "/csp/sys") || (tDefaultApp [ "/csp/sys/")) && ($Namespace '= "%SYS")) {
		// The URL won't be valid, so just return an empty string.
		Quit ""
	}
	Set pPath = $Case(tURLPrefix,"":"",:"/"_tURLPrefix)
	Set pPath = pPath _ tDefaultApp
	Set pPath = pPath _ "/TestCoverage.UI.AggregateResultViewer.cls?Index="_$ZConvert(pRunID,"O","URL")
	Quit pHost_pPath
}

}
