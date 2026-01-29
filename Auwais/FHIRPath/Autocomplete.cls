/**
* This class is an autocomplete function for FHIRPath
*/

Class Auwais.FHIRPath.Autocomplete Extends %RegisteredObject
{

Property Resource As %String;

Property ResourceFilter As %String;

Property FHIRVersion As %String [ InitialExpression = "4.0.1" ];

Property Paths As %ListOfDataTypes;

Method %OnNew(pValidResource = "") As %Status
{
	Set ..ResourceFilter = pValidResource
	Quit $$$OK
}

Method InorderTraversal(pExpr As Auwais.FHIRPath.Expr.Expression, ByRef pCtx As Auwais.FHIRPath.Context.Helper, ByRef finalTokenPrefix, ByRef refWithinFunctionCall = 0, withinFunctionCall = 0)
{
	/// Reach a leaf node
	If (pExpr = "") {
		Quit
	}

	Set cls = $CLASSNAME(pExpr)
	If cls = "Auwais.FHIRPath.Expr.BinaryExpr" {
		Do ..InorderTraversal(pExpr.Left, pCtx, .finalTokenPrefix, .refWithinFunctionCall, withinFunctionCall)
		Do ..InorderTraversal(pExpr.Right, pCtx, .finalTokenPrefix, .refWithinFunctionCall, withinFunctionCall)
	} ElseIf cls = "Auwais.FHIRPath.Expr.IdentExpr" {
		Set finalTokenPrefix = pExpr.Name
		Set refWithinFunctionCall = withinFunctionCall
		Do pCtx.AdvanceContext(finalTokenPrefix, 0)
	} ElseIf cls = "Auwais.FHIRPath.Expr.PartialExpr" {
		Set refWithinFunctionCall = withinFunctionCall
		Set finalTokenPrefix = ""
		#; Do pCtx.AdvanceContext(pExpr.Value)
	} ElseIf cls = "Auwais.FHIRPath.Expr.CallExpr" {
		Do pCtx.AdvanceContext(pExpr.Callee.Name, 1)
		Do ..InorderTraversal(pExpr.Args.GetAt(pExpr.Args.Size), pCtx, .finalTokenPrefix, .refWithinFunctionCall, 1)
	} ElseIf cls = "Auwais.FHIRPath.Expr.IndexExpr" {
		Do ..InorderTraversal(pExpr.Field, pCtx, .finalTokenPrefix, .refWithinFunctionCall, withinFunctionCall)
	} ElseIf (cls = "Auwais.FHIRPath.Expr.NumberExpr") || (cls = "Auwais.FHIRPath.Expr.DecimalExpr") {
	} ElseIf (cls = "Auwais.FHIRPath.Expr.StringExpr") {
	} ElseIf cls = "Auwais.FHIRPath.Expr.UnaryExpr" { 
		Do ..InorderTraversal(pExpr.Expr, pCtx, .finalTokenPrefix, .refWithinFunctionCall, withinFunctionCall)
	} Else {
		Throw ##class(%Exception.General).%New("Unable to handle class " _cls)
	}

	Quit
}

Method Suggest(pExpression As %String) As %ListOfDataTypes
{
	Set outputList = ##class(%ListOfDataTypes).%New()

	Set suggestedResources = ##class(%ListOfDataTypes).%New()

	Set searchString = ""
	/// First, locate the resource type.
	If ..ResourceFilter '= "" {
		/// Specific resource filter
		Set ..Resource = ..ResourceFilter
		Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT * FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND id=type AND kind='resource' AND %UPPER(id) = ?", "4.0.1", $ZCVT(..ResourceFilter, "U"))
		Throw:tRS.%Next()=0 ##class(%Exception.General).%New("Resource not found","-30211",,"The resource '" _ ..ResourceFilter _ "' could not be found")
		Set searchString = pExpression
	} Else {
		Set ..Resource = $PIECE(pExpression, ".")
		/// Check if this resource is valid
		Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT * FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND id=type AND kind='resource' AND %UPPER(id) LIKE ?", "4.0.1", $ZCVT(..Resource, "U") _ "%")

		While tRS.%Next() '= 0 {
			If (..Resource = tRS.%Get("id")) {
				/// Full match found
				Do suggestedResources.Clear()
				Quit
			} Else {
				Do suggestedResources.Insert(tRS.%Get("id") _ ".")
			}
		}

		// Remove the resource from the search string
		Set searchString = $PIECE(pExpression, ".", 2, *)
	}

	Return:suggestedResources.Size>0 suggestedResources

	/// Check if this resource exists
	Set pathList = ##class(%ListOfDataTypes).%New()

	Set ctx = ##class(Auwais.FHIRPath.FHIRContextHelper).BuildResourceContext(..Resource)
	
	Set ast = ##class(Auwais.FHIRPath.Parser).ParseString(searchString)

	/// We want to start by advancing into the resource itself
	Do ctx.AdvanceContext(..Resource)
	Do ..InorderTraversal(ast, ctx, .lastTokenFilter, .withinFnCall)
	
	#; Write "LastTokenFilter="_lastTokenFilter,!

	Set propertyList = ctx.GetPropertyList()
	Set fnList = ctx.GetFunctionsList()

	#; Write "lasttoken=" _ lastTokenFilter,!,!
	
	Set suffix = ""
	Set:withinFnCall=0 suffix = "."
	
	Quit:'$DATA(lastTokenFilter) outputList

	/// Filter 
	For i=1:1:propertyList.Size {
		If ($EXTRACT(propertyList.GetAt(i), 1, $L(lastTokenFilter)) = lastTokenFilter) {
			Do outputList.Insert(propertyList.GetAt(i) _ suffix)
			Do:ctx.CollectionFields.Find(propertyList.GetAt(i))'="" outputList.Insert(propertyList.GetAt(i) _ "[")
			Do:propertyList.GetAt(i)="extension" outputList.Insert("extension(")
		}
	}

	For i=1:1:fnList.Size {
		/// Commented out -- maybe needed?
		#; Continue:withinFnCall
		If ($EXTRACT(fnList.GetAt(i), 1, $L(lastTokenFilter)) = lastTokenFilter) {
			Do outputList.Insert(fnList.GetAt(i))
		}
	}
	
	Return outputList
}

ClassMethod Test(pExpr)
{
	Set a = ##class(Auwais.FHIRPath.Autocomplete).%New()
	Set l = a.Suggest(pExpr)
	For i=1:1:l.Size {
		Write l.GetAt(i),!
	}
}

}
