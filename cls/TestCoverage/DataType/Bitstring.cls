/// Overrides aggregates for bitstrings: <br />
/// MAX is the bitwise OR of all values considered in aggregation <br />
/// MIN is the bitwise AND of all values considered in aggregation <br />
/// Note that this only works for aggregates operating on properties of this type - not for arbitrary expressions
Class TestCoverage.DataType.Bitstring Extends %Binary [ ClassType = datatype ]
{

Parameter MAXLEN As INTEGER;

ClassMethod SQLmax(pAccumulated As TestCoverage.DataType.Bitstring, pValue As TestCoverage.DataType.Bitstring) As TestCoverage.DataType.Bitstring
{
	Quit $BitLogic(pAccumulated|pValue)
}

ClassMethod SQLmin(pAccumulated As TestCoverage.DataType.Bitstring, pValue As TestCoverage.DataType.Bitstring) As TestCoverage.DataType.Bitstring
{
	Quit $BitLogic(pAccumulated&pValue)
}

}

