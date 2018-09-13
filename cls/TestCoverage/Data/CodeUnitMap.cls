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
	Set tSC = $$$OK
	Try {
		&sql(insert or update into TestCoverage_Data.CodeUnitMap
			(FromHash, FromLine, ToHash, ToLine)
			select :pFromHash, :pFromLine, :pToHash, Counter
			from TestCoverage.Sequence(:pToLineStart,:pToLineEnd))
		If (SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
		}

		// Insert/update transitive data (e.g., .INT -> .MAC (generator) -> .CLS)
		&sql(
			/* Lines that map to the "from" line also map to the "to" line */
			insert or update into TestCoverage_Data.CodeUnitMap
			(FromHash, FromLine, ToHash, ToLine)
			select FromHash, FromLine, :pToHash, Counter
			from TestCoverage.Sequence(:pToLineStart,:pToLineEnd),TestCoverage_Data.CodeUnitMap
				where ToHash = :pFromHash and ToLine = :pFromLine
			union
			/* The "from" line also maps to lines that the "to" line maps to */
			select :pFromHash, :pFromLine, ToHash, ToLine
			from TestCoverage.Sequence(:pToLineStart,:pToLineEnd)
				join TestCoverage_Data.CodeUnitMap
				on FromHash = :pToHash and FromLine = Counter)
		If (SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE,%msg)
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
<Type>%Library.CacheStorage</Type>
}

}

