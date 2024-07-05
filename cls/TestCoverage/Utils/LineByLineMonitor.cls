Include %occErrors

/// Wrapper around %Monitor.System.LineByLine to ensure that the monitor is stopped when it should be, and also
/// to wrap the decision about whether to stop/start the monitor or to just clear counters.
Class TestCoverage.Utils.LineByLineMonitor Extends %Monitor.System.LineByLine
{

/// True if the line-by-line monitor has been started.
Property Started As %Boolean [ Calculated, Private, ReadOnly ];

Method StartedGet() As %Boolean [ CodeMode = expression ]
{
$zu(84,8)
}

/// True if the line-by-line monitor is paused
Property Paused As %Boolean [ Calculated, Private, ReadOnly ];

Method PausedGet() As %Boolean [ CodeMode = expression ]
{
..Started && '$zu(84,1)
}

/// The current python classes being tracked, so that we know what to store the coverage for
Property PythonClassList As %List;

Property LastRoutineList As %List [ Private ];

Property LastMetricList As %List [ Private ];

Property LastProcessList As %List [ Private ];

/// This callback method is invoked by the <METHOD>%Close</METHOD> method to 
/// provide notification that the current object is being closed.
/// 
/// <P>The return value of this method is ignored.
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
	If ..Started {
		Do ..Stop()
	}
	
	Quit $$$OK
}

ClassMethod CheckAvailableMemory(pProcessCount As %Integer, pRoutineCount As %Integer, pRequireError As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set tRequiredPages = $zu(84,0,4,pProcessCount,0,pRoutineCount,0,0)
	Set tAvailablePages = $zu(84,0,5)
	If pRequireError || (tRequiredPages > tAvailablePages) {
		Set tSC = $$$ERROR($$$GeneralError,"Insufficient memory for line by line monitor - consider increasing gmheap. Contiguous memory required: "_(tRequiredPages*64)_" KB; reported available: "_(tAvailablePages*64)_" KB")
	}
	Quit tSC
}

ClassMethod PyStartWithScope(pCoverageClasses As %List) [ Language = python ]
{
	
	from sys import settrace 
	import iris

	tCoverageClasses = set(iris.cls('%SYS.Python').ToList(pCoverageClasses))
	def my_tracer(frame, event, arg = None): 
		# extracts frame code 
		code = frame.f_code 
		# extracts calling function name and the class that the function is in 
		func_name = code.co_name 
		class_name = frame.f_globals['__name__']
		# extracts the line number 
		line_no = frame.f_lineno 
		if class_name in tCoverageClasses and line_no != 1: # if this is in a covered class 
			# print(f"A {event} encountered in {func_name}() in class {class_name} at line number {line_no}")
			tGlob = iris.gref('^IRIS.TEMP.TestCoveragePY')
			curId = tGlob.get([class_name])
			if not curId:
				tGlob[class_name] = 1
				curId = 1
			tGlob[class_name, curId] = line_no
			tGlob[class_name] = curId+1
			#; iris.execute('set ^TestCovera3FF5.PyMonitorReC80BD($i(^TestCovera3FF5.PyMonitorReC80BD)) = $listbuild("", ^IRIS.TEMP.TestCoveragePY(1), ^IRIS.TEMP.TestCoveragePY(2),^IRIS.TEMP.TestCoveragePY(3) )')
			
			#; new_line = iris.cls("TestCoverage.Data.PyMonitorResults")._New()
			#; new_line.ClassName = class_name
			#; new_line.FunctionName = func_name
			#; new_line.LineNumber = line_no 
			#; new_line._Save() 
			
			#; stmt = iris.sql.prepare("INSERT INTO TestCoverage_Data.PyMonitorResults (ClassName, FunctionName, LineNumber) VALUES (?, ?, ?)")
			#; try:
			#; 	rs = stmt.execute(class_name, func_name, line_no)
			#; except Exception as ex:
			#; 	print(ex.sqlcode, ex.message)
			
			# iris.cls("TestCoverage.Utils.LineByLineMonitor").DoNothing()
			# iris.cls("TestCoverage.Utils.LineByLineMonitor").SavePyLine(line_no, func_name, class_name)
			#; glob[0] = "we make it back"
		return my_tracer
	settrace(my_tracer)
}

ClassMethod PyClearCounters()
{
	Kill ^IRIS.TEMP.TestCoveragePY
	#; &sql(
	#; 	delete from TestCoverage_Data.PyMonitorResults
	#; )
	#; If (SQLCODE < 0) {
	#; 	Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
	#; }
}

ClassMethod DoNothing()
{
	set x = 1
}

ClassMethod SavePyLine(LineNumber As %Integer, FunctionName As %String, ClassName As %String)
{
	#; &sql(
	#; 	INSERT INTO TestCoverage_Data.PyMonitorResults 
	#; 	(ClassName, FunctionName, LineNumber) 
	#; 	VALUES (:ClassName, :FunctionName, :LineNumber)
	#; )

	#; If (SQLCODE < 0) {
	#; 	Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
	#; }
}

ClassMethod PyStop() [ Language = python ]
{
	from sys import settrace 
	settrace(None)
}

/// Tracks current monitoring context and stops/starts or resets counters depending on whether it has changed
Method StartWithScope(pRoutineList As %List, pPyClasses As %List, pMetricList As %List, pProcessList As %List) As %Status
{
	Set tSC = $$$OK
	Try {
		Set ..PythonClassList = pPyClasses
		Set tDifferentScope = (..LastRoutineList '= pRoutineList) || (..LastMetricList '= pMetricList) || (..LastProcessList '= pProcessList)
		If tDifferentScope && ..Started {
			// If we need to track different routines/metrics/processes, need to stop the monitor before restarting with the new context.
			Do ..Stop()
			Do ..PyStop()
			Set ..LastRoutineList = pRoutineList
			Set ..LastMetricList = pMetricList
			Set ..LastProcessList = pProcessList
		}
		
		If '..Started {
			Do ..PyClearCounters()
			Set tSC = ..Start(pRoutineList, pMetricList, pProcessList)
			Do ..PyStartWithScope(pPyClasses)
			If $System.Status.Equals(tSC,$$$ERRORCODE($$$MonitorMemoryAlloc)) {
				// Construct a more helpful error message.
				Set tSC = $$$EMBEDSC(..CheckAvailableMemory($ListLength(pProcessList),$ListLength(pRoutineList),1),tSC)
			}
			$$$ThrowOnError(tSC)
		} Else {
			// If the monitor was already running, clear the counters.
			Set tSC = ..ClearCounters()
			$$$ThrowOnError(tSC)
			If ..Paused {
				$$$ThrowOnError(..Resume())
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Clears all statistics, allowing collection to resume from 0 with the same settings and without needing to stop the monitor.
/// Based on <method>Pause</method> implementation, but with modern exception handling and code style.
ClassMethod ClearCounters() As %Status
{
	Set tSC = $$$OK
	Set tLocked = 0
	Try {
		// See if PERFMON is running (vs. line-by-line)
		If ($zu(84,8) = 1) && ($zu(84,16) = -1) {
			$$$ThrowStatus($$$ERROR($$$MonitorInUse))
		}
		Lock +^%SYS("MON-HOLD"):3
		If '$Test {
			$$$ThrowStatus($$$ERROR($$$MonitorInUse))
		}
		Set tLocked = 1
		if ($zu(84,8) = 0) {
			// Monitor is off.
			$$$ThrowStatus($$$ERROR($$$MonitorNotRunning))
		}
		// Finally: actually clear the counters.
		Do $zu(84,2)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If tLocked {
		Lock -^%SYS("MON-HOLD")
	}
	Quit tSC
}

ClassMethod IsRunning() As %Boolean [ CodeMode = expression ]
{
$zu(84,8) && $zu(84,1)
}

/// Overridden and minimally modified from parent implementation
ClassMethod Start(Routine As %List, Metric As %List, Process As %List) As %Status
{
	// Before attempting to start monitor, ensure we actually have object code for at least some element of Routine
	Set pointer = 0
	Set found = 0
	While $ListNext(Routine,pointer,routine) {
		Set rtnname = routine_".obj"
		For {
			Set data = ""
			Set more = $$LIST^%R(rtnname,32767,0,.data,.ctx)
			If (data '= "") {
				Set found = 1
				Quit
			}
		}
		If (found = 1) {
			Quit
		}
	}
	If 'found {
		Quit ..GetError("NoObjFound")
	}
	
	Quit ##super(.Routine,.Metric,.Process)
}

ClassMethod GetError(key As %String, args...)
{
	Quit $Case(key,
		"NoObjFound":$System.Status.Error($$$GeneralError,"Unable to start monitor: no object code exists for selected classes/routines. "_
			"Possible remediations: ensure that at least some class/routine is selected; ""view other"" for the routine and make sure that the "_
			".INT code actually has some content that could be covered."))
}

}
