Class TestCoverage.UI.Component.dataGrid Extends %ZEN.Component.dataGrid [ System = 3 ]
{

/// This is the XML namespace for this component.
Parameter NAMESPACE = "http://www.intersystems.com/zen/healthshare/test-coverage";

/// Focus taken from the grid's invisible edit control.
/// Overridden to avoid switching cell focus and consequently scrolling the grid (a major usability annoyance)
ClientMethod gridKeyBlur() [ Language = javascript ]
{
	this.hasFocus = false;
}

}

