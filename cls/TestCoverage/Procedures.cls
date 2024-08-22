/// Contains several helpful stored procedures for use in SQL.
Class TestCoverage.Procedures
{

/// Wraps $Bit for exposure as an SQL stored procedure
ClassMethod BitValue(pSource As %Binary, pIndex As %Integer) As %Boolean [ SqlName = BIT_VALUE, SqlProc ]
{
	Quit $Bit(pSource,pIndex)
}

/// Wraps $BitCount for exposure as an SQL stored procedure
ClassMethod BitCount(pSource As %Binary, pValue As %Boolean) As %Integer [ SqlName = BIT_COUNT, SqlProc ]
{
	If $Data(pValue) {
		Quit $BitCount(pSource, pValue)
	}
	Quit $BitCount(pSource)
}

/// Wrapper for $BitLogic(pArg1&pArg2) for exposure as an SQL stored procedure
ClassMethod BitwiseAnd(pArgs...) As %Binary [ SqlName = BITWISE_AND, SqlProc ]
{
	Set tResult = $Get(pArgs(1))
	For i=2:1:$Get(pArgs) {
		Set tResult = $BitLogic(tResult&pArgs(i))
	}
	Quit tResult
}

/// Wrapper for $BitLogic(pArg1|pArg2) for exposure as an SQL stored procedure
ClassMethod BitwiseOr(pArgs...) As %Binary [ SqlName = BITWISE_OR, SqlProc ]
{
	Set tResult = $Get(pArgs(1))
	For i=2:1:$Get(pArgs) {
		Set tResult = $BitLogic(tResult|pArgs(i))
	}
	Quit tResult
}

/// Wrapper for $BitLogic(pArg1^pArg2) for exposure as an SQL stored procedure
ClassMethod BitwiseXor(pArg1 As %Binary, pArg2 As %Binary) As %Binary [ SqlName = BITWISE_XOR, SqlProc ]
{
	Quit $BitLogic(pArg1^pArg2)
}

/// Wrapper for $BitLogic(~pArg) for exposure as an SQL stored procedure
ClassMethod BitwiseNot(pArg As %Binary) As %Binary [ SqlName = BITWISE_NOT, SqlProc ]
{
	Quit $BitLogic(~pArg)
}

/// Applies a bitwise OR to a $ListBuild list of bitstrings; input may be from the SQL %DLIST aggregate
ClassMethod BitwiseOrList(pSource As %List) As %Binary [ SqlName = BITWISE_OR_LIST, SqlProc ]
{
	Set tResult = ""
	Set tPointer = 0
	While $ListNext(pSource,tPointer,tItem) {
		Set tResult = $BitLogic(tResult|tItem)
	}
	Quit tResult
}

/// Applies a bitwise AND to a $ListBuild list of bitstrings; input may be from the SQL %DLIST aggregate
ClassMethod BitwiseAndList(pSource As %List) As %Binary [ SqlName = BITWISE_AND_LIST, SqlProc ]
{
	Set tResult = ""
	Set tPointer = 0
	While $ListNext(pSource,tPointer,tItem) {
		If (tResult = "") {
			Set tResult = tItem
		} Else {
			Set tResult = $BitLogic(tResult&tItem)
		}
	}
	Quit tResult
}

/// Convert a $ListBuild list of integers into a $Bit with 1s in positions present in the list
/// Use in SQL with the %DLIST aggregate
ClassMethod ListToBit(pSource As %List) As %Binary [ SqlName = LIST_TO_BIT, SqlProc ]
{
	Set tResult = ""
	Set tPointer = 0
	While $ListNext(pSource,tPointer,tBitPosition) {
		If $Data(tBitPosition)#2 && (tBitPosition '= "") {
			Set $Bit(tResult,tBitPosition) = 1
		}
	}
	Quit tResult
}

}

