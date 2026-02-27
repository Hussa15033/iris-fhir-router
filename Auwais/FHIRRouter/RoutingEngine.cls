Class FHIR.FHIRRouter.RoutingEngine Extends EnsLib.MsgRouter.RoutingEngine [ ClassType = persistent ]
{

Property FHIRJSON As %DynamicObject;

Method OnRequest(request As %Persistent, Output response As %Persistent) As %Status
{

	If (request.%Extends("HS.FHIRServer.Interop.Request")) {
		Set stream = ##class(HS.SDA3.QuickStream).%OpenId(request.QuickStreamId)
	} ElseIf (request.%Extends("HS.Message.FHIR.Request")) {
		Set stream = request.GetPayloadOref()
	} ElseIf (request.%Extends("Ens.StreamContainer")) {
		Set stream = request.Stream
	} Else {
		Throw ##class(%Exception.General).%New("Message not handled",,,"Message of type '" _ $CLASSNAME(request) _ "' cannot be routed")
	}
	Set ..FHIRJSON = {}.%FromJSON(stream.Read())
	Set tSC = ##super(request,.response)
	Quit tSC
}

Storage Default
{
<Data name="FHIRJSON">
<Attribute>FHIRJSON</Attribute>
<Structure>node</Structure>
<Subscript>"FHIR.FHIRRouter.RoutingEngine.FHIRJSON"</Subscript>
</Data>
<Type>%Storage.Persistent</Type>
}

}
