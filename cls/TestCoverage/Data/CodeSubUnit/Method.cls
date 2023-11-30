Class TestCoverage.Data.CodeSubUnit.Method Extends TestCoverage.Data.CodeSubUnit
{

Property Name As %Dictionary.CacheIdentifier [ Required ];

Property DisplaySignature As %String(MAXLEN = "");

Method UpdateComplexity() As %Status
{
	Set tSC = $$$OK
	Try {
		// Get int lines mapped to this method's mask.
		// As an optimization, find start/end of mask
		Set tMaskStart = $BitFind(..Mask,1,0,1)
		Set tMaskEnd = $BitFind(..Mask,1,0,-1)
		
		// Get lines mapped to this method's mask
		// Get unique by map.ToLine to avoid issues with mapping of embedded SQL
		// (all lines of the generated query map back to the class line defining it)
		Set tResult = ##class(%SQL.Statement).%ExecDirect(,
			"select distinct by (map.ToLine) element_key as Line, Lines as Code from TestCoverage_Data.CodeUnit_Lines intcode "_
			"join TestCoverage_Data.CodeUnitMap map "_
			"	on map.FromHash = intcode.CodeUnit "_
			"	and map.FromLine = intcode.element_key "_
			"where intcode.CodeUnit->Type = 'INT' "_
			"	and map.ToHash = ? "_
			"	and map.ToLine >= ? and map.ToLine <= ? "_
			"order by map.FromLine",..Parent.Hash,tMaskStart,tMaskEnd)
		If (tResult.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
		}
		Set tCodeStream = ##class(%Stream.TmpCharacter).%New()
		While tResult.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			$$$ThrowOnError(tCodeStream.WriteLine(tResult.%Get("Code")))
		}
		$$$ThrowOnError(tSC)
		
		Set ..Complexity = ##class(TestCoverage.Utils.ComplexityParser).%New(tCodeStream).GetComplexity()
		$$$ThrowOnError(..%Save(0))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Storage Default
{
<Data name="MethodDefaultData">
<Subscript>"Method"</Subscript>
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>DisplaySignature</Value>
</Value>
</Data>
<DefaultData>MethodDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}

