package org.mymimir.Engine
{
	import org.mymimir.sdk.Tools;
	
	

	public class SyntaxRule
	{	
		private var _name:String;
		private var _expressionString:String;
		private var _expression:RegExp;
		private var _expressionG:RegExp;
		private var _supportedFields:Array;
		private var _fieldMappings:Object;
		
		private var _blockBegin:Boolean = false;
		private var _blockEnd:Boolean = false;
		private var _endBlock:String;

		private var _replacement:Object = new Object();
		private var _creation:String;
		
		
		/**
		 * Constructor. Initialises a new SyntaxElement according to a given XML-description. 
		 * @param description
		 * 
		 */		
		public function SyntaxRule(description:XML)
		{
			this._name = new String(description.@name);											// Syntax-Element name	
			this._blockBegin = String(description.@type) == "blockBegin";						// Is blockBegin?
			this._blockEnd = String(description.@type) == "blockEnd";							// Is blockEnd?
			this._endBlock = String(description.@endBlock);
			if (this._endBlock == "") this._endBlock = null;
			
			var crea:XMLList = description.creation;											// Get Creation string
			if ((crea) && (crea.length()))														// If there is one described
			{
				this._creation = new String(crea[0].@text)										// get attribute text 
				if (this._creation == "")														// if it is empty
					this._creation = Tools.CDATAStrip(crea[0].text().toString());				// get cdata
			}
					
						
			var exText:String = new String(description.expression.@text);						// Get regular expression from attribute
			if (exText == "")																	// If attribute is empty
				exText = org.mymimir.sdk.Tools.CDATAStrip(description.expression.text().toString());	// get cdata
			
			this._expressionString = exText;
			this._expression = new RegExp(exText, "");											// Make RegExp with local scope
			this._expressionG = new RegExp(exText, "g");										// ... and one with global scope
			
			var mappings:XMLList = description.groups.mapping;									// Get group mappings
			this._fieldMappings = new Object();	
			this._supportedFields = new Array();
			for each (var map:XML in mappings)													// For each found mapping
			{
				var field:String = new String(map.@field);										// Get the fieldname
				var mapping:Object = new Object();												
				mapping.reg = new RegExp(Tools.replaceMetaCharacters(field), "g");				// Create a regular expression with the $ escaped
				mapping.id = new String(map.@id);												// Get the group id the field is mapped to
				this._fieldMappings[map.@field] = mapping;										// Store mapping
				this._supportedFields.push(field);												// Remeber the field as one supported by the element
			}
		}


		/**
		 *  
		 * @return If the element descibes the beginning of a block 
		 * 
		 */
		public function get isBlockBegin():Boolean
		{
			return this._blockBegin;
		}
		
		/**
		 * 
		 * @return if the element describes the end of a block 
		 * 
		 */
		public function get isBlockEnd():Boolean
		{
			return this._blockEnd;
		}
		
		public function get creationString():String
		{
			return this._creation;
		}


		public function get name():String
		{
			return this._name;
		}
		
		public function get endBlock():String
		{
			return this._endBlock;
		}

		public function replaceInExpression(oldStr:String, newStr:String, nonCapturingGroup:Boolean):void
		{
			oldStr = Tools.replaceMetaCharacters(oldStr);
			newStr = Tools.replaceMetaCharacters(newStr);
			var re:RegExp = new RegExp(oldStr, "g");
			
			if (nonCapturingGroup) newStr = "(?:" + newStr + ")";
			this._expressionString = this._expressionString.replace(re, newStr);
			
			this._expression = new RegExp(this._expressionString, "");
			this._expressionG = new RegExp(this._expressionString, "g");
		}


		/**
		 *	Check if the element is valid for a given block filter 
		 * @param filter	The block filter
		 * @return 			True when the element is valid
		 * 
		 */
/* 		public function validForFilter(filter:String):Boolean
		{
			if (this._validAny) return true;
			if (this._validBlocks.indexOf(filter) != -1) return true;
			return false;
		}
 */					

		/**
		 * Check is a string does match the elements regular expression 
		 * @param str	The string to test
		 * @return 		Ture if the string matches
		 * 
		 */
		public function doesMatch(str:String):Boolean
		{
			var m:Array = str.match(this._expression);
			if ((!m) || (!m.length)) return false;
			return true; 
		}
		
		/**
		 * Check is a string does match the elements regular expression 
		 * @param str	The string to test
		 * @return 		Ture if the string matches
		 * 
		 */
		public function doesMatchG(str:String):Boolean
		{
			var m:Array = str.match(this._expressionG);
			if ((!m) || (!m.length)) return false;
			return true; 			
		}
		
		/**
		 * This takes a string and replaces all occurences of supported fields by their mapped group id. 
		 * @param str
		 * @return 
		 * 
		 */
		public function setReplaceString(str:String, filter:String):void
		{
			this._replacement[filter] = str;
			for each (var sup:String in this._supportedFields)
				this._replacement[filter] = this._replacement[filter].replace(this._fieldMappings[sup].reg, this._fieldMappings[sup].id);
		}
		
		
		
		/**
		 * Apply global variables to string 
		 * @param str			String to work on
		 * @param globals		Global variables: Dictinary of Rregular expressions (variable name) and replacement strings (value)
		 * @return 				Resulting string
		 * 
		 */		
		private function applyGlobals(str:String, globals:Object):String
		{
			for (var globName:String in globals)
			{
				var glob:Object = globals[globName];
				str = str.replace(glob.reg, glob.value);
			}
			
			return str;
		}
		
		
		private function getReplacement(filter:String):String
		{
			var ret:String = this._replacement[filter];
			if (!ret)
				ret = this._replacement[Syntax.FilterAnyBlock];
			return ret;
		}
		
		
		/**
		 * Replace using the expression (non-globally) and the replacement string 
		 * @param str	String to process
		 * @return 		Resulf of the replacement
		 * 
		 */
		public function replace(str:String, filter:String, globals:Object):String
		{
			var repl:String = this.getReplacement(filter);
			if (!repl) return str;
			return this.applyGlobals(str.replace(this._expression, repl), globals);
		}

		/**
		 * Replace using the expression (non-globally) and the replacement string 
		 * @param str	String to process
		 * @return 		Resulf of the replacement
		 * 
		 */
		public function replaceOverride(str:String, replace:String, globals:Object):String
		{
			return this.applyGlobals(str.replace(this._expression, replace), globals);
		}
		
		/**
		 * Replace using the expression (globally) and the replacement string 
		 * @param str	String to process
		 * @return 		Resulf of the replacement
		 * 
		 */
		public function replaceG(str:String, filter:String, globals:Object):String
		{
			var repl:String = this.getReplacement(filter);
			if (!repl) return str;
			return this.applyGlobals(str.replace(this._expressionG, repl), globals);			
		}
		
		/**
		 * Giva all matches of the global regular expression of the element in a string 
		 * @param str	The string to process
		 * @return 		An array of string with all matching substrings
		 * 
		 */
		public function allMatches(str:String):Array
		{
			if (!str) return null;
			return str.match(this._expressionG);			
		}
		
				
		/**
		 * Get the substring representing the field from the fieldmapping in a string 
		 * @param field	The field to retrieve the substring for
		 * @param str	The string to process
		 * @return 		The substring
		 * 
		 */
		public function getField(field:String, str:String):String
		{
			return str.replace(this._expression, this._fieldMappings[field].id);
		}
		
		
		/**
		 * Creates a string using the creation string from the syntax description.  
		 * @param fieldValues	An Object where the attributes represent the values fpr different fields supported by the element
		 * @return 				The created string
		 * 
		 */
		public function createFromFieldValues(fieldValues:Object):String
		{
			if (!this._creation) return null;
			var ret:String = this._creation;
			
			for each (var field:String in this._supportedFields)
			{
				var val:String = fieldValues[field];
				if (val != null) ret = ret.replace(this._fieldMappings[field].reg, val);
			}
			
			// Remove fields where no value was provided
			for each (var m:Object in this._fieldMappings)
				ret = ret.replace(m.reg, "");


			return ret;
		}
		
		public function createFromArgs(args:Array):String
		{
			var name:String;
			var value:String;
			var fieldValues:Object = new Object();
			
			for each (var arg:String in args)
			{
				if (!name) name = arg;
				else
				{
					value = arg;
					fieldValues[name] = value;
					name =  null;
				}
			}
			return this.createFromFieldValues(fieldValues);
		}
		
		public function init(index:int = 0):void
		{
			this._expression.lastIndex = index;
			this._expressionG.lastIndex = index;
		}
		
		public function execG(str:String):Object
		{
			return this._expressionG.exec(str);
		}
	}
}