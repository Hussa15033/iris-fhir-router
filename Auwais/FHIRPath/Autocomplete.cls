/**
* This class is an autocomplete function for FHIRPath
*/

Class Auwais.FHIRPath.Autocomplete Extends %RegisteredObject
{

Property Resource As %String;

Property FHIRVersion As %String [ InitialExpression = "4.0.1" ];

Property Paths As %ListOfDataTypes;

Method %OnNew() As %Status
{
	Quit $$$OK
}

Method SearchPaths(pResourceType As %String, pSearchTerm As %String, ByRef paths As %ListOfDataTypes)
{
	Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT * FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND id=type AND kind='resource' AND %UPPER(id)=?", "4.0.1", $ZCVT(pResourceType, "U"))
	Quit:tRS.%Next()=0
	Set obj = {}.%FromJSON(tRS.%Get("json"))


	#dim elements As %DynamicArray
	Set elements = obj.snapshot.element
	Set iter = elements.iterator()

	

	While (iter.%GetNext(.key, .value)) {
		Continue:($ZCVT($EXTRACT(value.path, 1, $L(pSearchTerm)), "L"))'=$ZCVT(pSearchTerm,"L")
		Continue:(pResourceType = value.path)
		If (value.path [ "[x]") {
			/// Enumerate paths
			Set types = value.type
			Set typeIter = types.iterator()
			While (typeIter.%GetNext(.key2, .value2)) {
				Do paths.Insert($EXTRACT(value.path,$F(value.path, "."),*-3)_$ZCVT(value2.code, "w"))
			}
		} Else {
			Do paths.Insert($EXTRACT(value.path, $F(value.path, "."),*))
		}
	}
}

Method InorderTraversal(pExpr As Auwais.FHIRPath.Expr.Expression, pCtx As Auwais.FHIRPath.FHIRContextHelper, ByRef finalTokenPrefix, ByRef refWithinFunctionCall = 0, withinFunctionCall = 0)
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
		Do pCtx.AdvanceContext(finalTokenPrefix)
	} ElseIf cls = "Auwais.FHIRPath.Expr.PartialExpr" {
		Set refWithinFunctionCall = withinFunctionCall
		Set finalTokenPrefix = ""
		#; Do pCtx.AdvanceContext(pExpr.Value)
	} ElseIf cls = "Auwais.FHIRPath.Expr.CallExpr" {
		Do ..InorderTraversal(pExpr.Args.GetAt(pExpr.Args.Size), pCtx, .finalTokenPrefix, .refWithinFunctionCall, 1)
	} ElseIf cls = "Auwais.FHIRPath.Expr.IndexExpr" {
		Do ..InorderTraversal(pExpr.Field, pCtx, .finalTokenPrefix, .refWithinFunctionCall, withinFunctionCall)
	} ElseIf (cls = "Auwais.FHIRPath.Expr.NumberExpr") || (cls = "Auwais.FHIRPath.Expr.DecimalExpr") {
	} ElseIf cls = "Auwais.FHIRPath.Expr.UnaryExpr" { 
		Do ..InorderTraversal(pExpr.Expr, pCtx, .finalTokenPrefix, .refWithinFunctionCall, withinFunctionCall)
	} Else {
		Throw ##class(%Exception.General).%New("Unable to handle class " _cls)
	}

	Quit
}

Method Suggest(pExpression As %String) As %ListOfDataTypes
{
	/// First, locate the resource type.
	Set ..Resource = $PIECE(pExpression, ".")

	/// Check if this resource exists
	Set pathList = ##class(%ListOfDataTypes).%New()

	Set ctx = ##class(Auwais.FHIRPath.FHIRContextHelper).BuildResourceContext(..Resource)
	
	Set ast = ##class(Auwais.FHIRPath.Parser).ParseString(pExpression)
	Do ..InorderTraversal(ast, ctx, .lastTokenFilter, .withinFnCall)
	#; Write "LastTokenFilter="_lastTokenFilter,!

	Set propertyList = ctx.GetPropertyList()
	Set fnList = ctx.GetFunctionsList()

	Set filteredList = ##class(%ListOfDataTypes).%New()
	#; Write "lasttoken=" _ lastTokenFilter,!,!
	
	Set suffix = ""
	Set:withinFnCall=0 suffix = "."
	
	/// Filter 
	For i=1:1:propertyList.Size {
		If ($EXTRACT(propertyList.GetAt(i), 1, $L(lastTokenFilter)) = lastTokenFilter) {
			Do filteredList.Insert(propertyList.GetAt(i) _ suffix)
			Do:ctx.CollectionFields.Find(propertyList.GetAt(i))'="" filteredList.Insert(propertyList.GetAt(i) _ "[")
			Do:propertyList.GetAt(i)="extension" filteredList.Insert("extension(")
		}
	}

	For i=1:1:fnList.Size {
		Continue:withinFnCall
		If ($EXTRACT(fnList.GetAt(i), 1, $L(lastTokenFilter)) = lastTokenFilter) {
			Do filteredList.Insert(fnList.GetAt(i) _ "(")
		}
	}
	
	Return filteredList
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
