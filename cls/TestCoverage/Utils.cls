Include (%occInclude, TestCoverage)

IncludeGenerator TestCoverage

Class TestCoverage.Utils
{

/// Removes all data for test coverage, code snapshots. Does not enforce referential integrity (for the sake of speed).
/// @API.Method
ClassMethod Clear() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tClasses("TestCoverage.Data.Aggregate.ByRun") = ""
		Set tClasses("TestCoverage.Data.Aggregate.ByCodeUnit") = ""
		Set tClasses("TestCoverage.Data.CodeSubUnit") = ""
		Set tClasses("TestCoverage.Data.CodeUnitMap") = ""
		Set tClasses("TestCoverage.Data.CodeUnit") = ""
		Set tClasses("TestCoverage.Data.Coverage") = ""
		Set tClasses("TestCoverage.Data.Run") = ""
		kill $$$PyMonitorResults
		
		Set tClass = ""
		For {
			Set tClass = $Order(tClasses(tClass))
			If (tClass = "") {
				Quit
			}
			Set tOneSC = $ClassMethod(tClass,"%KillExtent")
			Set tSC = $$$ADDSC(tSC,tOneSC)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Grants SQL SELECT permissions on all TestCoverage tables for the specified username/role
/// @API.Method
ClassMethod GrantSQLReadPermissions(pUsernameOrRole As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tTableList = ..GetTestCoverageTableList()
		$$$ThrowOnError($System.SQL.GrantObjPriv("SELECT",$ListToString(tTableList),"TABLE",pUsernameOrRole))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Revokes SQL SELECT permissions on all TestCoverage tables for the specified username/role
/// @API.Method
ClassMethod RevokeSQLReadPermissions(pUsernameOrRole As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tTableList = ..GetTestCoverageTableList()
		$$$ThrowOnError($System.SQL.RevokeObjPriv("SELECT",$ListToString(tTableList),"TABLE",pUsernameOrRole))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod GetTestCoverageTableList() As %List
{
	Set tSC = $$$OK
	&sql(select %DLIST(TABLE_SCHEMA || '.' || TABLE_NAME) into :tList from INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA %STARTSWITH 'TestCoverage')
	If (SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
	} ElseIf (SQLCODE = 100) {
		Set tList = ""
	}
	Quit tList
}

/// Given <var>pIntRoutines</var>, a $ListBuild list of .INT routine names, creates snapshots of the current state of the code of each. <br />
/// This is parallelized using <class>%SYSTEM.WorkMgr</class> for better performance. <br />
/// <var>pRelevantRoutines</var> is a $ListBuild list of .INT routines that map back to a .CLS or .MAC
/// routine with at least one executable line.
ClassMethod Snapshot(pIntRoutines As %List, pPyRoutines As %List, Output pRelevantRoutines As %List = "", Output pPyRelevantRoutines As %List = "") As %Status
{
	Set tSC = $$$OK
	Try {
		#dim tSnapshotQueue As %SYSTEM.WorkMgr
		Set tSnapshotQueue = $System.WorkMgr.Initialize(,.tSC)
		$$$ThrowOnError(tSC)
		
		Set tPointer = 0
		While $ListNext(pIntRoutines,tPointer,tIntRoutine) {
			Set tSC = tSnapshotQueue.Queue("##class(TestCoverage.Data.CodeUnit).GetCurrentByName",tIntRoutine_".INT")
			$$$ThrowOnError(tSC)
		}
		
		Set tSC = tSnapshotQueue.WaitForComplete()
		$$$ThrowOnError(tSC)



		// See which routines are actually relevant (one or more lines mapping back to a class with 1 or more executable lines)
		// There's no point in optimizing out .MAC routines; they'll always have code
		Set tPointer = 0
		While $ListNext(pIntRoutines,tPointer,tIntRoutine) {
			Set tOther = ##class(%Library.RoutineMgr).GetOther(tIntRoutine,"INT",-1)
			If (tOther '= "") && ($Piece(tOther,".",*) = "CLS") {
				// With the code already cached, this will be faster.
				// This also snapshots the compiled python routine with it if there is one
				#dim tCodeUnit As TestCoverage.Data.CodeUnit
				Set tSC = ##class(TestCoverage.Data.CodeUnit).GetCurrentByName(tOther,,.tCodeUnit)
				
				If $$$ISERR(tSC) {
					Continue // Non-fatal. Just skip it.
				}
				Set tName = tCodeUnit.Name // should be the same as tOther without the .cls, but if I have it already why not
				Set SnapshottedClasses(tName) = 1
				If ##class(TestCoverage.Manager).HasPython(tName) {
					// take a snapshot of the compiled python file 
					$$$ThrowOnError(##class(TestCoverage.Data.CodeUnit).GetCurrentByName(tName_".PY",,.tPyCodeUnit))

					// update the executable lines for the .cls file's python
					$$$ThrowOnError(tCodeUnit.UpdatePyExecutableLines(tName, .tPyCodeUnit))

					// update the pythonicity of the lines for the .cls file
					$$$ThrowOnError(tCodeUnit.UpdatePythonLines(tName, .tPyCodeUnit))

					// update the relevant python routines
					If ($BitCount(tPyCodeUnit.ExecutableLines, 1)) {
						set pPyRelevantRoutines = pPyRelevantRoutines _ $ListBuild(tName)
					} ElseIf '$BitCount(tCodeUnit.ExecutableLines,1) {
						// if there's no executable python and no executable objectscript, skip it 
						Continue
					}
					
				} ElseIf '$BitCount(tCodeUnit.ExecutableLines,1) {
					// Skip it - no executable lines.
					Continue
				}
			}
			
			Set pRelevantRoutines = pRelevantRoutines _ $ListBuild(tIntRoutine)
		}

		// Snapshot all the python routines and their corresponding classes that haven't already been snapshotted 
		Set tPointer = 0
		While $ListNext(pPyRoutines, tPointer, tPyRoutine) {
			If ('$Data(SnapshottedClasses(tPyRoutine))) {
				$$$ThrowOnError(##class(TestCoverage.Data.CodeUnit).GetCurrentByName(tPyRoutine_".CLS",,.tCodeUnit))
				$$$ThrowOnError(##class(TestCoverage.Data.CodeUnit).GetCurrentByName(tPyRoutine_".PY",,.tPyCodeUnit))
				$$$ThrowOnError(tCodeUnit.UpdatePyExecutableLines(tPyRoutine, .tPyCodeUnit))
				$$$ThrowOnError(tCodeUnit.UpdatePythonLines(tPyRoutine, .tPyCodeUnit))
				
				If ($BitCount(tPyCodeUnit.ExecutableLines, 1)) {
					set pPyRelevantRoutines = pPyRelevantRoutines _ $ListBuild(tPyRoutine)
				}
				Set SnapshottedClasses(tPyRoutine) = 1
			}
		}

		Write !
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns the "TestPath" string used to represent coverage collected at the test coverage run level.
/// In deployed mode, TestCoverage.inc does not exist, but dynamic SQL against persistent classes that include
/// it will try to include it in the generated class. This effectively makes the macro available as a method instead.
ClassMethod GetTestPathAllTests() [ CodeMode = objectgenerator ]
{
	Do %code.WriteLine(" Quit "_$$$QUOTE($$$TestPathAllTests))
	Quit $$$OK
}

/// Aggregates coverage results for test coverage run <var>pTestIndex</var>
ClassMethod AggregateCoverage(pTestIndex As %String) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Set tRun = ##class(TestCoverage.Data.Run).%OpenId(pTestIndex,,.tSC)
		$$$ThrowOnError(tSC)
		TSTART
		&sql(delete %NOLOCK %NOCHECK from TestCoverage_Data_Aggregate.ByRun where Run = :pTestIndex)
		If (SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
		}
		&sql(delete %NOLOCK %NOCHECK from TestCoverage_Data_Aggregate.ByCodeUnit where Run = :pTestIndex)
		If (SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
		}
		
		// Rollup: TestCoverage.Data.Coverage at 'all tests' level
		Set tRollupTestPath = ..GetTestPathAllTests()
		Set tRollupCalculated = (tRun.Detail > 0)
		If tRollupCalculated {
			&sql(delete %NOLOCK %NOCHECK from TestCoverage_Data.Coverage where Run = :pTestIndex and Calculated = 1)
			If (SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
			}
			&sql(
				insert %NOLOCK %NOCHECK into TestCoverage_Data.Coverage (
						Run,TestPath,Hash,Calculated,Ignore,
						CoveredLines)
				select :pTestIndex,:tRollupTestPath,Hash,1,0,
						MAX(CoveredLines)
					from TestCoverage_Data.Coverage
					where Run = :pTestIndex
						and Hash->Type in ('CLS','MAC')
						and Ignore = 0
						and Calculated = 0
					group by Hash
			)
			If (SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
			}
			
			// Copy any other metrics captured/requested as well.
			For i=1:1:tRun.Metrics.Count() {
				Set tMetric = tRun.Metrics.GetAt(i)
				If $System.SQL.IsReservedWord(tMetric) {
					// e.g., "Time" -> "_Time"
					Set tMetric = "_"_tMetric
				}
				Set tSQLStatement = "INSERT %NOLOCK %NOCHECK INTO TestCoverage_Data.Coverage_"_tMetric_" "_
					"(Coverage,element_key,"_tMetric_") "_
					"SELECT target.ID,metric.element_key,SUM(metric."_tMetric_") "_
					"FROM TestCoverage_Data.Coverage source "_
					"JOIN TestCoverage_Data.Coverage_"_tMetric_" metric "_
					"	ON metric.Coverage = source.ID "_
					"JOIN TestCoverage_Data.Coverage target "_
					"	ON target.Hash = source.Hash "_
					"	AND target.Run = source.Run "_
					"WHERE source.Run = ? "_
					"	AND source.Ignore = 0"_
					"	AND source.Calculated = 0"_
					"	AND target.TestPath = ?"_
					"GROUP BY target.ID,metric.element_key"
				
				#dim tResult As %SQL.StatementResult
				Set tResult = ##class(%SQL.Statement).%ExecDirect(,tSQLStatement,pTestIndex,tRollupTestPath)
				If (tResult.%SQLCODE < 0) {
					Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
				}
			}
		}
		
		// Aggregate by code unit
		&sql(
			insert %NOLOCK %NOCHECK into TestCoverage_Data_Aggregate.ByCodeUnit (
					Run,
					CodeUnit,
					ExecutableLines,
					CoveredLines,
					ExecutableMethods,
					CoveredMethods,
					RtnLine,
					_Time,
					TotalTime)
			select :pTestIndex,
					CodeUnit,
					TestCoverage.BIT_COUNT(ExecutableLines,1), -- Count of executable lines
					TestCoverage.BIT_COUNT(CoveredLines,1), -- Count of lines that were covered
					
					-- Count of executable methods:
					-- These have at least one executable line
					NVL((select SUM(CASE
							TestCoverage.BIT_COUNT(TestCoverage.BITWISE_AND(
								method.Mask,ExecutableLines),1)
							WHEN 0 THEN 0
							ELSE 1 END)
						from TestCoverage_Data_CodeSubUnit.Method method
						where method.Parent = CodeUnit),0) ExecutableMethods,
						
					-- Count of covered methods:
					-- These have at least one line that was covered
					NVL((select SUM(CASE
							TestCoverage.BIT_COUNT(TestCoverage.BITWISE_AND(
								method.Mask,CoveredLines),1)
							WHEN 0 THEN 0
							ELSE 1 END)
						from TestCoverage_Data_CodeSubUnit.Method method
						where method.Parent = CodeUnit),0) CoveredMethods,
						
					-- Other metrics
					RtnLine, _Time, TotalTime
			from (
				select Hash CodeUnit,
					Hash->ExecutableLines ExecutableLines,
					TestCoverage.BITWISE_AND(Hash->ExecutableLines,CoveredLines) CoveredLines,
					(select SUM(RtnLine)
						from TestCoverage_Data.Coverage_RtnLine r
						where r.Coverage = coverage.ID) RtnLine,
					(select SUM(_Time)
						from TestCoverage_Data.Coverage__Time t
						where t.Coverage = coverage.ID) _Time,
					(select SUM(TotalTime)
						from TestCoverage_Data.Coverage_TotalTime tt
						where tt.Coverage = coverage.ID) TotalTime
				from TestCoverage_Data.Coverage coverage
				where Run = :pTestIndex
					and Calculated = :tRollupCalculated
					and Ignore = 0
					and Hash->Type in ('CLS','MAC')
					and TestPath = :tRollupTestPath -- This is guaranteed to exist, so optimize by using it rather than aggregating.
				
				-- Supported by index:
				-- Index MeaningfulCoverageData On (Run, Calculated, Ignore, Hash, TestPath) [ Data = CoveredLines, Unique ];
			)
			order by CodeUnit
		)
		If (SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
		}
		
		// Aggregate for full run
		&sql(
			insert %NOLOCK %NOCHECK into TestCoverage_Data_Aggregate.ByRun
				(Run, ExecutableLines ,CoveredLines,
					ExecutableMethods, CoveredMethods,
					RtnLine, _Time, TotalTime)
			select Run, SUM(ExecutableLines), SUM(CoveredLines),
				SUM(ExecutableMethods), SUM(CoveredMethods),
				SUM(RtnLine), SUM(_Time), SUM(TotalTime)
			from TestCoverage_Data_Aggregate.ByCodeUnit
			where Run = :pTestIndex
			group by Run
		)
		If (SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
		}
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) {
		TROLLBACK 1
	}
	Quit tSC
}

/// Returns the test coverage measured for <var>pRunIndex</var>, as a percentage, or an empty string if no data was found.
ClassMethod GetAggregateCoverage(pRunIndex As %Integer) As %Numeric
{
	Set tCoveragePercent = ""
	&sql(select ROUND((SUM(CoveredLines)/SUM(ExecutableLines))*100,2) into :tCoveragePercent
			from TestCoverage_Data_Aggregate.ByRun where ExecutableLines > 0 and Run = :pRunIndex)
	If (SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
	} ElseIf (SQLCODE = 100) {
		Set tCoveragePercent = ""
	}
	Quit tCoveragePercent
}

/// Displays aggregate coverage for <var>pRunIndex</var>
ClassMethod ShowAggregateCoverage(pRunIndex As %String)
{
	Set tCoveragePercent = ..GetAggregateCoverage(pRunIndex)
	If (tCoveragePercent = "") {
		Write !,"No code coverage found (!)"
	} Else {
		Write !,"Code coverage: ",tCoveragePercent,"%"
	}
	Write !
}

/// For a class, <var>pClassName</var>, with code in <var>pDocumentText</var> as an integer-subscripted array of lines,
/// returns an array (<var>pExecutableFlags</var>) subscripted by line with boolean flags indicating whether the corresponding line is executable.
ClassMethod GetClassLineExecutableFlags(pClassName As %String, ByRef pDocumentText, Output pExecutableFlags)
{
	// Now process the class itself.
	Set tInMethod = 0
	Set tMethodStarted = 0
	For tDocLine=1:1:$Get(pDocumentText) {
		Set tLine = pDocumentText(tDocLine)
		If 'tInMethod {
			Set pExecutableFlags(tDocLine) = 0
		
			// Extract line offset of method in class
			Set tStart = $Extract(tLine,1,6)
			If (tStart = "ClassM") || (tStart = "Method") {
				Set tMethod = $Piece($Piece(tLine,"(")," ",2)
				Kill tMethodCode
				Set tInMethod = 1
			}
		} Else {
			If $Extract(tLine) = "{" {
				Set tMethodStarted = 1
				Set tMethodMap(tMethod) = tDocLine + 1
				Set pExecutableFlags(tDocLine) = 0
			} ElseIf $Extract(tLine) = "}" {
				Set tInMethod = 0
				Set tMethodStarted = 0
				Set pExecutableFlags(tDocLine) = 0
				
				Set tCodeMode = $$$defMemberKeyGet(pClassName,$$$cCLASSmethod,tMethod,$$$cMETHcodemode)
				If $Data(^rMAP(pClassName,"CLS","INT",tMethod)) || (tCodeMode = $$$cMETHCODEMODEGENERATOR) || (tCodeMode = $$$cMETHCODEMODEOBJECTGENERATOR) {
					Set tSourceStream = ##class(%Stream.GlobalCharacter).%New()
					Set tSourceStream.LineTerminator = $c(13,10)
					For tMethodLine=1:1:$Get(tMethodCode) {
						Do tSourceStream.WriteLine(tMethodCode(tMethodLine))
					}
					
					Set tSC = ##class(%Library.SyntaxColorReader).FromCode(tSourceStream,"COS","A",.tSCReader)
					$$$ThrowOnError(tSC)
					
					Set tOffset = tMethodMap(tMethod)
					Set tLine = 0
					While tSCReader.NextLine(.tLineTokenList) {
						If (tLine = 0) && (tCodeMode = $$$cMETHCODEMODEEXPRESSION) {
							// Simulate a normal method.
							Set tLineTokenList = $ListBuild($ListBuild("COS","Command","Quit"))_tLineTokenList
						}
						Set pExecutableFlags(tOffset + tLine) = ..LineIsExecutable(tLineTokenList,.tPreviousLineWasExecutable)
						If (tPreviousLineWasExecutable) {
							Set pExecutableFlags(tOffset + tLine - 1) = pExecutableFlags(tOffset + tLine-1) || tPreviousLineWasExecutable
						}
						Set tLine = tLine + 1
					}
				} Else {
					// Method is not executable.
					Set tOffset = tMethodMap(tMethod)
					For tMethodLine = 1:1:$Get(tMethodCode) {
						Set pExecutableFlags(tOffset + tMethodLine) = 0
					}
				}
			} ElseIf tMethodStarted {
				// Aggregate lines from the method body to look at later.
				Set tMethodCode($i(tMethodCode)) = tLine
			} 
		}
	}
}

ClassMethod CodeArrayToList(ByRef pCodeArray, Output pDocumentText As %List)
{
	set pDocumentText = ""
	for i=1:1:$get(pCodeArray(0)) {
		set pDocumentText = pDocumentText _ $ListBuild(pCodeArray(i))
	}
	quit
}

/// returns a python tuple of (line to method info, method map info) 
/// linetomethodinfo: a python builtins list where the item at index i is the name of the method that line i is a part of 
/// methodmapinfo: a python builtins dict with key = method name, value = the line number of its definition
ClassMethod GetPythonMethodMapping(pDocumentText) [ Language = python ]
{
	import iris
	import ast 
	source_lines = iris.cls('%SYS.Python').ToList(pDocumentText)

	source = '\n'.join(source_lines)
	tree = ast.parse(source)
	line_function_map = [None] * (len(source_lines)+2)
	method_map = {} # dictionary from the method name to its start and ending line number

	class FunctionMapper(ast.NodeVisitor):
		def __init__(self):
			self.current_class = None
			self.current_function = None
			self.outermost_function = None # for objectscript purposes, we only care about the outer level functions/methods

		def visit_ClassDef(self, node):
			prev_class = self.current_class
			self.current_class = node.name
			self.generic_visit(node)
			self.current_class = prev_class

		def visit_FunctionDef(self, node):
			if self.outermost_function is None:
				self.outermost_function = node.name
				start_line = node.lineno
				end_line = self.get_end_line(node)
				method_map[node.name] = (start_line, end_line)

			self.current_function = node.name
			for lineno in range(node.lineno, node.end_lineno + 1):
				line_function_map[lineno-1] = self.outermost_function

			self.generic_visit(node)
			self.current_function = None
			if self.outermost_function == node.name:
				self.outermost_function = None
		@staticmethod
		def get_end_line(node):
			return max(child.lineno for child in ast.walk(node) if hasattr(child, 'lineno'))

	FunctionMapper().visit(tree)
	return (line_function_map, method_map)
}

/// returns a python list with a 1 or 0 for subscript i indicating if line i is executable or not
ClassMethod GetPythonLineExecutableFlags(pDocumentText) [ Language = python ]
{
	import iris
	import ast 
	source_lines = iris.cls('%SYS.Python').ToList(pDocumentText)
	source_lines = [line + "\n" for line in source_lines]  # contains a list of each line of the source code

	# create the abstract syntax tree for the code, and walk through it, getting each line of code in its context
	source = ''.join(source_lines)
	tree = ast.parse(source)
	executable_lines = set() # stores the 1-indexed line numbers of the executable lines 

	class ExecutableLineVisitor(ast.NodeVisitor):
		def __init__(self):
			self.function_depth = 0

		def visit(self, node):
			if hasattr(node, 'lineno'):
				
				# decorators for functions and class definitions are executable
				if isinstance(node, (ast.FunctionDef, ast.ClassDef, ast.AsyncFunctionDef)):
					decorators = [element.id for element in node.decorator_list]
					num_decorators = len(decorators)
					for i, element in enumerate(decorators):
						conjectured_line = (node.lineno-1)-num_decorators+i # change this back if the line numbers aren't 0 indexed
						if "@" + element in source_lines[conjectured_line]:
							executable_lines.add(conjectured_line+1) # because back to 1-indexing
					executable_lines.add(node.lineno)
				elif isinstance(node, (ast.Call,
										ast.Return, ast.Assign, ast.AugAssign, ast.AnnAssign,
										ast.For, ast.AsyncFor, ast.While, ast.If, ast.With, 
										ast.AsyncWith, ast.Raise, ast.Try, ast.Assert, 
										ast.Import, ast.ImportFrom, ast.Pass, 
										ast.Break, ast.Continue, ast.Delete, ast.Yield, 
										ast.YieldFrom, ast.Await, ast.Nonlocal)): # all executable (determined manually)
					executable_lines.add(node.lineno)
				elif isinstance(node, ast.ExceptHandler): # except (but not finally) is executable
					executable_lines.add(node.lineno) 
				elif isinstance(node, ast.Expr) and not isinstance(node.value, ast.Constant): # expressions that aren't docstrings are executable
					executable_lines.add(node.lineno)
			self.generic_visit(node)
	ExecutableLineVisitor().visit(tree)

	output = [0] * (len(source_lines)+1)
	for line in executable_lines:
		output[line] = 1
	output[1] = 0 # manually set the class definition to be not executable 
	def print_executable_lines():
		for i, line in enumerate(source_lines, start=1):
			is_exec = output[i]
			print(f"{i:2d} {'*' if is_exec else ' '} {line.rstrip()}")
	# print_executable_lines()
	return output
}

/// For a routine (.MAC/.INT) with code in <var>pDocumentText</var> as an integer-subscripted array of lines,
/// returns an array (<var>pExecutableFlags</var>) subscripted by line with boolean flags indicating whether the corresponding line is executable.
ClassMethod GetRoutineLineExecutableFlags(ByRef pDocumentText, Output pExecutableFlags)
{
	Set tSourceStream = ##class(%Stream.GlobalCharacter).%New()
	Set tSourceStream.LineTerminator = $c(13,10)
	For tDocLine=1:1:$Get(pDocumentText) {
		Do tSourceStream.WriteLine(pDocumentText(tDocLine))
	}
	Set tSC = ##class(%Library.SyntaxColorReader).FromCode(tSourceStream,"COS","A",.tSCReader)
	$$$ThrowOnError(tSC)
	
	Set tLine = 1
	While tSCReader.NextLine(.tLineTokenList) {
		Set pExecutableFlags(tLine) = ..LineIsExecutable(tLineTokenList,.tPreviousLineWasExecutable)
		If (tPreviousLineWasExecutable) {
			Set pExecutableFlags(tLine-1) = 1
		}
		Set tLine = tLine + 1
	}
}

/// Given <var>pLineTokenList</var> with a list of tokens from a single line (from <class>%Library.SyntaxColorReader</class>),
/// returns 1 if the line is "executable" (meaning the line-by-line monitor will likely be able to detect whether it was executed) or not.
/// In certain edge cases, <var>pPreviousLineWasExecutable</var> may be set to 1 to correct the previous line's result.
ClassMethod LineIsExecutable(pLineTokenList As %List, Output pPreviousLineWasExecutable As %Boolean) As %Boolean [ Private ]
{
	Set tExecutable = 0
	Set tPointer = 0
	Set pPreviousLineWasExecutable = 0
	While $ListNext(pLineTokenList,tPointer,tLineToken) {
		Set tExecutable = tExecutable || ..LineTokenIsExecutable(tLineToken, .tLineState, .pPreviousLineWasExecutable)
		If (tExecutable) {
			Quit
		}
	}
	Quit tExecutable
}

/// Given <var>pLineToken</var> describing a single token on a given line (from <class>%Library.SyntaxColorReader</class>), and <var>pState</var> passed between calls,
/// returns 1 if the line is "executable" (meaning the line-by-line monitor will likely be able to detect whether it was executed) or not.
/// In certain edge cases, <var>pPreviousLineWasExecutable</var> may be set to 1 to correct the previous line's result.
ClassMethod LineTokenIsExecutable(pLineToken As %List, ByRef pState, ByRef pPreviousLineWasExecutable As %Boolean) As %Boolean [ Private ]
{
	If '$Data(pState) {
		Set pState("IsDim") = 0
		Set pState("PastWhiteSpace") = 0
		Set pState("DoCommand") = 0
	}
	Set tExecutable = 0
	Set tTokenType = $ListGet(pLineToken,2)
	Set tTokenName = $ListGet(pLineToken,3)
	Set tTokenLower = $ZConvert(tTokenName,"L")
	If (tTokenType = "Pre-Processor Command") {
		If (tTokenLower = "dim") {
			Set pState("IsDim") = 1
		}
	} ElseIf (tTokenType = "Command") {
		If pState("IsDim") {
			// Not executable unless there's an "="
		} Else {
			If (tTokenLower = "do") {
				// Special handling for do: is not executable if the line has just:
				// Do {
				// Will check later for non-whitespace/comment/brace tokens following "Do" on a given line
				Set pState("DoCommand") = 1
			} ElseIf (tTokenLower = "catch") {
				/*
				"Catch" is tricky.
				Given:
					}
					catch e {
				
				The line by line monitor will flag "}" as executed (if an exception was not thrown),
				but will never flag never "catch e {" as executed.
				
				Similarly,
					} catch e {
				gets credit as being run if no exception is thrown.
				*/
				 
				If pState("PastWhiteSpace") {
					Set tExecutable = 1
				} Else {
					Set pPreviousLineWasExecutable = 1
				}
			} ElseIf (tTokenLower '= "try") && (tTokenLower '[ "else") {
				Set tExecutable = 1
			}
		}
	} ElseIf (tTokenType = "Operator") {
		If pState("IsDim") {
			// #dim is executable if there is later an "Equals" operator
			If (tTokenName = "=") {
				Set tExecutable = 1
			}
		}
	} ElseIf (tTokenType = "Macro") {
		If (tTokenLower [ "throw") || (tTokenLower = "generate") {
			// $$$ThrowStatus / $$$ThrowOnError commonly appears as on lines with no explicit command.
			// Treat as executable.
			// $$$GENERATE(...) is also executable.
			Set tExecutable = 1
		}
	} ElseIf pState("DoCommand") && (tTokenType '= "White Space") && (tTokenType '= "Brace") && (tTokenType '= "Comment") {
		Set tExecutable = 1
	}
	If (tTokenType '= "White Space") {
		Set pState("PastWhiteSpace") = 1
	}
	Quit tExecutable
}

/// Wrapper for %Monitor.System.LineByLine:Result to present metrics in a format more usable from SQL (as a table-valued function).
Query LineByLineMonitorResult(pRoutine As %String) As %Query(ROWSPEC = "LineNumber:%Integer,LineCovered:%Boolean,RtnLine:%Integer,Time:%Numeric,TotalTime:%Numeric") [ SqlProc ]
{
}

ClassMethod LineByLineMonitorResultExecute(ByRef qHandle As %Binary, pRoutine As %String) As %Status
{
	Quit ##class(%Monitor.System.LineByLine).ResultExecute(.qHandle,pRoutine)
}

ClassMethod LineByLineMonitorResultFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ResultExecute ]
{
	Set tLine = $Piece(qHandle,"^",2)
	Set tSC = ##class(%Monitor.System.LineByLine).ResultFetch(.qHandle,.Row,.AtEnd)
	If 'AtEnd {
		Set tCounters = $List(Row,1)
		Set tRtnLine = $ListGet(tCounters,1)
		Set tTime = $ListGet(tCounters,2)
		Set tTotalTime = $ListGet(tCounters,3)
		
		Set tRtnLines = $Case(tRtnLine,0:0,"":0,:tRtnLine)
		Set tLineCovered = (tRtnLines > 0)
		Set tTime = $Case(tTime,0:0,"":0,:tTime)
		Set tTotalTime = $Case(tTotalTime,0:0,"":0,:tTotalTime)
		Set Row = $ListBuild(tLine,tLineCovered,tRtnLines,tTime,tTotalTime)
	}
	Quit $$$OK
}

ClassMethod LineByLineMonitorResultClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = ResultExecute ]
{
	Quit ##class(%Monitor.System.LineByLine).ResultClose(.qHandle)
}

}
