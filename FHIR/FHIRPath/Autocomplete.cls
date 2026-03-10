/// 
/// This class is an autocomplete function for FHIRPath.
/// 
/// Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Autocomplete Extends %RegisteredObject
{

/// The name of a resource or "" (empty string)
Property ResourceFilter As %String;

/// The FHIR Loader to load all metadata once
Property Loader As HS.FHIRMeta.Load.NpmLoader;

Method %OnNew(pPackageId = "hl7.fhir.r4.core@4.0.1", pValidResource = "") As %Status
{
	Set ..Loader = ##class(HS.FHIRMeta.Load.NpmLoader).Load($lb(pPackageId))
	Set ..ResourceFilter = pValidResource
	Quit $$$OK
}

/// Helper method to convert an operator to it's corresponding function (if applicable)
Method OpAsFn(pOp As %String)
{
	Return $CASE(pOp, "|":"union", :"")
}

Method InorderTraversal(pExpr As FHIR.FHIRPath.Expr.Expression, ByRef pCtx As FHIR.FHIRPath.FHIRContextHelper, ByRef finalTokenPrefix, ByRef suggestValues, ByRef refWithinFunctionCall = 0, withinFunctionCall = 0)
{
	/// Reach a leaf node
	If (pExpr = "") {
		Quit
	}

	Set cls = $CLASSNAME(pExpr)
	If cls = "FHIR.FHIRPath.Expr.BinaryExpr" {
		Set savedContext = pCtx.Context
		/// Traverse down the left tree
		Do ..InorderTraversal(pExpr.Left, .pCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)
		
		Set opFn = ..OpAsFn(pExpr.Op)
		Do:opFn'="" pCtx.AdvanceContext(opFn, 1)
		If pExpr.Op = "|" {
			/// If this is the union operator, we want to merge the context resulting from the RHS
			/// Instantiate a new Context obj
			Set leftCtx = ##class(FHIR.FHIRPath.FHIRContextHelper).%New(savedContext)
			Do ..InorderTraversal(pExpr.Right, leftCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)

			Do pCtx.MergeContext(leftCtx.Context)
		}

		/// Suggest values only if the operator is equal to "="
		Set suggestValues = (pExpr.Op = "=")
		
		/// If we successfully advance the operator, it means the operator doubles as both
		/// a function and operator, so we move within
		Set opSuccess = pCtx.AdvanceOperator(pExpr.Op)
		Set:pCtx.AdvanceOperator(pExpr.Op) withinFunctionCall = 1
		Do ..InorderTraversal(pExpr.Right, .pCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)
	} ElseIf cls = "FHIR.FHIRPath.Expr.IdentExpr" {
		Set finalTokenPrefix = pExpr.Name
		Set refWithinFunctionCall = withinFunctionCall
		Do pCtx.AdvanceContext(finalTokenPrefix, 0)
	} ElseIf cls = "FHIR.FHIRPath.Expr.PartialExpr" {
		Set refWithinFunctionCall = withinFunctionCall
		Set finalTokenPrefix = ""
		#; Do pCtx.AdvanceContext(pExpr.Value)
	} ElseIf cls = "FHIR.FHIRPath.Expr.CallExpr" {
		/// Duplicate the current context for use within the function
		Set scopedCtx = pCtx.Duplicate()
		Do scopedCtx.AdvanceContext(pExpr.Callee.Name, 1)

		/// We only need to traverse through the last argument to update the context

		Do ..InorderTraversal(pExpr.Args.GetAt(pExpr.Args.Size), .scopedCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, 1)
		Set:'pExpr.Partial suggestValues = 0

		/// TODO: Check if the following plays nicely with all types of supported functions....
		/// If the function call is partial (i.e. the function does not have a closing ')'),
		/// we want to change the context to the new scoped context
		Set:pExpr.Partial pCtx = scopedCtx
	} ElseIf cls = "FHIR.FHIRPath.Expr.IndexExpr" {
		Do ..InorderTraversal(pExpr.Field, .pCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)
	} ElseIf (cls = "FHIR.FHIRPath.Expr.NumberExpr") || (cls = "FHIR.FHIRPath.Expr.DecimalExpr") {
	} ElseIf (cls = "FHIR.FHIRPath.Expr.StringExpr") {
		Do pCtx.AdvanceString()
	} ElseIf cls = "FHIR.FHIRPath.Expr.UnaryExpr" { 
		Do ..InorderTraversal(pExpr.Expr, .pCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)
	} Else {
		Throw ##class(%Exception.General).%New("Unable to handle class " _cls)
	}

	Quit
}

/// Returns a list of resources to search or "" (empty string) if pSearch is a valid resource
Method SearchResources(pSearch As %String) As %ListOfDataTypes [ Private ]
{
	Set output = ##class(%ListOfDataTypes).%New()
	Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT DISTINCT(type) FROM HS_FHIRMeta_Storage.Rsrc WHERE (packageId %INLIST ?) AND kind='resource' AND %UPPER(type) LIKE ?", ..Loader.packageIdList, $ZCVT(pSearch, "U") _ "%")
	While tRS.%Next() '= 0 {
		Set type = tRS.%Get("type")
		If ($ZCVT(type, "U") = $ZCVT(pSearch, "U")) {
			Return ""
		}
		Do output.Insert(tRS.%Get("type") _ ".")
	}

	Return output
}

Method Suggest(pExpression As %String) As %ListOfDataTypes
{
	Set outputList = ##class(%ListOfDataTypes).%New()

	Set searchString = pExpression
	Set resourceFilter = ..ResourceFilter

	/// If a resource filter isn't set, extract it from the expression
	/// typically the FHIRPath expression begins with the resource type
	If (resourceFilter = "") {
		Set resourceSearch = $PIECE(pExpression, ".")
		Set searchString = $PIECE(pExpression, ".", 2, *)

		
		Set resourceList = ..SearchResources(resourceSearch)

		Return:resourceList'="" resourceList

		Set resourceFilter = resourceSearch
	}

	/// Create a context helper
	Set ctx = ##class(FHIR.FHIRPath.FHIRContextHelper).BuildResourceContext(..Loader, resourceFilter)
	
	Set ast = ##class(FHIR.FHIRPath.Parser).ParseString(searchString)

	/// We want to start by advancing into the resource itself
	#; Do ctx.AdvanceContext(..Resource)
	Set suggestValues = 0
	Do ..InorderTraversal(ast, .ctx, .lastTokenFilter, .suggestValues, .withinFnCall)
	
	#; Write "LastTokenFilter="_lastTokenFilter,!

	Set propertyList = ctx.GetPropertyList()
	Set fnList = ctx.GetFunctionsList()
	Set suggestionList = ""
	Set:suggestValues suggestionList = ctx.GetSuggestionsList()

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

	If suggestionList'="" {
		For i=1:1:suggestionList.Size {
			If ($EXTRACT(suggestionList.GetAt(i), 1, $L(lastTokenFilter)) = lastTokenFilter) {
				Do outputList.Insert("'" _ suggestionList.GetAt(i) _ "'")
			}
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
