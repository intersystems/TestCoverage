Class TestCoverage.Data.Aggregate.ByRun Extends TestCoverage.Data.Aggregate.Base
{

Index Run On Run [ Unique ];

Property Run As TestCoverage.Data.Run [ Required ];

ForeignKey RunFK(Run) References TestCoverage.Data.Run() [ OnDelete = cascade ];

Storage Default
{
<Data name="ByRunDefaultData">
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
</Data>
<DataLocation>^TestCoverage.Data.Agg.ByRunD</DataLocation>
<DefaultData>ByRunDefaultData</DefaultData>
<IdLocation>^TestCoverage.Data.Agg.ByRunD</IdLocation>
<IndexLocation>^TestCoverage.Data.Agg.ByRunI</IndexLocation>
<StreamLocation>^TestCoverage.Data.Agg.ByRunS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}

