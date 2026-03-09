/// 
/// This class is an autocomplete function for FHIRPath.
/// 
/// Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Autocomplete Extends %RegisteredObject
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

/// Helper method to convert an operator to it's corresponding function (if applicable)
Method OpAsFn(pOp As %String)
{
	Return $CASE(pOp, "|":"union", :"")
}

Method InorderTraversal(pExpr As FHIR.FHIRPath.Expr.Expression, ByRef pCtx As FHIR.FHIRPath.FHIRContextHelper, ByRef finalTokenPrefix, ByRef refWithinFunctionCall = 0, withinFunctionCall = 0)
{
	/// Reach a leaf node
	If (pExpr = "") {
		Quit
	}

	Set cls = $CLASSNAME(pExpr)
	If cls = "FHIR.FHIRPath.Expr.BinaryExpr" {
		Set savedContext = pCtx.Context
		/// Traverse down the left tree
		Do ..InorderTraversal(pExpr.Left, pCtx, .finalTokenPrefix, .refWithinFunctionCall, withinFunctionCall)
		
		Set opFn = ..OpAsFn(pExpr.Op)
		Do:opFn'="" pCtx.AdvanceFunction(opFn)
		If pExpr.Op = "|" {
			/// If this is the union operator, we want to merge the context resulting from the RHS
			/// Instantiate a new Context obj
			Set leftCtx = ##class(FHIR.FHIRPath.FHIRContextHelper).%New(savedContext)
			Do ..InorderTraversal(pExpr.Right, leftCtx, .finalTokenPrefix, .refWithinFunctionCall, withinFunctionCall)

			Do pCtx.MergeContext(leftCtx.Context)
		}
		
		/// If we successfully advance the operator, it means the operator doubles as both
		/// a function and operator, so we move within
		Set opSuccess = pCtx.AdvanceOperator(pExpr.Op)
		Set:pCtx.AdvanceOperator(pExpr.Op) withinFunctionCall = 1
		Do ..InorderTraversal(pExpr.Right, pCtx, .finalTokenPrefix, .refWithinFunctionCall, withinFunctionCall)
	} ElseIf cls = "FHIR.FHIRPath.Expr.IdentExpr" {
		Set finalTokenPrefix = pExpr.Name
		Set refWithinFunctionCall = withinFunctionCall
		Do pCtx.AdvanceContext(finalTokenPrefix, 0)
	} ElseIf cls = "FHIR.FHIRPath.Expr.PartialExpr" {
		Set refWithinFunctionCall = withinFunctionCall
		Set finalTokenPrefix = ""
		#; Do pCtx.AdvanceContext(pExpr.Value)
	} ElseIf cls = "FHIR.FHIRPath.Expr.CallExpr" {
		Do pCtx.AdvanceContext(pExpr.Callee.Name, 1)
		/// Todo: Need a better way of reverting context after function call
		Set contextPrior = pCtx.CurrentContext
		Do ..InorderTraversal(pExpr.Args.GetAt(pExpr.Args.Size), pCtx, .finalTokenPrefix, .refWithinFunctionCall, 1)
		#; Write "Loading context prior to call: " _ pExpr.Callee.Name
		

		/// If the function call is not partial (i.e the function call has a closing ')'),
		/// then we revert back to the original context
		Do:pExpr.Partial=0 pCtx.LoadContext(contextPrior)
	} ElseIf cls = "FHIR.FHIRPath.Expr.IndexExpr" {
		Do ..InorderTraversal(pExpr.Field, pCtx, .finalTokenPrefix, .refWithinFunctionCall, withinFunctionCall)
	} ElseIf (cls = "FHIR.FHIRPath.Expr.NumberExpr") || (cls = "FHIR.FHIRPath.Expr.DecimalExpr") {
	} ElseIf (cls = "FHIR.FHIRPath.Expr.StringExpr") {
		Do pCtx.AdvanceString()
	} ElseIf cls = "FHIR.FHIRPath.Expr.UnaryExpr" { 
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
		Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT * FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND id=type AND kind='resource' AND %UPPER(id) = ?", ..FHIRVersion, $ZCVT(..ResourceFilter, "U"))
		Throw:tRS.%Next()=0 ##class(%Exception.General).%New("Resource not found","-30211",,"The resource '" _ ..ResourceFilter _ "' could not be found")
		Set searchString = pExpression
	} Else {
		Set ..Resource = $PIECE(pExpression, ".")
		/// Check if this resource is valid
		Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT * FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND id=type AND kind='resource' AND %UPPER(id) LIKE ?", ..FHIRVersion, $ZCVT(..Resource, "U") _ "%")

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

	Set ctx = ##class(FHIR.FHIRPath.FHIRContextHelper).BuildResourceContext(..Resource)
	
	Set ast = ##class(FHIR.FHIRPath.Parser).ParseString(searchString)

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
	Set a = ##class(FHIR.FHIRPath.Autocomplete).%New()
	Set l = a.Suggest(pExpr)
	For i=1:1:l.Size {
		Write l.GetAt(i),!
	}
}

}
