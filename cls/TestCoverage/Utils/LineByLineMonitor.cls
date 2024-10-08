Include (%occErrors, TestCoverage)

/// Wrapper around %Monitor.System.LineByLine to ensure that the monitor is stopped when it should be, and also
/// to wrap the decision about whether to stop/start the monitor or to just clear counters.
Class TestCoverage.Utils.LineByLineMonitor Extends %Monitor.System.LineByLine
{

/// True if the line-by-line monitor has been started.
Property Started As %Boolean [ Calculated, Private, ReadOnly ];

/// True if the Python trace has been set 
Property PyStarted As %Boolean [ Calculated, Private, ReadOnly ];

Method StartedGet() As %Boolean [ CodeMode = expression ]
{
$zu(84,8)
}

Method PyStartedGet() As %Boolean [ Language = python ]
{
	import sys
	return sys.gettrace() is not None
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

Property LastPythonList As %List [ Private ];

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
		class_name = frame.f_globals.get('__name__', None)  # Use get to avoid KeyError
		# extracts the line number 
		line_no = frame.f_lineno 
		if class_name and class_name in tCoverageClasses and line_no > 1: # if this is in a covered class 
			tGlob = iris.gref('^IRIS.Temp.TestCoveragePY') # python doesn't have macros -- this is $$$PyMonitorResults
			# $$$PyMonitorResults(classname, linenumber) = the number of times that linenumber in that class was covered 

			curCount = tGlob.get([class_name, line_no]) 
			if not curCount:
				curCount = 0
			tGlob[class_name, line_no] = curCount + 1 
			
		return my_tracer
	settrace(my_tracer)
}

ClassMethod PyClearCounters()
{
	Kill $$$PyMonitorResults
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
		Set tDifferentScope = (..LastRoutineList '= pRoutineList) || (..LastMetricList '= pMetricList) || (..LastProcessList '= pProcessList) || (..LastPythonList '= pPyClasses)
		If tDifferentScope && (..Started || ..PyStarted) {
			// If we need to track different routines/metrics/processes, need to stop the monitor before restarting with the new context.
			If (..Started) {
				Do ..Stop()
			}
			Do ..PyStop() // setting the trace to None can and should always be done 
			Set ..LastRoutineList = pRoutineList
			Set ..LastMetricList = pMetricList
			Set ..LastProcessList = pProcessList
			Set ..LastPythonList = pPyClasses
		}
		
		// take care of starting the ObjectScript Monitor
		If ('..Started && $ListLength(pRoutineList) '= 0) {
			Set tSC = ..Start(pRoutineList, pMetricList, pProcessList)
			If $System.Status.Equals(tSC,$$$ERRORCODE($$$MonitorMemoryAlloc)) {
				// Construct a more helpful error message.
				Set tSC = $$$EMBEDSC(..CheckAvailableMemory($ListLength(pProcessList),$ListLength(pRoutineList),1),tSC)
			}
			$$$ThrowOnError(tSC)
		} Else {
			// If the monitor was already running, clear the counters.
			if (..Started) {
				Set tSC = ..ClearCounters()
				$$$ThrowOnError(tSC)
			}
			If (..Paused && $ListLength(pRoutineList) '= 0){
				$$$ThrowOnError(..Resume())	
			}
		}

		If ('..PyStarted && $ListLength(pPyClasses) '= 0) {
			// whether we're resuming or restarting, we either way want to clear counters
			// since StoreIntCoverage should have already 
			Do ..PyClearCounters()
			Do ..PyStartWithScope(pPyClasses)
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
