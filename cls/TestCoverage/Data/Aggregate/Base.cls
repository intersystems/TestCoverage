Class TestCoverage.Data.Aggregate.Base Extends %Persistent [ Abstract, NoExtent ]
{

Property ExecutableLines As %Integer [ Required ];

Property CoveredLines As %Integer [ Required ];

Property ExecutableMethods As %Integer [ Required ];

Property CoveredMethods As %Integer [ Required ];

Property RtnLine As %Integer [ InitialExpression = 0 ];

Property Time As TestCoverage.DataType.Timing [ InitialExpression = 0, SqlFieldName = _TIME ];

Property TotalTime As TestCoverage.DataType.Timing [ InitialExpression = 0 ];

}

