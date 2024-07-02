Class TestCoverage.Data.PyMonitorResults Extends %Persistent [ DdlAllowed ]
{

Property ClassName As %String(MAXLEN = 255) [ Required ];

Property FunctionName As %String(MAXLEN = 255) [ Required ];

Property LineNumber As %Integer [ Required ];

Storage Default
{
<Data name="PyMonitorResultsDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ClassName</Value>
</Value>
<Value name="3">
<Value>FunctionName</Value>
</Value>
<Value name="4">
<Value>LineNumber</Value>
</Value>
</Data>
<DataLocation>^TestCovera3FF5.PyMonitorReC80BD</DataLocation>
<DefaultData>PyMonitorResultsDefaultData</DefaultData>
<ExtentSize>1</ExtentSize>
<IdLocation>^TestCovera3FF5.PyMonitorReC80BD</IdLocation>
<IndexLocation>^TestCovera3FF5.PyMonitorReC80BI</IndexLocation>
<Property name="%%CLASSNAME">
<AverageFieldSize>2</AverageFieldSize>
<OutlierSelectivity>.999999:</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="%%ID">
<AverageFieldSize>3</AverageFieldSize>
<Selectivity>1</Selectivity>
</Property>
<Property name="ClassName">
<AverageFieldSize>16</AverageFieldSize>
<OutlierSelectivity>.999999:"EP.sysSettrace"</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="FunctionName">
<AverageFieldSize>11</AverageFieldSize>
<OutlierSelectivity>.999999:"TestAsync"</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="LineNumber">
<AverageFieldSize>3</AverageFieldSize>
<OutlierSelectivity>.999999:28</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<SQLMap name="IDKEY">
<BlockCount>-4</BlockCount>
</SQLMap>
<StreamLocation>^TestCovera3FF5.PyMonitorReC80BS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
