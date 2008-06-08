package org.mymimir.Engine
{
	import org.mymimir.sdk.Tools;
	
	/**
	 * Class representing the Wiki-Syntax. 
	 * @author stephansmola
	 * 
	 */	
	public class Syntax
	{
		private static const RegElementList:RegExp = /([^,\s]+\s*,\s*)*([^,\s]+\s*)/; 
		private static const RegElementFromList:RegExp = /([^,\s]+)/g;
		
		
		public static const FilterAnyBlock:String =		"*";
		public static const FilterPageBlock:String =    "page";
		
			
		
		public static const FieldFunctionName:String 	=	"$functionname";
		public static const FieldParameter:String 		=	"$parameter";
		public static const FieldPageName:String 		= 	"$pagename";
		public static const FieldURL:String 			= 	"$url";
		public static const FieldText:String 			= 	"$text";
		public static const FieldTodoTask:String		=   "$task";
		public static const FieldTodoDue:String			=   "$due";
		public static const FieldTodoDone:String		=   "$done";
		
		//Globals
		public static const FieldDatapath:String	    =   "$datapath";
		public static const FieldWikipath:String		=	"$wikipath";
		public static const FieldWikipageFile:String	=	"$wikipagefile";
		public static const FieldBlockContentCode:String =  "$blockcontent";
		public static const FieldLineNumber:String       =  "$linenumber";
		public static const FieldSourceLine:String       =  "$sourceline";
		
		
		public static const RHeadlineL1:String = 	"Headline1";
		public static const RHeadlineL2:String = 	"Headline2";
		public static const RHeadlineL3:String = 	"Headline3";
		public static const RHeadlineL4:String = 	"Headline4";
		public static const RPreBegin:String =		"PreBegin";
		public static const RPreEnd:String =		"PreEnd";
		public static const RTableBegin:String = 	"TableBegin";
		public static const RTableEnd:String =		"TableEnd";
		public static const RTodo:String =			"Todo";
		public static const RDone:String =			"Done";
		public static const RWikiLink:String =		"WikiLink";
		public static const RWebLink:String =		"WebLink";
		public static const RFileLink:String = 		"FileLink";				// These are nevertheless general inline elements
		public static const RRelFileLink:String = 	"RelFileLink";			// ... and are therefore not part of the standard rules
		public static const RRelIMG:String = 		"RelIMG";				// ... this one too
		public static const REscapeRelIMG:String = 	"RelIMGEscape";
		public static const RFunction:String = 		"Function";
		
		private static const StandardRules:Array = new Array(Syntax.RHeadlineL1,
													    	 Syntax.RHeadlineL2,
													   		 Syntax.RHeadlineL3,
													   		 Syntax.RHeadlineL4,
													   		 Syntax.RTableBegin,
													   		 Syntax.RTableEnd,
													   		 Syntax.RWikiLink,
													   		 Syntax.RWebLink,
													   		 Syntax.RTodo,
													   		 Syntax.RDone,
													   		 Syntax.RFunction);
													   
		
		private var _ruleNames:Array = new Array();
		private var _rules:Object = new Object();
		
		private var _blockBeginRules:Object = new Object();
		private var _blockBeginRuleNames:Array = new Array();
		private var _blockEndRules:Object = new Object();
		private var _blockEndRuleNames:Array = new Array();
		
		private var _nonStandardRuleNames:Array = new Array();
		private var _nonStandardRules:Object = new Object();
		private var _tableCellDelimiter:String;
		
		private var _blockFilterStack:Array = new Array();
		private var _blockFilter:String;
		
		private var _allowedElements:Object = new Object();
		
		private var _globals:Object;
		
		public function Syntax(description:XML)
		{
			this.addRules(description);
			this.initBlockFilterStack();
		}
		
		public function addRules(description:XML):void
		{
			if (!description) return;
			var rules:XMLList = description.rule;
			var newEl:SyntaxRule;
			var tcd:String = new String(description.@tableCellDelimiter);
			
			if ((this._tableCellDelimiter == null) || (tcd != ""))
				this._tableCellDelimiter = tcd
			
						
			for each (var rule:XML in rules)
			{
				var elName:String = new String(rule.@name);
				newEl = new SyntaxRule(rule);
				
				if (Syntax.StandardRules.indexOf(elName) != -1)
				{
					if (!_rules[elName])
						_rules[elName] = new Array();
					_rules[elName].push(newEl);		
					_ruleNames.push(elName);			
				}
				else 
				{
					if (newEl.isBlockBegin)
					{
						this._blockBeginRuleNames.push(elName);
						if (!this._blockBeginRules[elName])
							this._blockBeginRules[elName] = new Array()
						this._blockBeginRules[elName].push(newEl);
						if (!_rules[elName])
							_rules[elName] = new Array();
						_rules[elName].push(newEl);					
						_ruleNames.push(elName);
						
						
						var elements:String = new String(rule.@elements);								// Get elements allowed in Block
						if (elements)
						{
							this._allowedElements[elName] = this.getElementsFromList(elements); 
						}
						else
						{
							this._allowedElements[elName] = [Syntax.FilterAnyBlock];
						}
						
					}
					else if (newEl.isBlockEnd)
					{
						this._blockEndRuleNames.push(elName);
						if (!this._blockEndRules[elName])
							this._blockEndRules[elName] = new Array()
						this._blockEndRules[elName].push(newEl);
						if (!_rules[elName])
							_rules[elName] = new Array();
						_rules[elName].push(newEl);	
						_ruleNames.push(elName);				
					}
					else
					{
						_nonStandardRuleNames.push(elName);
						if (!_nonStandardRules[elName])
							_nonStandardRules[elName] = new Array();
						_nonStandardRules[elName].push(newEl);
						if (!_rules[elName])
							_rules[elName] = new Array();
						_rules[elName].push(newEl);	
						_ruleNames.push(elName);				
					}
				}
								
			}			
		}
		
		
		/**
		 * Creates an array of strings each being one of the elements from a comma separated element list. 
		 * @param elementList	The string containing the elements, e.g. "el1, el2, el3"
		 * @return 				An array of strings. Null if elementList is not a valid commaseparated list.
		 * 
		 */		
		private function getElementsFromList(elementList:String):Array
		{
			var ret:Array = elementList.match(Syntax.RegElementList);
			if ((!ret) || (!ret.length))
				return null;
			return elementList.match(Syntax.RegElementFromList);
		}
		
		/**
		 * The table cell delimiter is used to distinguish the seperate table cell contents in the wiki text. 
		 * @return 	The cell delimiter for this syntax
		 * 
		 */		
		public function get tableCellDelimiter():String
		{
			return this._tableCellDelimiter;
		}
		
		/**
		 * Set the globals property of the syntax. 
		 * @param globals
		 * 
		 */		
		public function set globals(globals:Object):void
		{
			this._globals = globals;
		}
		
		/**
		 * Set a field i the globals list to a new value. If the field already exists, it will be replaced.
		 * Otherwise it will be added 
		 * @param name		The name of the global field
		 * @param value		The (new) value of that global field.
		 * 
		 */		
		public function setGlobalField(name:String, value:String):void
		{
			var glob:Object = this._globals[name];
			if (!glob)
			{
				glob = new Object();
				glob.reg = Tools.regExpForStringG(name);
				glob.value = value;
				this._globals[name] = glob;
			}
			else glob.value = value;
		}
		
		private function ruleIsAllowed(rule:String, filter:String = null):Boolean
		{
			if (filter == null) filter = this._blockFilter;
			
			if (filter == Syntax.FilterPageBlock) return true;
			if (this._allowedElements[filter] == Syntax.FilterAnyBlock) return true;
			if (this._allowedElements[filter].indexOf(rule) != -1) return true;
			return false;
		}
		
		/**
		 * Set the replacementstring for a rule for a specific filter 
		 * @param els
		 * @param filter
		 * @param repl
		 * 
		 */		
		private function setRulesReplaceStringFiltered(els:Array, filter:String, repl:String):void
		{
			for each (var el:SyntaxRule in els)
			{
				if (!this.ruleIsAllowed(el.name)) continue;
				el.setReplaceString(repl, filter);
			}			
		}
		
		/**
		 * Ste the replace string for a rule for a set of filters. 
		 * @param rule		The rule to set the replace string for
		 * @param filter	A commaseperated sequence of block filters
		 * @param repl		The replacement string
		 * 
		 */		
		public function setRuleReplaceString(rule:String, filter:String, repl:String):void
		{
			var filtArray:Array = this.getElementsFromList(filter);
			
			if ((!filtArray) || (!filtArray.length))
			{
				filtArray = new Array();
				filtArray.push(Syntax.FilterAnyBlock);
			}
						
			var els:Array = this._rules[rule];
			var nsEls:Array = this._nonStandardRules[rule];
			var bbEls:Array = this._blockBeginRules[rule];
			var beEls:Array = this._blockEndRules[rule];
			
			for each (var filt:String in filtArray)
			{
				this.setRulesReplaceStringFiltered(els, filt, repl);				
				this.setRulesReplaceStringFiltered(nsEls, filt, repl);				
				this.setRulesReplaceStringFiltered(bbEls, filt, repl);				
				this.setRulesReplaceStringFiltered(beEls, filt, repl);				
			}
		}
		
		
		/**
		 * Set the current block filter. The block filter determines what rule definition to choose. 
		 * @param filter	The block filter to set.
		 * 
		 */		
		public function set blockFilter(filter:String):void
		{
			this._blockFilterStack.push(this._blockFilter);
			this._blockFilter = filter;
		}
		
		
		/**
		 * Reset block filter. This will pop the top item from the filter stack and use that as the current
		 * filter. If the stack is empty, the page filter will be used. 
		 * 
		 */		
		public function clearBlockFilter():void
		{
			if (this._blockFilterStack.length)
				this._blockFilter = this._blockFilterStack.pop();
			else this._blockFilter = Syntax.FilterPageBlock;
		}
		
		/**
		 * Empty the filter stack and set the current filter to page. 
		 * 
		 */
		public function initBlockFilterStack():void
		{
			this._blockFilterStack = new Array();
			this._blockFilter = Syntax.FilterPageBlock;
		}
		
		
		/**
		 * Get a rule of the givenrule name for the current block filter. 
		 * @param name	The rule name
		 * @return 		The rule, null if no rule was found
		 * 
		 */		
		private function getRule(name:String, filter:String = null):SyntaxRule
		{
			var els:Array = this._rules[name];
			if (!els) return null;
			
			if (!filter) filter = this._blockFilter;
			
			if (filter == Syntax.FilterAnyBlock) return els[0];
			
			for each (var el:SyntaxRule in els)
				if (this.ruleIsAllowed(el.name, filter)) return el

			return null;
		}
		
		
		/**
		 * Get an array of all matches of a string for a given rule. 
		 * @param rule	The rule to match against
		 * @param str	The string to match
		 * @return 		An array of all matches, null for no matches
		 * @see String.match
		 */		
		public function allMatches(rule:String, str:String):Array
		{
			var el:SyntaxRule = this.getRule(rule);
			if (!el) return null;
			return el.allMatches(str);
		}
		
		public function firstMatch(rule:String, str:String):String
		{
			var el:SyntaxRule = this.getRule(rule);
			if (!el) return null;
			var matches:Array = el.allMatches(str);	
			if ((!matches) || (!matches.length)) return null;
			return matches[0];		
		}
		
		/**
		 * Apply the replacement string of a rule to a given string. 
		 * @param rule	The rule to use
		 * @param str	The input string to perform the replace
		 * @return 		The result. If no rule was found the input string is returned
		 * @see replaceG, replaceOverride
		 */		
		public function replace(rule:String, str:String):String
		{
			var el:SyntaxRule = this.getRule(rule);
			if (!el) return str;
			return el.replace(str, this._blockFilter, this._globals);			
		}
		
		/**
		 * Apply a rule replacement but overriding the rules replacement string by a given one. 
		 * @param rule		The rule to use
		 * @param str		The input string to perform the replace
		 * @param replace	The replacement string to use
		 * @return 			The result. If no rule was found the input string will be returned
		 * @see replace, replaceG
		 */		
		public function replaceOverride(rule:String, str:String, replace:String):String
		{
			var el:SyntaxRule = this.getRule(rule);
			if (!el) return str;
			return el.replaceOverride(str, replace, this._globals);						
		}

		/**
		 * Apply the replacement string of a rule to a given string. Performs the function globally.
		 * @param rule	The rule to use
		 * @param str	The input string to perform the replace
		 * @return 		The result. If no rule was found the input string is returned
		 * @see replace, replaceOverride
		 */		
		public function replaceG(rule:String, str:String):String
		{
			var el:SyntaxRule = this.getRule(rule);
			if (!el) return str;
			return el.replaceG(str, this._blockFilter, this._globals);			
		}
		
		/**
		 * Determine the field value for a given rule and string. the first occurence of the field in the string will be returned. 
		 * @param rule		The rule to use
		 * @param field		The field to return the value for
		 * @param str		The string to work on
		 * @return 			The value of the field in the string. If no rule was found or the field was not found this will be null
		 * 
		 */		
		public function getField(rule:String, field:String, str:String):String
		{
			var el:SyntaxRule = this.getRule(rule);
			if (!el) return null;
			return el.getField(field, str);
		}
		
		/**
		 * Check if a string does match a specific rule 
		 * @param rule
		 * @param str
		 * @return 
		 * 
		 */
		public function doesMatch(rule:String, str:String):Boolean
		{
			var el:SyntaxRule = this.getRule(rule);
			if (!el) return false;
			return el.doesMatch(str);			
		}

		/**
		 * Check if any part of a string does match a specific rule. 
		 * @param rule
		 * @param str
		 * @return 
		 * 
		 */
		public function doesMatchG(rule:String, str:String):Boolean
		{
			var el:SyntaxRule = this.getRule(rule);
			if (!el) return false;
			return el.doesMatchG(str);			
		}
		
		
		/**
		 * Apply all rules that are not in the standard rule list 
		 * @param str
		 * @return 
		 * 
		 */
		public function applyNonStandardRules(str:String):String
		{
			for each (var eln:String in this._nonStandardRuleNames)
			{
				var els:Array = this._nonStandardRules[eln];
				for each (var el:SyntaxRule in els)
				{
					if (!this.ruleIsAllowed(el.name)) continue;					
					str = el.replaceG(str, this._blockFilter, this._globals);
				}
			}
			return str;
		}
		


		/**
		 * Determine the rule that a given string matches. Firs found rule is returned. 
		 * @param str
		 * @param rules
		 * @param ruleNames
		 * @param filter
		 * @return 
		 * 
		 */
		private function giveRuleForString(str:String, rules:Object, ruleNames:Array, filter:String = null):String
		{
			if (!filter) filter = this._blockFilter;
			
			for each (var name:String in ruleNames)
			{
				var els:Array = rules[name];
				
				for each(var el:SyntaxRule in els)
				{
					if (!this.ruleIsAllowed(el.name)) continue;
					if (el.doesMatch(str)) return name
				}
			}	
			return null;
			
		}
		
		/**
		 * Check if a string begins a block, i.e. matches a block-begin rule. 
		 * @param str
		 * @return 		The name of the block begin rule or null
		 * 
		 */
		public function isBlockBegin(str:String):String
		{
			return this.giveRuleForString(str, this._blockBeginRules, this._blockBeginRuleNames);
		}

		/**
		 * Check if a string ends a block, i.e. matches a block end rule. 
		 * @param str
		 * @return 		The name of the block end rule or null
		 * 
		 */
		public function isBlockEnd(str:String):String
		{
			if (this._blockFilterStack.length == 0) 
				return null;
			var prevFilt:String = this._blockFilterStack[this._blockFilterStack.length - 1];
						
			var el:SyntaxRule = this.getRule(this._blockFilter, prevFilt);
			if (!el) return null;
			if (el.endBlock)
			{
				el = this.getRule(el.endBlock);
				if (!el) return null;
				if (el.doesMatch(str)) return el.name
				return null;
			} 
			 
			return this.giveRuleForString(str, this._blockEndRules, this._blockEndRuleNames, this._blockFilter);
		}
		
		/**
		 * Creates a string using the creation string of a rule. 
		 * @param rule			The rule to create a string for
		 * @param fieldValues	An Object where the attributes represent the values fpr different fields supported by the rule
		 * @return 				The created string
		 * 
		 */
		public function createFromFieldValues(rule:String, fieldValues:Object):String
		{
			var el:SyntaxRule = this.getRule(rule);
			if (!el) return null;
			return el.createFromFieldValues(fieldValues);
		}
		
		
		/**
		 * Create a string using the creation string of a rule 
		 * @param rule			The rule to create the string for
		 * @param args			Additional parameter sequence <name1>, <value1>, <name2>, <value2>, ...
		 * @return 				The created string
		 * 
		 */		
		public function createFromArgs(rule:String, ... args):String
		{
			var el:SyntaxRule = this.getRule(rule);
			if (!el) return null;
			return el.createFromArgs(args);			
		}
		
		
		/**
		 * Get the creation string of a given rule 
		 * @param rule
		 * @return 
		 * 
		 */
		public function getCreationString(rule:String, filter:String = null):String
		{
			var el:SyntaxRule = this.getRule(rule, filter);
			if (!el) return null;
			return el.creationString;
		}
		
		public function replaceInExpressions(oldStr:String, newStr:String):void
		{
			for each (var rule:Array in this._rules)
			{
				for each (var r:SyntaxRule in rule)
					r.replaceInExpression(oldStr, newStr, true);
			}
		}
		
		
		private static function compareToken(t1:Object, t2:Object):int
		{
			if (t1.index > t2.index) return 1;
			if (t2.index > t1.index) return -1;
			return 1;
		}
		
		public function tokenize(str:String):Array
		{
			var tokens:Array = new Array();
			var idx:int;
			
			for each (var rule:String in this._ruleNames)
			{
				var el:SyntaxRule = this.getRule(rule);
				if (!el) continue;
				idx = 0;
				el.init(idx);
				var res:Object = el.execG(str);
				while (res)
				{
					tokens.push(res);
					res["rule"] = rule;
					res["tokens"] = new Array();
					for (var i:int = 1; i < res.length; i++)
					{
						var subs:Array = tokenize(res[i]);
						res["tokens"] = res["tokens"].concat(subs);
					}
						
					idx = idx + res[0].length;
					el.init(idx)
					res = el.execG(str);
					
				}
				
			}
			
			tokens.sort(Syntax.compareToken);
			
			return tokens;
		}

	}
}