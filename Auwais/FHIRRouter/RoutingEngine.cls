Class Auwais.FHIRRouter.RoutingEngine Extends EnsLib.MsgRouter.RoutingEngine [ ClassType = persistent ]
{

Property FHIRJSON As %DynamicObject;

Method OnRequest(request As %Persistent, Output response As %Persistent) As %Status
{
	If (request.%Extends("HS.Message.FHIR.Request")) {
		Set stream = request.Payload
	} ElseIf (request.%Extends("Ens.StreamContainer")) {
		Set stream = request.Stream
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
<Subscript>"Auwais.FHIRRouter.RoutingEngine.FHIRJSON"</Subscript>
</Data>
<Type>%Storage.Persistent</Type>
}

}
