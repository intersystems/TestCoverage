/// We want to avoid depending on HSMOD.FileUtils to support use of the Test Coverage tool without the package manager (e.g., by QD)
Class TestCoverage.Utils.File
{

/// Create this directory and all the parent directories if they do not exist. This differs from
/// <method>CreateDirectory</method> as that method only creates one new directory where as
/// this will create the entire chain of directories. Returns true if it succeeds and false otherwise.
/// Pass <var>return</var> by reference to obtain the low level return value in case of errors
ClassMethod CreateDirectoryChain(pName As %String) As %Status
{
	Set tSC = $$$OK
	If '##class(%Library.File).CreateDirectoryChain(pName,.tReturn) {
		Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",pName,$zu(209,tReturn)))
	}
	Quit tSC
}

}

