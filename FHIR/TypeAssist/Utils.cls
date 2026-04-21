Class FHIR.TypeAssist.Utils Extends %RegisteredObject
{

Method %OnNew() As %Status [ Private ] {
	Return $$$OK
}
/// Appends a subscript to a global ref given by <parameter>base</parameter>
/// The <parameter>subscriptValue</parameter> can be either a list or a string.
/// This function will traverse the list and append each string as a subscript
ClassMethod AppendSubscript(base As %String, subscriptValue) As %String
{
	If ('$LISTVALID(subscriptValue))||(subscriptValue = "") {
		Set subscriptValue = $lb(subscriptValue)
	}

	For i=1:1:$LL(subscriptValue) { 
		Set base = $NAME(@base@($LG(subscriptValue, i)))
	}

	Return base
}

/// Ascend a single subscript given its global ref
ClassMethod AscendSubscript(pRef As %String) As %String
{
	Return $NAME(@pRef, $QL(pRef) - 1)
}

/// Descend the first subscript found. Returns "" (empty string) if
/// no children were found
ClassMethod DescendSubscript(pRef As %String) As %String
{
	Set child = $O(@pRef@(""))
	Return:child="" child
	Return ..AppendSubscript(pRef, child)
}

/// True if the given parameter is a valid global reference
ClassMethod IsGlobalRef(pGlobalRef As %String) As %Boolean
{
	Return $EXTRACT(pGlobalRef)="^"
}

/// Given a global reference, get its display name
ClassMethod GetFieldDisplayName(pGlobalRef As %String) As %String
{
	Return:'..IsGlobalRef(pGlobalRef) pGlobalRef
	Return $QS(pGlobalRef, $QL(pGlobalRef))
}

/// Given a list of properties as key:value, returns ones where
/// key = pPropName
ClassMethod FindProperty(pPropList As %List, pPropName As %String) As %List
{
	Set list = ""
	For i=1:1:$LL(pPropList) {
		Set item = $LG(pPropList, i)
		Continue:item=""

		Set type = $PIECE(item, ":", 1)
		Set val = $PIECE(item, ":", 2, *)

		Continue:type'=pPropName

		Set:val'="" list = list _ $lb(val)
	}

	Return list
}

/// Find a specific property from a (list of) global references
/// Global 
ClassMethod FindPropertyFromRefs(pGlobalRefs As %List, pPropName As %String) As %List
{
	Return:pGlobalRefs="" ""
	Set refs = pGlobalRefs
	If ('$LISTVALID(pGlobalRefs)) {
		Set refs = $lb(pGlobalRefs)
	}

	Set list = ""
	For i=1:1:$LL(refs) {
		Set ref = $LG(refs, i)

		Set list = list _ ..FindProperty(@ref, pPropName)
	}

	Return list
}

ClassMethod FindMaxCardinality(pGlobalRefs As %List) As %String
{
	Set cardinalities = ..FindPropertyFromRefs(pGlobalRefs, "max")
	Set max = 0
	For i=1:1:$LL(cardinalities) {
		Set c = $LG(cardinalities, i)
		Return:c="*" c
		
		Set:c>max max = c
	}

	Return max
}

ClassMethod GetTypes(pPropList As %List) As %List
{
	Return ..FindProperty(pPropList, "type")
}

ClassMethod GetDirectTypesFromRefs(pGlobalRefs As %List) As %List {
	Return ..FindPropertyFromRefs(pGlobalRefs, "type")
}

ClassMethod GetTypeRefs(rootRef As %String) As %List
{
	Set list = @rootRef
	Set typeList = ..GetTypes(list)
	Return:$LL(typeList)'=1 ""

	Set profileList = ..FindProperty(list, "profile")

	Set type = $LG(typeList, 1)
	Set base = $NAME(@rootRef, 1)
	Set base = ..AppendSubscript(base, $lb("Type", type))

	/// TODO: Deal with cases with multiple profile types rather than just the first...
	If $LL(profileList) > 0 {
		Set profile = $LG(profileList, 1)
		Set base2 = ..AppendSubscript(base, profile)
		Return:$DATA(@base2) $lb(base2)
	}

	Return:'$DATA(@base) ""


	Return $lb(..DescendSubscript(base))
}

/// TODO: Rename this and the above method to something more descriptive
ClassMethod GetTypeRefsMultiple(pGlobalRefs As %List) {
	Return:pGlobalRefs="" ""
	Set refs = pGlobalRefs
	If ('$LISTVALID(pGlobalRefs)) {
		Set refs = $lb(pGlobalRefs)
	}

	Set typeRefs = ""
	For i=1:1:$LL(refs)	{
		Set ref = $LG(refs, i)
		Set typeRefs = typeRefs _ ..GetTypeRefs(ref)
	}

	Return typeRefs
}
ClassMethod FindImmediateDescendants(pGlobalRefs As %List) As %List
{
	Return:pGlobalRefs="" ""
	Set refs = pGlobalRefs
	If ('$LISTVALID(pGlobalRefs)) {
		Set refs = $lb(pGlobalRefs)
	}

	Set list = ""

	For i=1:1:$LL(refs) {
		Set gRef = $LG(refs, i)

		Continue:(gRef="")||($DATA(@gRef)<=1)

		Set next = ""
		For {
			Set subRef = ..AppendSubscript(gRef, next)
			Set next = $O(@subRef)
			Quit:next=""

			Set list = list _ $lb(..AppendSubscript(gRef, next))
		}
	}

	Return list
}


/// TODO: Implement and use this method
/// Helper method to perform a lookup and return a %DynamicObject
Method Lookup(pCanonicalURL, pVersion = "") As HS.FHIRMeta.Storage.Rsrc
{
	/// TODO:
	/// Utilise this lookup everywhere thats needed
	If pVersion = "" {
		Set pVersion = $PIECE(pCanonicalURL, "|", 2)
	}
	Return ##class(HS.FHIRMeta.Storage.Rsrc).UrlIndexOpen(pCanonicalURL, pVersion)
}

}
