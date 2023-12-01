/// This class maintains the mapping between .INT/.MAC/.CLS and therefore is critical for
/// interpreting the .INT-level coverage data that the line-by-line monitor collects.
Class TestCoverage.Data.CodeUnitMap Extends %Persistent
{

Index Key On (FromHash, FromLine, ToHash, ToLine) [ IdKey ];

Property FromHash As TestCoverage.Data.CodeUnit [ Required ];

Property FromLine As %Integer [ Required ];

Property ToHash As TestCoverage.Data.CodeUnit [ Required ];

Property ToLine As %Integer [ Required ];

Index Reverse On (ToHash, ToLine, FromHash, FromLine) [ Unique ];

Index HashForward On (FromHash, ToHash);

Index HashReverse On (ToHash, FromHash);

ForeignKey FromCodeUnitFK(FromHash) References TestCoverage.Data.CodeUnit(Hash) [ OnDelete = cascade ];

ForeignKey ToCodeUnitFK(ToHash) References TestCoverage.Data.CodeUnit(Hash) [ OnDelete = cascade ];

ClassMethod Create(pFromHash As %String, pFromLine As %Integer, pToHash As %String, pToLineStart As %Integer, pToLineEnd As %Integer) As %Status
{
	#def1arg DefaultStorageNode(%node) ##expression($$$comMemberKeyGet("TestCoverage.Data.CodeUnitMap", $$$cCLASSstorage, "Default", %node))
	#def1arg CodeUnitMasterMap(%arg) $$$DefaultStorageNode($$$cSDEFdatalocation)(%arg)
	#def1arg CodeUnitReverseMap(%arg) $$$DefaultStorageNode($$$cSDEFindexlocation)("Reverse",%arg)
	
	Set tSC = $$$OK
	Try {
		For counter=pToLineStart:1:pToLineEnd {
			// Uses direct global references for performance boost; this is one of the most performance-critical sections.
			If '$Data($$$CodeUnitMasterMap(pFromHash,pFromLine,pToHash,counter)) {
				&sql(insert %NOLOCK %NOCHECK into TestCoverage_Data.CodeUnitMap
					(FromHash, FromLine, ToHash, ToLine)
					select :pFromHash, :pFromLine, :pToHash, :counter)
				If (SQLCODE < 0) {
					Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
				}
			}
		}

		// Insert/update transitive data (e.g., .INT -> .MAC (generator) -> .CLS)
		// Original implementation:
		/*
		// Leg 1: Lines that map to the "from" line also map to the "to" line
		// Leg 2: The "from" line also maps to lines that the "to" line maps to
		&sql(
			insert or update %NOLOCK %NOCHECK into TestCoverage_Data.CodeUnitMap
			(FromHash, FromLine, ToHash, ToLine)
			select FromHash, FromLine, :pToHash, Counter
			from TestCoverage.Sequence(:pToLineStart,:pToLineEnd),TestCoverage_Data.CodeUnitMap
				where ToHash = :pFromHash and ToLine = :pFromLine
			union
			select :pFromHash, :pFromLine, ToHash, ToLine
			from TestCoverage.Sequence(:pToLineStart,:pToLineEnd)
				join TestCoverage_Data.CodeUnitMap
				on FromHash = :pToHash and FromLine = Counter)
		If (SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
		}
		*/
		
		// This introduced some unacceptable performance overhead, and has been rewritten with direct global references.
		// This reduces overall overhead of code capture for test coverage measurement by roughly 40%.
		
		// Leg 1: Lines that map to the "from" line also map to the "to" line
		Set fromHash = ""
		For {
			Set fromHash = $Order($$$CodeUnitReverseMap(pFromHash,pFromLine,fromHash))
			If (fromHash = "") {
				Quit
			}
			Set fromLine = ""
			For {
				Set fromLine = $Order($$$CodeUnitReverseMap(pFromHash,pFromLine,fromHash,fromLine))
				If (fromLine = "") {
					Quit
				}
				For counter=pToLineStart:1:pToLineEnd {	
					If '$Data($$$CodeUnitMasterMap(fromHash,fromLine,pToHash,counter)) {
						&sql(insert %NOLOCK %NOCHECK into TestCoverage_Data.CodeUnitMap
							(FromHash, FromLine, ToHash, ToLine)
							select :fromHash, :fromLine, :pToHash, :counter)
						If (SQLCODE < 0) {
							Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
						}
					}
				}
			}
		}
		
		For counter=pToLineStart:1:pToLineEnd {
			// Leg 2: The "from" line also maps to lines that the "to" line maps to
			Set toHash = ""
			For {
				Set toHash = $Order($$$CodeUnitMasterMap(pToHash,counter,toHash))
				If (toHash = "") {
					Quit
				}
				Set toLine = ""
				For {
					Set toLine = $Order($$$CodeUnitMasterMap(pToHash,counter,toHash,toLine))
					If (toLine = "") {
						Quit
					}
					If '$Data($$$CodeUnitMasterMap(pFromHash,pFromLine,toHash,toLine)) {
						&sql(insert %NOLOCK %NOCHECK into TestCoverage_Data.CodeUnitMap
							(FromHash, FromLine, ToHash, ToLine)
							select :pFromHash, :pFromLine, :toHash, :toLine)
						If (SQLCODE < 0) {
							Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
						}
					}
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod IsLineMappedTo(pToHash As %String, pToLine As %Integer) As %Boolean
{
	If (pToHash = "") || (pToLine = "") {
		Quit 0
	}
	
	// In theory, the query would be really really fast and just have a single global reference.
	// In practice, the generated code loops over subscripts in the "Reverse" index.
	/*
	&sql(select top 1 1 from TestCoverage_Data.CodeUnitMap where ToHash = :pToHash and ToLine = :pToLine)
	Quit (SQLCODE = 0)
	*/
	
	// Therefore, as an optimization, just check the global of interest.
	Quit ($Data(^TestCoverage.Data.CodeUnitMapI("Reverse",pToHash,pToLine)) > 0)
}

Storage Default
{
<Data name="CodeUnitMapDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^TestCoverage.Data.CodeUnitMapD</DataLocation>
<DefaultData>CodeUnitMapDefaultData</DefaultData>
<IdLocation>^TestCoverage.Data.CodeUnitMapD</IdLocation>
<IndexLocation>^TestCoverage.Data.CodeUnitMapI</IndexLocation>
<StreamLocation>^TestCoverage.Data.CodeUnitMapS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}

