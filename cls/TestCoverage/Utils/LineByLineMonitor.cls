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

/// Tracks current monitoring context and stops/starts or resets counters depending on whether it has changed
Method StartWithScope(pRoutineList As %List, pMetricList As %List, pProcessList As %List) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tDifferentScope = (..LastRoutineList '= pRoutineList) || (..LastMetricList '= pMetricList) || (..LastProcessList '= pProcessList)
		If tDifferentScope && ..Started {
			// If we need to track different routines/metrics/processes, need to stop the monitor before restarting with the new context.
			Do ..Stop()
			Set ..LastRoutineList = pRoutineList
			Set ..LastMetricList = pMetricList
			Set ..LastProcessList = pProcessList
		}
		
		If '..Started {
			Set tSC = ..Start(pRoutineList, pMetricList, pProcessList)
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

}

