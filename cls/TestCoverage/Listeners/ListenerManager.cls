Class TestCoverage.Listeners.ListenerManager Extends %RegisteredObject
{

Property listeners As list Of TestCoverage.Listeners.ListenerInterface;

Method BroadCastToAll(pMessage As %DynamicObject) As %Status
{
    set tSC = $$$OK 
    try {
        for i = 1:1:..listeners.Count() {
            set tListener = ..listeners.GetAt(i)
            $$$ThrowOnError(tListener.Broadcast(pMessage))
        }
    }
    catch e {
        Set tSC = e.AsStatus()
    }
    quit tSC
}

Method AddListener(pListener As TestCoverage.Listeners.ListenerInterface) As %Status
{
    set tSC = $$$OK 
    try {
        do ..listeners.Insert(pListener)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method RemoveListener(pListener As TestCoverage.Listeners.ListenerInterface) As %Status
{
    set tSC = $$$OK 
    try {
        set tIndex = ..listeners.FindOref(pListener)
        if (tIndex = "") {
            Set tMsg = "Listener not found"
	        $$$ThrowStatus($$$ERROR($$$GeneralError,tMsg))
        }
        do ..listeners.RemoveAt(tIndex)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
