Class TestCoverage.Data.Aggregate.ByCodeUnit Extends TestCoverage.Data.Aggregate.Base
{

Index RunCodeUnit On (Run, CodeUnit) [ Unique ];

Property Run As TestCoverage.Data.Run [ Required ];

ForeignKey RunFK(Run) References TestCoverage.Data.Run() [ OnDelete = cascade ];

Property CodeUnit As TestCoverage.Data.CodeUnit [ Required ];

ForeignKey CodeUnitFK(CodeUnit) References TestCoverage.Data.CodeUnit(Hash) [ OnDelete = cascade ];

Storage Default
{
<Data name="ByCodeUnitDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ExecutableLines</Value>
</Value>
<Value name="3">
<Value>CoveredLines</Value>
</Value>
<Value name="4">
<Value>ExecutableMethods</Value>
</Value>
<Value name="5">
<Value>CoveredMethods</Value>
</Value>
<Value name="6">
<Value>RtnLine</Value>
</Value>
<Value name="7">
<Value>Time</Value>
</Value>
<Value name="8">
<Value>TotalTime</Value>
</Value>
<Value name="9">
<Value>Run</Value>
</Value>
<Value name="10">
<Value>CodeUnit</Value>
</Value>
</Data>
<DataLocation>^TestCoverage.Data.Agg.ByCUD</DataLocation>
<DefaultData>ByCodeUnitDefaultData</DefaultData>
<IdLocation>^TestCoverage.Data.Agg.ByCUD</IdLocation>
<IndexLocation>^TestCoverage.Data.Agg.ByCUI</IndexLocation>
<StreamLocation>^TestCoverage.Data.Agg.ByCUS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}

