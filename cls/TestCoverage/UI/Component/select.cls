/// %ZEN.Component.select customized to behave in more expected ways with an SQL data source and parameters
Class TestCoverage.UI.Component.select Extends %ZEN.Component.select [ System = 3 ]
{

/// This is the XML namespace for this component.
Parameter NAMESPACE = "http://www.intersystems.com/zen/healthshare/test-coverage";

/// Set to true (default) to automatically reexecute the query when a parameter changes
Property autoExecute As %ZEN.Datatype.boolean [ InitialExpression = 0 ];

/// Overridden to allow zen expressions in initial value.
Method %DrawHTML()
{
	Set tSC = ..%BuildValueLists(.tValueList,.tDisplayList)

	If $$$ISERR(tSC) {
		Do ##class(%ZEN.Utils).%DisplayErrorHTML($this,tSC)
		Quit
	}

	#; <select> does not support readOnly
	#; so we use disabled for both
	Set disabled = $S(..disabled||..readOnly:"disabled",1:"")
	Set tValue = $$$ZENVAL(..value)

	&html<<select class="#(..controlClass)#" id="#(..%MakeId("control"))#" #(..%Name())# #(..%Attr("title",..title))# #(disabled)# #(..%Attr("size",..size))# #(..%Attr("style",..controlStyle))# #(..%Attr("tabindex",..tabIndex))# #(..%GetEventHandlers())#>>

	If (..showEmpty) {
		#; empty item for value of ""
		&html<<option #($S(""=..value:"selected=""1""",1:""))#>#($ZCVT(..emptyText,"O","HTML"))#</option>>
	}

	// Also replaced a bunch of $ListGets with $ListNext, which is faster.
	Set tDisplayPointer = 0
	Set tValuePointer = 0
	While $ListNext(tDisplayList,tDisplayPointer,tDisplayItem) && $ListNext(tValueList,tValuePointer,tValueItem) {
		Set tDisplayItem = $$$ZENVAL($Get(tDisplayItem))
		Set tValueItem = $$$ZENVAL($Get(tValueItem))
		&html<<option #($S(tValueItem=tValue:"selected=""1""",1:""))# value="#($ZCVT(tValueItem,"O","HTML"))#">#($ZCVT(tDisplayItem,"O","HTML"))#</option>>
	}

	&html<</select>>
}

/// Set the value of a named property.
/// Overridden to allow parameters to be set.
ClientMethod setProperty(property, value, value2) [ Language = javascript ]
{
	var el = this.findElement('control');

	switch(property) {
	case 'parameters':
		if ('' != value) {
			value = value - 1;
			if (this.parameters[value]) {
				if (this.parameters[value].value != value2) {
					this.parameters[value].value = value2;
					if (this.autoExecute) { this.triggerRefresh(); }
				}
			}
		}
		break;
	default:
		// dispatch
		return this.invokeSuper('setProperty',arguments);
	}
	return true;
}

ClientMethod triggerRefresh() [ Language = javascript ]
{
	this._refreshing = true;
	this.setDisabled(true);
	this.refreshContents();
}

/// This client callback is called just from refreshContents
/// just after the new HTML is delivered from the server.
ClientMethod onRefreshContents() [ Language = javascript ]
{
	if (this._refreshing == true) {
		this.setDisabled(false);
	}
}

}

