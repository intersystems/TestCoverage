Include TestCoverage

Class TestCoverage.Report.Cobertura.ReportGenerator Extends TestCoverage.Report.AbstractReportGenerator
{

ClassMethod GenerateReport(pRunIndex As %Integer, pOutputFileName As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tCoverage = ##class(TestCoverage.Report.Cobertura.type.coverage).%New()
		Set tCoverage.version = ##class(TestCoverage.Report.Cobertura.Schema).#VERSION
		Set tCoverage.timestamp = $zdatetime($ztimestamp,-2) * 1000
		
		// Summary statistics
		&sql(select
				ROUND(CoveredLines/ExecutableLines,4),
				ExecutableLines,
				CoveredLines
			into :tLineRate,:tLinesValid,:tLinesCovered
			from TestCoverage_Data_Aggregate.ByRun where ExecutableLines > 0 and Run = :pRunIndex)
		If (SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
		}
		
		If (SQLCODE = 100) {
			Set tLineRate = 0
			Set tLinesCovered = 0
			Set tLinesValid = 0
		}
		
		Set tCoverage.linerate = tLineRate
		Set tCoverage.linescovered = tLinesCovered
		Set tCoverage.linesvalid = tLinesValid
		
		// For now:
		#define EMPTYBRANCHRATE ""
		#define EMPTYCOMPLEXITY ""
		Set tCoverage.branchescovered = 0
		Set tCoverage.branchesvalid = 0
		Set tCoverage.branchrate = $$$EMPTYBRANCHRATE
		Set tCoverage.complexity = $$$EMPTYCOMPLEXITY
		
		// Create directory for source code export
		Set tSourceDirectory = ##class(%Library.File).GetDirectory(pOutputFileName,1)_"source"
		$$$ThrowOnError(##class(TestCoverage.Utils.File).CreateDirectoryChain(tSourceDirectory))
		
		Do tCoverage.sources.Insert(tSourceDirectory)
		
		// Package-level results
		Set tTestPath = $$$TestPathAllTests
		Set tResults = ##class(%SQL.Statement).%ExecDirect(,
			"SELECT ID from TestCoverage_Data.Coverage "_
			"WHERE Run = ? and TestPath = ? and Ignore = 0 And Hash->Type in ('CLS','MAC')",pRunIndex,tTestPath)
		If (tResults.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResults.%SQLCODE,tResults.%Message)
		}
		While tResults.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set tCoverageData = ##class(TestCoverage.Data.Coverage).%OpenId(tResults.%Get("ID"),,.tSC)
			$$$ThrowOnError(tSC)
			Set tCodeUnit = tCoverageData.Hash
			Set tFileName = $Replace(tCodeUnit.Name,".","/")_"."_$ZConvert(tCodeUnit.Type,"L")
			Set tFullName = ##class(%Library.File).NormalizeFilename(tSourceDirectory_"/"_tFileName)
			Set tDirectory = ##class(%Library.File).GetDirectory(tFullName)
			$$$ThrowOnError(##class(TestCoverage.Utils.File).CreateDirectoryChain(tDirectory))
			Set tStream = ##class(%Stream.FileCharacter).%New()
			$$$ThrowOnError(tStream.LinkToFile(tFullName))
			$$$ThrowOnError(tCoverageData.Hash.ExportToStream(tStream))
			$$$ThrowOnError(tStream.%Save())
			
			Set tCoveredLineCount = $BitCount($BitLogic(tCodeUnit.ExecutableLines&tCoverageData.CoveredLines),1)
			Set tValidLineCount = $BitCount(tCodeUnit.ExecutableLines,1)
			
			// Class
			Set tClass = ##class(TestCoverage.Report.Cobertura.type.class).%New()
			Set tClass.name = tCodeUnit.Name
			Set tClass.filename = tFileName
			Set tClass.linerate = $Case(tValidLineCount,0:1,:tCoveredLineCount/tValidLineCount)
			Set tClass.branchrate = $$$EMPTYBRANCHRATE
			Set tClass.complexity = $$$EMPTYCOMPLEXITY
			Set tTotalMethodComplexity = 0
			
			// Lines
			Set tLineNumber = 0
			For {
				Set tLineNumber = $BitFind(tCodeUnit.ExecutableLines,1,tLineNumber+1)
				If (tLineNumber = 0) || (tLineNumber = "") {
					Quit
				}
				Set tLine = ##class(TestCoverage.Report.Cobertura.type.line).%New()
				Set tLine.number = tLineNumber
				Set tLine.branch = "false"
				Set tLine.hits = +tCoverageData.RtnLine.GetAt(tLineNumber)
				Do tClass.lines.Insert(tLine)
			}
			
			// Methods
			Set tMethodKey = ""
			For {
				Set tSubUnit = tCodeUnit.SubUnits.GetNext(.tMethodKey)
				If (tMethodKey = "") {
					Quit
				}
				If tSubUnit.%IsA("TestCoverage.Data.CodeSubUnit.Method") {
					Set tMethod = ##class(TestCoverage.Report.Cobertura.type.method).%New()
					Set tMethod.name = $Piece(tSubUnit.DisplaySignature," ")_" "_tSubUnit.Name //ClassMethod/Method and method name only
					Set tMethod.signature = $c(0) // Interpretation is tied to Java, so we just use the method name (above).
					Set tExecutableMethodLines = $BitLogic(tCodeUnit.ExecutableLines&tSubUnit.Mask)
					Set tExecutableCount = $BitCount(tExecutableMethodLines,1)
					Set tMethod.linerate = $Case(tExecutableCount, 0:1,
						:$BitCount($BitLogic(tExecutableMethodLines&tCoverageData.CoveredLines),1) / tExecutableCount)
					Set tMethod.branchrate = $$$EMPTYBRANCHRATE
					Set tMethod.complexity = tSubUnit.Complexity
					Set tTotalMethodComplexity = tTotalMethodComplexity + tMethod.complexity
					Set tLineNumber = 0
					For {
						Set tLineNumber = $BitFind(tExecutableMethodLines,1,tLineNumber+1)
						If (tLineNumber = 0) || (tLineNumber = "") {
							Quit
						}
						Set tLine = ##class(TestCoverage.Report.Cobertura.type.line).%New()
						Set tLine.number = tLineNumber
						Set tLine.branch = "false"
						Set tLine.hits = +tCoverageData.RtnLine.GetAt(tLineNumber)
						Do tMethod.lines.Insert(tLine)
					}
					Do tClass.methods.Insert(tMethod)
				}
			}
			
			Set tMethodCount = tClass.methods.Count()
			If (tMethodCount > 0) {
				Set tClass.complexity = tTotalMethodComplexity/tMethodCount
			}
			
			If (tCodeUnit.Type = "CLS") {
				Set tPackageSub = $Piece(tCodeUnit.Name,".",1,*-1)
				Set tMemberSub = $Piece(tCodeUnit.Name,".",*)
			} Else {
				Set tPackageSub = $c(0)
				Set tMemberSub = tCodeUnit.Name_"."_tCodeUnit.Type
			}
			
			Set tOldCoveredCount = 0
			Set tOldValidCount = 0
			If $Data(tPackages(tPackageSub),tOldCounts) {
				Set $ListBuild(tOldCoveredCount,tOldValidCount) = tOldCounts
			}
			Set tPackages(tPackageSub) = $ListBuild(tOldCoveredCount + tCoveredLineCount, tOldValidCount + tValidLineCount)
			Set tPackages(tPackageSub,tMemberSub) = tClass
		}
		$$$ThrowOnError(tSC)
		
		// Package-level aggregation
		Set tTotalComplexity = 0
		Set tPackageSub = ""
		For {
			Set tPackageSub = $Order(tPackages(tPackageSub),1,tCounts)
			If (tPackageSub = "") {
				Quit
			}
			Set tPackage = ##class(TestCoverage.Report.Cobertura.type.package).%New()
			Set tPackage.name = tPackageSub
			Set tPackage.linerate = $Case($ListGet(tCounts,2), 0:1, :$ListGet(tCounts)/$ListGet(tCounts,2))
			Set tPackage.branchrate = $$$EMPTYBRANCHRATE
			Set tPackage.complexity = $$$EMPTYCOMPLEXITY
			Set tTotalClassComplexity = 0
			
			Set tMemberSub = ""
			For {
				Set tMemberSub = $Order(tPackages(tPackageSub,tMemberSub),1,tMember)
				If (tMemberSub = "") {
					Quit
				}
				Set tTotalClassComplexity = tTotalClassComplexity + tMember.complexity
				Do tPackage.classes.Insert(tMember)
			}
			
			Set tClassCount = tPackage.classes.Count()
			If (tClassCount > 0) {
				Set tPackage.complexity = tTotalClassComplexity/tClassCount
			}
			
			Set tTotalComplexity = tTotalComplexity + tPackage.complexity
			Do tCoverage.packages.Insert(tPackage)
		}
		
		// Coverage-level complexity aggregation
		Set tPackageCount = tCoverage.packages.Count()
		If (tPackageCount > 0) {
			Set tCoverage.complexity = tTotalComplexity/tPackageCount
		}
		
		// Actual XML export
		Set tStream = ##class(%Stream.FileCharacter).%New()
		Set tSC = tStream.LinkToFile(pOutputFileName)
		Do tStream.WriteLine("<?xml version=""1.0"" ?>")
		Do tStream.WriteLine("<!DOCTYPE coverage SYSTEM ""http://cobertura.sourceforge.net/xml/coverage-04.dtd"">")
		Do tStream.WriteLine()
		$$$ThrowOnError(tSC)
		Set tSC = tCoverage.XMLExportToStream(tStream,,",literal,indent")
		$$$ThrowOnError(tSC)
		
		$$$ThrowOnError(tStream.%Save())
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}

