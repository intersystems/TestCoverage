Class TestCoverage.Utils.Projection.SchemaGenerator Extends %Projection.AbstractProjection
{

/// Name of XData block with schema in class defining this projection. Defaults to XSD.
Parameter XDATA As STRING = "XSD";

/// Package in which to generate classes. Defaults to the current class's name.
Parameter PACKAGE As STRING;

/// See <class>%XML.Utils.SchemaReader</class> for description.
Parameter DEFAULTSEQUENCE As BOOLEAN;

/// See <class>%XML.Utils.SchemaReader</class> for description.
Parameter JAVA As BOOLEAN;

/// See <class>%XML.Utils.SchemaReader</class> for description.
Parameter NOSEQUENCE As BOOLEAN;

/// See <class>%XML.Utils.SchemaReader</class> for description.
Parameter POPULATE As BOOLEAN;

/// See <class>%XML.Utils.SchemaReader</class> for description.
Parameter SQLCOLUMNS As BOOLEAN;

/// See <class>%XML.Utils.SchemaReader</class> for description.
Parameter IGNORENULL As BOOLEAN;

/// Generate classes based on the specified XData block.
ClassMethod CreateProjection(classname As %String, ByRef parameters As %String, modified As %String, qstruct) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Merge tParameters = parameters
		
		// Clear empty parameters
		Set tParameter = ""
		For {
			Set tParameter = $Order(parameters(tParameter),1,tValue)
			If (tParameter = "") {
				Quit
			}
			If (tValue = "") {
				Kill tParameters(tParameter)
			}
		}
		
		Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(classname,parameters("XDATA"),,.tSC)
		$$$ThrowOnError(tSC)
		
		Set tTempFile = ##class(%Stream.FileCharacter).%New()
		Set tTempFile.RemoveOnClose = 1
		Set tSC = tTempFile.CopyFromAndSave(tXData.Data)
		$$$ThrowOnError(tSC)
		
		// If no package specified, generate under the class defining this projection.
		Set tPackage = $Get(parameters("PACKAGE"),classname)
		
		// Wrap deletion and regeneration of classes in a transaction.
		TSTART
		Set tSC = $System.OBJ.DeletePackage(tPackage)
		$$$ThrowOnError(tSC)
		
		Set tReader = ##class(%XML.Utils.SchemaReader).%New()
		Set tReader.CompileClasses = 0 // We'll queue this for later.
		Set tReader.MakePersistent = 0
		Set tReader.MakeNamespace = 1
		Set tSC = tReader.Process(tTempFile.Filename,tPackage,.tParameters)
		$$$ThrowOnError(tSC)
		TCOMMIT
		
		// Queue compilation of all classes in generated package
		Set tSC = $System.OBJ.GetPackageList(.tClasses,tPackage)
		$$$ThrowOnError(tSC)
		
		Set tClass = ""
		For {
			Set tClass = $Order(tClasses(tClass))
			If (tClass = "") {
				Quit
			}
			Do ..QueueClass(tClass)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) {
		TROLLBACK 1
	}
	Quit tSC
}

/// Cleanup is automatic when parent class is deleted.
ClassMethod RemoveProjection(classname As %String, ByRef parameters As %String, recompile As %Boolean, modified As %String, qstruct) As %Status
{
	Quit $$$OK
}

}

