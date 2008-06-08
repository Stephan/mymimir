package org.mymimir.Converter
{
	import org.mymimir.Engine.Syntax;
	import org.mymimir.Application;
	import org.mymimir.sdk.IConverter;
	import org.mymimir.sdk.IConvFunctionHandler;
	import org.mymimir.sdk.MYMError;
	import org.mymimir.sdk.Tools;
	
	/**
	 * A general converter class 
	 * @author stephansmola
	 * 
	 */	
	public class ConverterGeneral implements IConverter
	{
		protected static var _instance:IConverter;
		
		protected var _rules:Object;
		protected var _name:String;
		protected var _prefix:String;
		protected var _suffix:String;
		protected var _specials:Object;	
		protected var _specialStrings:Array;	
		protected var _syntax:Syntax;
		
		public function ConverterGeneral(name:String)
		{			
			this._name = name;
	
			this._syntax = new Syntax(org.mymimir.Application.getInstance().getSyntaxDefinition());
			this._syntax.addRules(Application.getInstance().getWikiSyntaxDefinition());

			var rules:XMLList;
			var rule:XML;
			var rName:String;
			var rFilter:String;
						
			var description:XML = Application.getInstance().getConverterSettings(name);
			if (!description)
			{
				throw new MYMError(MYMError.ErrorInitConverter);
			}
			rules = description.rule;
			
			_prefix = this.getPrefix(description);
			_suffix = this.getSuffix(description);
			
			var specs:XMLList = description.specials.replace;
			this._specials = new Object();
			this._specialStrings = new Array();
			for each (var spec:XML in specs)
			{
				var oldStr:String = new String(spec.@oldstring)
				var newStr:String = new String(spec.@newstring);
				
				if (oldStr == "") oldStr = Tools.replaceMetaCharacters(Tools.CDATAStrip(spec.oldstring.text().toString()))
				if (newStr == "") newStr = Tools.CDATAStrip(spec.newstring.text().toString())
				 
				_specials[oldStr] = newStr;
				_specialStrings.push(oldStr);
				this._syntax.replaceInExpressions(oldStr, newStr);
			}	
			
			
			for each (rule in rules)
			{
				rName = new String(rule.@name);
				rFilter = new String(rule.@blocks);
				this._syntax.setRuleReplaceString(rName, rFilter, org.mymimir.sdk.Tools.CDATAStrip(rule.text().toString())); 
			}
			
			description = Application.getInstance().getWikiConverterSettings(name);
			if (description)
			{
				rules = description.rule;
				
				var wPre:String = this.getPrefix(description);
				var wSuf:String = this.getSuffix(description);
				if (wPre != "") _prefix = wPre;
				if (wSuf != "") _suffix = wSuf;
				
				for each (rule in rules)
				{
					rName = new String(rule.@name);
					rFilter = new String(rule.@blocks);
					this._syntax.setRuleReplaceString(rName, rFilter, org.mymimir.sdk.Tools.CDATAStrip(rule.text().toString())); 
				}
			}
		}
		
		
		private function getPrefix(xml:XML):String
		{
			var pre:XMLList = xml.prefix;
			if ((!pre) || (!pre.length())) return "";
			return Tools.CDATAStrip(pre[0].text().toString());
		}

		private function getSuffix(xml:XML):String
		{
			var pre:XMLList = xml.suffix;
			if ((!pre) || (!pre.length())) return "";
			return Tools.CDATAStrip(pre[0].text().toString());
		}

		public function get prefix():String
		{
			return this._prefix;
		}
		
		public function get suffix():String
		{
			return this._suffix;
		}

		
		public static function getInstance(name:String):IConverter
		{
			if (!_instance) _instance = new ConverterGeneral(name);
			return _instance;
		}
		
		
		public function get name():String
		{
			return _name;
		}
		
		protected function replaceSpecialsInText(text:String):String
		{
			for each (var prop:String in this._specialStrings)
			{
				var re:RegExp = new RegExp(prop, "g");
				text = text.replace(re, this._specials[prop]);
			}
			return text;
		}
		
		public function convertText(text:String):String
		{
			this._syntax.globals = org.mymimir.Application.getInstance().getSyntaxGlobals();			
			return text;
		}
		
		public function convertLine(line:String):String
		{
			this._syntax.globals = org.mymimir.Application.getInstance().getSyntaxGlobals();			
			return line;			
		}


		protected function doConvertText(text:String, lineBreak:Boolean = false):String
		{
			return text;
		}

		public function processFunctions(str:String):String
		{
			var functions:Array = this._syntax.allMatches(Syntax.RFunction, str);
			
			for each (var func:String in functions)
			{
				var fName:String = this._syntax.getField(Syntax.RFunction, Syntax.FieldFunctionName, func);
				var fParas:String = this._syntax.getField(Syntax.RFunction, Syntax.FieldParameter, func);
				str = str.replace(func, this.doConvertText(this.processFunction(fName, fParas)));
			}
			
			return str;
		}
		
		protected function processFunction(name:String, param:String):String
		{
			var handler:IConvFunctionHandler = Application.getInstance().getConverterFunctionHandler(name);
			if (handler) return handler.processConverterFunction(name, param, this);
			return "ERROR: Unknown function " + name + "!";
		}
		
		


	}
}