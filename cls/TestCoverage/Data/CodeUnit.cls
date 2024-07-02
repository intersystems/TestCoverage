Include %syGluedef

/// Represents a single unit of code (class, routine), which may be generated or user-written.
/// TODO: Create subclasses representing classes, routines, and intermediate code.
Class TestCoverage.Data.CodeUnit Extends %Persistent
{

/// Hash had better be unique...
Index Hash On Hash [ IdKey ];

/// Uniquely identifies a unit of code by name, type, and hash.
Index NameTypeHash On (Name, Type, Hash) [ Data = ExecutableLines, Unique ];

/// Name of the code unit
Property Name As %String(MAXLEN = 255) [ Required ];

/// Type (2 or 3-letter extension) of the code unit
Property Type As TestCoverage.DataType.RoutineType [ Required ];

/// Hash of the code unit; for methods for determining this, see <method>GetCurrentHash</method>
Property Hash As %String [ Required ];

/// Lines (with position in list corresponding to line number)
Property Lines As list Of %String(MAXLEN = "", STORAGEDEFAULT = "array");

/// Bitstring of (line # is executable)
Property ExecutableLines As TestCoverage.DataType.Bitstring;

/// For classes, map of method names in the code to their associated line numbers
/// For routines, map of labels to associated line numbers
/// For python, map of method names to associated starting line number
Property MethodMap As array Of %Integer;

/// Only for python: map of method names to associated ending line number of the method 
Property MethodEndMap As array Of %Integer;

/// For classes, map of line numbers in code to associated method names
/// For routines, map of labels to associated line numbers
Property LineToMethodMap As array Of %Dictionary.CacheIdentifier [ Private ];

/// Set to true if this class/routine is generated
Property Generated As %Boolean [ InitialExpression = 0 ];

/// Methods, branches, etc. within this unit of code.
Relationship SubUnits As TestCoverage.Data.CodeSubUnit [ Cardinality = children, Inverse = Parent ];

/// Gets the current instance of a unit of code by its internal name (e.g., SomePackage.ClassName.CLS or SomePackage.ClassName.1.INT)
ClassMethod GetCurrentByName(pInternalName As %String, pSourceNamespace As %String = {$Namespace}, Output pCodeUnit As TestCoverage.Data.CodeUnit, ByRef pCache) As %Status
{
	Set tSC = $$$OK
	Set tOriginalNamespace = $Namespace
	Set tInitTLevel = $TLevel
	Try {
		Set pCodeUnit = $$$NULLOREF
		
		New $Namespace
		Set $Namespace = pSourceNamespace
		
		// Figure out the hash.
		Set pInternalName = ##class(%Studio.SourceControl.Interface).normalizeName(pInternalName)
		Set tName = $Piece(pInternalName,".",1,*-1)
		Set tType = $Piece(pInternalName,".",*)
		
		TSTART
		// GetCurrentHash may store the current version of the routine,
		// so start the transaction before calling it.
		$$$ThrowOnError(..GetCurrentHash(tName,tType,.tHash,.tCodeArray,.pCache))
			
		// Ensure mappings from the specified name/type/hash are up to date.
		#dim tMapToResult As %SQL.StatementResult
		Set tMapToResult = ##class(%SQL.Statement).%ExecDirect(,
			"select distinct ToHash from TestCoverage_Data.CodeUnitMap where FromHash = ?",tHash)
		If (tMapToResult.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tMapToResult.%SQLCODE,tMapToResult.%Message)
		}
		Set tNeedsUpdate = 0
		While tMapToResult.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set tKnownHash = tMapToResult.%GetData(1)
			Set tMapToUnit = ..HashOpen(tKnownHash,,.tSC)
			$$$ThrowOnError(tSC)
			$$$ThrowOnError(..GetCurrentByName(tMapToUnit.Name_"."_tMapToUnit.Type,pSourceNamespace,.tUpdatedUnit,.pCache))
			If (tUpdatedUnit.Hash '= tKnownHash) {
				//Clear out old data and flag the need for an update.
				Set tNeedsUpdate = 1
				&sql(delete from TestCoverage_Data.CodeUnitMap where ToHash = :tKnownHash)
				If (SQLCODE < 0) {
					Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
				}
			}
		}
		
		Set $Namespace = tOriginalNamespace
		If ..NameTypeHashExists(tName,tType,tHash,.tID) {
			Set pCodeUnit = ..%OpenId(tID,,.tSC)
			$$$ThrowOnError(tSC)
			If tNeedsUpdate {
				$$$ThrowOnError(pCodeUnit.UpdateSourceMap(pSourceNamespace,.pCache))
			}
			TCOMMIT
			Quit
		}
		
		Set $Namespace = pSourceNamespace
		
		If (tType = "CLS") {
			Do ##class(TestCoverage.Utils).GetClassLineExecutableFlags(tName,.tCodeArray,.tExecutableFlags)
		} ElseIf ((tType = "INT") || (tType = "MAC")) {
			Do ##class(TestCoverage.Utils).GetRoutineLineExecutableFlags(.tCodeArray,.tExecutableFlags)
		} ElseIf (tType="PY") {
			Do ##class(TestCoverage.Utils).CodeArrayToList(.tCodeArray, .pDocumentText) 
			Set tExecutableFlagsPyList = ##class(TestCoverage.Utils).GetPythonLineExecutableFlags(pDocumentText)
			Kill tExecutableFlags
			for i=1:1:tExecutableFlagsPyList."__len__"()-1 {
				set tExecutableFlags(i) = tExecutableFlagsPyList."__getitem__"(i)
			}
		}
		Else {
			return $$$ERROR($$$GeneralError,"File type not supported")
		}
		
		Set $Namespace = tOriginalNamespace
		Set pCodeUnit = ..%New()
		Set pCodeUnit.Name = tName
		Set pCodeUnit.Type = tType
		Set pCodeUnit.Hash = tHash
		
		Set tBitString = ""
		For tLine=1:1:$Get(tCodeArray,0) {
			Set $Bit(tBitString,tLine) = $Get(tExecutableFlags(tLine),0)
		}
		Set pCodeUnit.ExecutableLines = tBitString
		
		If (tType = "CLS") {
			Set pCodeUnit.Generated = ($$$comClassKeyGet(tName,$$$cCLASSgeneratedby) '= "")
		}
		
		
		If (tType = "PY") {
			Set ClassName = $Piece(tName,".", *)
			Set tMethodInfo = ##class(TestCoverage.Utils).GetPythonMethodMapping(pDocumentText, ClassName)
			Set tLineToMethodInfo = tMethodInfo."__getitem__"(0)
			Set tMethodMapInfo = tMethodInfo."__getitem__"(1)
			for i=1:1:$listlength(pDocumentText) {
				Set tMethod = tLineToMethodInfo."__getitem__"(i)
				Do pCodeUnit.LineToMethodMap.SetAt(tMethod,i)
			}
			Set iterator = tMethodMapInfo."__iter__"()
			for i=1:1:tMethodMapInfo."__len__"() {
				Set tMethod = iterator."__next__"()
				Set tStartEnd = tMethodMapInfo."__getitem__"(tMethod)
				Set tStartLine = tStartEnd."__getitem__"(0)
				Set tEndLine = tStartEnd."__getitem__"(1)
				Do pCodeUnit.MethodMap.SetAt(tStartLine,tMethod)
				Do pCodeUnit.MethodEndMap.SetAt(tEndLine, tMethod)

				Set tMethodMask = ""
				for j = tStartLine:1:tEndLine {
					Set $Bit(tMethodMask,j) = 1
				}
				Set tMethodSignature = $list(pDocumentText, tStartLine)
				Set tSubUnit = ##class(TestCoverage.Data.CodeSubUnit.Method).%New()
				Set tSubUnit.Name = tMethod
				Set tSubUnit.DisplaySignature = tMethodSignature
				Set tSubUnit.Mask = tMethodMask
				Do pCodeUnit.SubUnits.Insert(tSubUnit)
			}
		}
		Else {
			Set tMethod = ""
			Set tMethodSignature = ""
			Set tMethodMask = ""
			For tLineNumber=1:1:$Get(tCodeArray,0) {
				Set tLine = tCodeArray(tLineNumber)
				Do pCodeUnit.Lines.Insert(tLine)
				
				If (tType = "CLS") {
					// Extract line offset of methods in classes
					Set tStart = $Piece(tLine," ")
					If (tStart = "ClassMethod") || (tStart = "Method") {
						Set tMethod = $Piece($Piece(tLine,"(")," ",2)
						Set tMethodSignature = tLine
						Do pCodeUnit.MethodMap.SetAt(tLineNumber,tMethod)
						Do pCodeUnit.LineToMethodMap.SetAt(tMethod,tLineNumber)
					} ElseIf ($Extract(tStart) = "{") {
						// Ignore the opening bracket for a method.
					} ElseIf ($Extract(tStart) = "}") && (tMethod '= "") {
						// End of method. Add method subunit to class.
						Set tSubUnit = ##class(TestCoverage.Data.CodeSubUnit.Method).%New()
						Set tSubUnit.Name = tMethod
						Set tSubUnit.DisplaySignature = tMethodSignature
						Set tSubUnit.Mask = tMethodMask
						Do pCodeUnit.SubUnits.Insert(tSubUnit)
						Set tMethod = ""
						Set tMethodSignature = ""
						Set tMethodMask = ""
					} ElseIf (tMethod '= "") {
						Set $Bit(tMethodMask,tLineNumber) = 1
					}
				} 
				Else {
					// Extract line offset of labels in routines
					If ($ZStrip($Extract(tLine),"*PWC") '= "") {
						Set tLabel = $Piece($Piece(tLine," "),"(")
						Do pCodeUnit.MethodMap.SetAt(tLineNumber,tLabel)
						Do pCodeUnit.LineToMethodMap.SetAt(tLabel,tLineNumber)
					}
				}
			}
		}
		
		
		Set tSC = pCodeUnit.%Save()
		If $$$ISERR(tSC) && $System.Status.Equals(tSC,$$$ERRORCODE($$$IDKeyNotUnique)) {
			// Some other process beat us to it.
			Set tSC = $$$OK
			Set pCodeUnit = ..%OpenId(pCodeUnit.Hash,,.tSC)
			Quit
		}
		// For non-class (e.g., .MAC/.INT) code, it's possible that something else generated it,
		// so update the mappings between generated and the thing that generated it.
		If (tType '= "CLS") {
			$$$ThrowOnError(pCodeUnit.UpdateSourceMap(pSourceNamespace,.pCache))
		}
		TCOMMIT
	} Catch e {
		Set pCodeUnit = $$$NULLOREF
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) {
		TROLLBACK 1
	}
	Quit tSC
}

Method UpdateSourceMap(pSourceNamespace As %String, ByRef pCache) As %Status
{
	Set tSC = $$$OK
	Try {
		
		// First, build local array (tMap) of all maps from the .INT file to other files.
		If (..Type = "INT") {
			For tLineNumber=1:1:..Lines.Count() {
				Set tLine = ..Lines.GetAt(tLineNumber)
				Set tSC = ##class(%Studio.Debugger).SourceLine(..Name, tLineNumber, 1, tLineNumber,	$Length(tLine), pSourceNamespace, .tMap)
				$$$ThrowOnError(tSC)
				
				If $Data(tMap("CLS",1),tData1) && $Data(tMap("CLS",2),tData2) {
					Set $ListBuild(tClass,tMethod,tLine1) = tData1
					Set tLine2 = $List(tData2,3)
					
					// Skip stub classes
					If $$$defClassKeyGet(tClass,$$$cCLASShidden) && ($$$defClassKeyGet(tClass,$$$cCLASSdeployed) = 2) {
						Continue
					}
					
					// Generated method lines are not correctly mapped to the generator method's lines.
					// Therefore, skip mapping generator methods directly from INT to CLS.
					// Instead, these are mapped from INT to MAC and MAC to CLS (transitively).
					If '$Data(tCodeModeCache(tClass,tMethod),tCodeMode) {
						Set tCodeMode = $$$comMemberKeyGet(tClass,$$$cCLASSmethod,tMethod,$$$cMETHcodemode)
						Set tCodeModeCache(tClass,tMethod) = tCodeMode
					}
					If (tCodeMode = $$$cMETHCODEMODEGENERATOR) || (tCodeMode = $$$cMETHCODEMODEOBJECTGENERATOR) {
						Continue
					}
					
					Set tFullMap(tLineNumber) = $ListBuild("CLS",tClass,tMethod,tLine1,tLine2)
					Set tSourceUnits(tClass_".CLS") = ""
				} ElseIf $Data(tMap("MAC",1),tData1) && $Data(tMap("MAC",2),tData2) {
					Set tRoutine = $ListGet(tData1)
					Set tLine1 = $ListGet(tData1,3)
					Set tLine2 = $ListGet(tData2,3)
					Set tFullMap(tLineNumber) = $ListBuild("MAC",tRoutine,"",tLine1,tLine2)
					Set tSourceUnits(tRoutine_".MAC") = ""
				}
			}
		}
		If (..Type = "PY") {
			
			set tClass = ..Name
			Set tSourceUnits(tClass_".CLS") = ""
			$$$ThrowOnError(..GetCurrentByName(tClass _ ".CLS", pSourceNamespace, .pCLSCodeUnit, .pCLSCache))
			// we'll do the mappings from the .py to the .cls direction, so that we don't iterate over objectscript lines
			Set tMethod = ""
			Do ..MethodMap.GetNext(.tMethod)
			while (tMethod '= "") 
			{
				Set tCLSMethodNum = pCLSCodeUnit.MethodMap.GetAt(tMethod)
				Set tMethodStart = ..MethodMap.GetAt(tMethod)
				Set tMethodEnd = ..MethodEndMap.GetAt(tMethod)
				Set tMethodName = tMethod
				Set tFullMap(tMethodStart) = $lb("CLS", tClass,tMethodName, -1, -1) ; -1 because the class 
				; definition doesn't have the +1 offset from the { 

				Do ..MethodMap.GetNext(.tMethod)
				For i = tMethodStart+1:1:tMethodEnd {
					Set tClassLineNum = i-tMethodStart
					Set tFullMap(i) = $lb("CLS", tClass,tMethodName, tClassLineNum, tClassLineNum)

					// extra check to make sure that the lines we're mapping between are the same as expected
					Set tClassLineCode = $zstrip(pCLSCodeUnit.Lines.GetAt(tCLSMethodNum + tClassLineNum + 1), "<>W")
					Set tPyLineCode = $zstrip(..Lines.GetAt(i), "<>W")
					if (tPyLineCode '= tClassLineCode) {
						Set tSC = $$$ERROR($$$GeneralError,"Compiled .py code doesn't match .CLS python code ")
					}
				}
			}
		}
		
		// If we are a generator .INT file, ensure that we have source for the original class populated.
		// In such files, the second line looks like (for example):
		// ;(C)InterSystems, method generator for class %ZHSLIB.PackageManager.Developer.AbstractSettings.  Do NOT edit.
		Set tIsGenerator = 0
		Set tCommentLine = ..Lines.GetAt(2)
		If (tCommentLine [ "method generator for class ") {
			Set tClass = $Piece($Piece(tCommentLine,"method generator for class ",2),". ")
			Set tIsGenerator = 1
			Set tSourceUnits(tClass_".CLS") = ""
			
			If (..Type = "MAC") {
				Set ..Generated = 1
				$$$ThrowOnError(..%Save())
				Set tMethod = ""
				Set tLastOffset = 0
				For tLineNumber=1:1:..Lines.Count() {
					Set tLine = ..Lines.GetAt(tLineNumber)
					If ($Piece(tLine," ") = "#classmethod") {
						Set tMethod = $Piece(tLine," ",2)
						Set tMethodGenerators(tLineNumber) = tMethod
						Set tLastOffset = tLineNumber
					} ElseIf (tLine = "#generator") {
						Set tMethod = ""
					} ElseIf (tLineNumber - tLastOffset > 1) && (tMethod '= "") {
						Set tMethodOffset = tLineNumber-tLastOffset-1
						Set tFullMap(tLineNumber) = $ListBuild("CLS",tClass,tMethod,tMethodOffset,tMethodOffset)
					}
				}
			}
		}
		
		// Ensure we have up-to-date code stashed for originating code (MAC/CLS)
		Set tSourceKey = ""
		For {
			Set tSourceKey = $Order(tSourceUnits(tSourceKey))
			If (tSourceKey = "") {
				Quit
			}
			
			Set tSC = ..GetCurrentByName(tSourceKey,pSourceNamespace,.tCodeUnit,.pCache)
			$$$ThrowOnError(tSC)
			Set tCodeUnits(tCodeUnit.Type,tCodeUnit.Name) = tCodeUnit
		}
		
		// Create CodeUnitMap data based on .INT / .py ->.CLS mapping.
		Set tFromHash = ..Hash
		Set tLineNumber = ""
		For {
			Set tLineNumber = $Order(tFullMap(tLineNumber),1,tData)
			If (tLineNumber = "") {
				Quit
			}
			
			Set tType = $ListGet(tData,1)
			Set tName = $ListGet(tData,2)
			Set tMethod = $ListGet(tData,3)
			Set tLine1 = $ListGet(tData,4)
			Set tLine2 = $ListGet(tData,5)
			
			Set tToHash = tCodeUnits(tType,tName).Hash
			If (tType = "CLS") {
				Set tOffset = 1 + tCodeUnits(tType,tName).MethodMap.GetAt(tMethod)
			} ElseIf (tType = "MAC") {
				Set tOffset = 0
			}
			
			$$$ThrowOnError(##class(TestCoverage.Data.CodeUnitMap).Create(tFromHash,tLineNumber,tToHash,tLine1 + tOffset,tLine2 + tOffset))
		}
		
		// Fill in missing details from .CLS->.INT debug mapping.
		// In some cases .CLS->.INT is more accurate; it is possible to have a many-to-many relationship in line mappings.
		// Embedded SQL, in particular, seems to throw a wrench in the works.
		If (..Type = "INT") {
			#dim tClassCodeUnit As TestCoverage.Data.CodeUnit
			Set tClass = $Order(tCodeUnits("CLS",""),1,tClassCodeUnit)
			If $IsObject($Get(tClassCodeUnit)) {
				Set tLine = 0
				For {
					Set tLine = $BitFind(tClassCodeUnit.ExecutableLines,1,tLine+1)
					If (tLine = 0) {
						Quit
					}
					
					// Find method offset of line
					Set tMethodOffset = tLine
					Set tMethodName = tClassCodeUnit.LineToMethodMap.GetPrevious(.tMethodOffset)
					If (tMethodName '= "") {
						If '$Data(tCodeModeCache(tClass,tMethodName),tCodeMode) {
							Set tCodeMode = $$$comMemberKeyGet(tClass,$$$cCLASSmethod,tMethodName,$$$cMETHcodemode)
							Set tCodeModeCache(tClass,tMethodName) = tCodeMode
						}
						If (tCodeMode = $$$cMETHCODEMODEGENERATOR) || (tCodeMode = $$$cMETHCODEMODEOBJECTGENERATOR) {
							Continue
						}
						Set tOffset = tLine - tMethodOffset - 1
						Set tSC = ##class(%Studio.Debugger).INTLine(tClass_".CLS",tMethodName,tOffset,.tIntName,.tIntLine,.tMissing,pSourceNamespace)
						$$$ThrowOnError(tSC)
						If 'tMissing && (tIntName = ..Name) {
							$$$ThrowOnError(##class(TestCoverage.Data.CodeUnitMap).Create(..Hash,tIntLine,tClassCodeUnit.Hash,tLine,tLine))
						}
					}
				}
			}
		}
		
		// Update cyclomatic complexity for methods in the linked class
		Set tClass = $Order(tCodeUnits("CLS",""),1,tClassCodeUnit)
		If $IsObject($Get(tClassCodeUnit)) {
			$$$ThrowOnError(tClassCodeUnit.UpdateComplexity())
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method UpdateComplexity() As %Status
{
	Set tSC = $$$OK
	Try {
		If (..Type '= "CLS") {
			Quit
		}
		
		Set tKey = ""
		For {
			Set tSubUnit = ..SubUnits.GetNext(.tKey)
			If (tKey = "") {
				Quit
			}
			$$$ThrowOnError(tSubUnit.UpdateComplexity())
		}
		
		$$$ThrowOnError(..%Save())
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method GetMethodOffset(pAbsoluteLine As %Integer, Output pMethod As %String, Output pOffset As %Integer)
{
}

ClassMethod GetCurrentHash(pName As %String, pType As %String, Output pHash As %String, Output pCodeArray As %String, Output pCache) As %Status [ Private ]
{
	Set tSC = $$$OK
	Try {
		If '$Data(pCache(pName,pType),pHash) {
			If (pType = "CLS") {
				Set pHash = $$$comClassKeyGet(pName,$$$cCLASShash)
				If (pHash '= "") {
					// Get the code too.
					Set pHash = pHash_"|"_$zcrc(pName,7) // In case multiple class definitions are the same!
					$$$ThrowOnError(##class(%Compiler.UDL.TextServices).GetTextAsArray($Namespace,pName,.pCodeArray))
					Set pCodeArray = $Order(pCodeArray(""),-1) //Set top level node to # of lines.
				}
			} ElseIf (pType = "MAC") {
				Merge pCodeArray = ^rMAC(pName,0)
				Merge tSizeHint = ^rMAC(pName,0,"SIZE")
				Set pCodeArray = $Get(pCodeArray(0),0)
				Set pHash = ..HashArrayRange(.pCodeArray,,pName_"."_pType,.tSizeHint)
			} ElseIf (pType = "INT") {
				Merge pCodeArray = ^ROUTINE(pName,0)
				Merge tSizeHint = ^ROUTINE(pName,0,"SIZE")
				Set pCodeArray = $Get(pCodeArray(0),0)
				
				// Skip header (lines 1-4) which, for .INT routines generated from classes,
				// includes the class compilation signature.
				Set pHash = ..HashArrayRange(.pCodeArray,5,pName_"."_pType,.tSizeHint)
			} ElseIf (pType = "PY") {
				Merge pCodeArray = ^ROUTINE(pName_".py",0)
				set tSizeHint = ^ROUTINE(pName_".py",0,0)
				set pHash = ..HashArrayRange(.pCodeArray, ,pName_".py", .pSizeHint)
			} Else {
				// Give standard descriptive error about the type being invalid.
				$$$ThrowStatus(..TypeIsValid(pType))
			}
			Set pCache(pName,pType) = pHash
		}
		If (pHash = "") {
			Set tSC = $$$ERROR($$$GeneralError,"Source code not available for "_pName_"."_pType)
		}
	} Catch e {
		Set pHash = ""
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod HashArrayRange(ByRef pArray, pStart As %Integer = 1, pInitValue As %String, pSizeHint As %Integer = 0) [ Private ]
{
	Set tHash = ""
	Set tSC = $$$OK
	If (pSizeHint > $$$MaxLocalLength) {
		// If we would exceed the max string length, use a stream instead.
		Set tTmpStream = ##class(%Stream.TmpCharacter).%New()
		Set tString = pInitValue
		For tIndex = pStart:1:$Get(pArray) {
			Do tTmpStream.Write(pArray(tIndex))
		}
		Set tHash = $Case(tTmpStream.Size,0:"",:$System.Encryption.Base64Encode($System.Encryption.SHA1HashStream(tTmpStream,.tSC)))
		$$$ThrowOnError(tSC)
	} Else {
		Set tString = pInitValue
		For tIndex = pStart:1:$Get(pArray) {
			Set tString = tString_$Get(pArray(tIndex))
		}
		// This is fast enough; overhead is only ~3x that of $zcrc(tString,7)
		Set tHash = $Case(tString,"":"",:$System.Encryption.Base64Encode($System.Encryption.SHA1Hash(tString)))
	}
	Quit tHash
}

Method ExportToStream(pStream As %Stream.Object) As %Status
{
	Set tSC = $$$OK
	Try {
		For tLineNumber = 1:1:..Lines.Count() {
			Do pStream.WriteLine(..Lines.GetAt(tLineNumber))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Storage Default
{
<Data name="CodeUnitDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Type</Value>
</Value>
<Value name="4">
<Value>ExecutableLines</Value>
</Value>
<Value name="5">
<Value>Generated</Value>
</Value>
</Data>
<Data name="LineToMethodMap">
<Attribute>LineToMethodMap</Attribute>
<Structure>subnode</Structure>
<Subscript>"LineToMethodMap"</Subscript>
</Data>
<Data name="Lines">
<Attribute>Lines</Attribute>
<Structure>subnode</Structure>
<Subscript>"Lines"</Subscript>
</Data>
<Data name="MethodEndMap">
<Attribute>MethodEndMap</Attribute>
<Structure>subnode</Structure>
<Subscript>"MethodEndMap"</Subscript>
</Data>
<Data name="MethodMap">
<Attribute>MethodMap</Attribute>
<Structure>subnode</Structure>
<Subscript>"MethodMap"</Subscript>
</Data>
<DataLocation>^TestCoverage.Data.CodeUnitD</DataLocation>
<DefaultData>CodeUnitDefaultData</DefaultData>
<IdLocation>^TestCoverage.Data.CodeUnitD</IdLocation>
<IndexLocation>^TestCoverage.Data.CodeUnitI</IndexLocation>
<StreamLocation>^TestCoverage.Data.CodeUnitS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
