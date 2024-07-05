Class TestCoverage.Data.CodeSubUnit Extends %Persistent [ Abstract ]
{

Relationship Parent As TestCoverage.Data.CodeUnit [ Cardinality = parent, Inverse = SubUnits ];

/// Bitstring representing which lines are part of this section (method, branch, etc.) of the code
Property Mask As TestCoverage.DataType.Bitstring;

/// Cyclomatic complexity of the code subunit
Property Complexity As %Integer [ InitialExpression = 1 ];

/// 1 if it's a python class method, 0 if not
Property IsPythonMethod As %Boolean;

Method UpdateComplexity() As %Status
{
	Quit $$$OK
}

Storage Default
{
<Data name="CodeSubUnitDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Mask</Value>
</Value>
<Value name="3">
<Value>Complexity</Value>
</Value>
<Value name="4">
<Value>IsPythonMethod</Value>
</Value>
</Data>
<DataLocation>{%%PARENT}("SubUnits")</DataLocation>
<DefaultData>CodeSubUnitDefaultData</DefaultData>
<IdLocation>^TestCoverage.Data.CodeUnitC("SubUnits")</IdLocation>
<IndexLocation>^TestCoverage.Data.CodeSubUnitI</IndexLocation>
<StreamLocation>^TestCoverage.Data.CodeSubUnitS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
