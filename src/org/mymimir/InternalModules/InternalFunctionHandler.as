package org.mymimir.InternalModules
{
	import flash.desktop.Clipboard;
	import flash.desktop.ClipboardFormats;
	
	import org.mymimir.Engine.Syntax;
	import org.mymimir.sdk.IApplication;
	import org.mymimir.sdk.IConvFunctionHandler;
	import org.mymimir.sdk.IConverter;
	import org.mymimir.sdk.IViewFunctionHandler;
	import org.mymimir.sdk.IWikiPage;
	import org.mymimir.sdk.Modules.MYMModule;
	import org.mymimir.sdk.Tools;

	public class InternalFunctionHandler extends MYMModule implements IConvFunctionHandler, IViewFunctionHandler
	{	
		private var _syntax:Syntax;
		
		public function InternalFunctionHandler()
		{
			super();
		}

		override public function init(app:IApplication, description:XML):void
		{
			super.init(app, description);
			this._syntax = new Syntax(_app.getSyntaxDefinition());
			this._syntax.addRules(_app.getWikiSyntaxDefinition());
		}

		/*** Converter Functions
		/******************************************************************************************/
		
		public static const ConvFunctionPageName:String =		"func:pagename";
		public static const ConvFunctionWikiName:String =		"func:wikiname";	
		public static const ConvFunctionWikiStyleSheet:String =	"func:wikistylesheet";	
		public static const ConvFunctionDate:String = 			"func:date";
		public static const ConvFunctionTodos:String =			"func:todos";
		public static const ConvFunctionDataURL:String = 		"func:dataURL";

		protected var _convFunctions:Array = [InternalFunctionHandler.ConvFunctionDate,
							   	   InternalFunctionHandler.ConvFunctionPageName,
							   	   InternalFunctionHandler.ConvFunctionWikiName,
							       InternalFunctionHandler.ConvFunctionWikiStyleSheet,
							       InternalFunctionHandler.ConvFunctionTodos,
							       InternalFunctionHandler.ConvFunctionDataURL];
		

		
		public function get converterFunctions():Array
		{
			return _convFunctions;
		}
		
		public function processConverterFunction(name:String, param:String, converter:IConverter):String
		{
			switch (name)
			{
				case InternalFunctionHandler.ConvFunctionPageName:		return _app.getCurrentPageName();
										
				case InternalFunctionHandler.ConvFunctionWikiName:		return _app.getCurrentWikiName();
				
				case InternalFunctionHandler.ConvFunctionWikiStyleSheet:return _app.getWikiStyleSheetURL();	
				
				case InternalFunctionHandler.ConvFunctionTodos:			return convFuncTodos(param, converter);
				
				case InternalFunctionHandler.ConvFunctionDate:			
					if (!param)
						return Tools.strftime("%d.%m.%Y");
					else return Tools.strftime(param);
				
				case InternalFunctionHandler.ConvFunctionDataURL:			return _app.wiki.backend.getDataURLForFilename(param);	
				
			}	
			return "ERROR: Unknown function " + name + "!"; 

		}
	
	
		private function convFuncTodos(param:String, converter:IConverter):String
		{
			var ret:String = "";
			var todos:Array = this._app.wiki.todos;
			var page:String;
			
			for each (var todo:Object in todos)
			{
				if (todo.page != page)
				{
					page = todo.page;
					ret += this._syntax.createFromArgs(Syntax.RHeadlineL2, Syntax.FieldText, todo.page) + "\r";
				}
				ret += this._syntax.createFromArgs(Syntax.RTodo, Syntax.FieldTodoTask, todo.task, Syntax.FieldTodoDue, todo.due) + "\r";
			}
			
			
			return ret;
		}
	
	
		/*** View Functions
		/******************************************************************************************/

		private static const ViewFunctionToClipboard:String = "toClipboard";
		private static const ViewFunctionSetDone:String 	= "setDone";
		private static const ViewFunctionSetTodo:String 	= "setTodo";
		
		private var _viewFunctions:Array = [InternalFunctionHandler.ViewFunctionToClipboard,
											InternalFunctionHandler.ViewFunctionSetDone,
											InternalFunctionHandler.ViewFunctionSetTodo];
	
		public function get viewFunctions():Array
		{
			return this._viewFunctions;	
		}
		
		public function processViewFunction(name:String, args:Array):Object
		{
			if (this._viewFunctions.indexOf(name) != -1)
				return this[name](args);
			return null;
		}
		
		
		private function toClipboard(args:Array):Object
		{
			trace("To Clipboard", args);
			if (args.length)
			{
				flash.desktop.Clipboard.generalClipboard.clear();
				flash.desktop.Clipboard.generalClipboard.setData(flash.desktop.ClipboardFormats.TEXT_FORMAT, args[0]);				
			}
			
			return null;
		}
		
		
		private function getLineOfText(text:String, line:int):String
		{
			var count:int = 0;
			var pos:int = 0;
			while (count < line)
			{
				pos = text.indexOf("\r", pos) + 1;
				if (pos == -1) break;
				count++;	
			}
			
			var pos2:int = text.indexOf("\r", pos);
			if (pos2 == -1) pos2 = text.length;
			if (pos2 == pos) return null;
			
			return text.substring(pos, pos2);			
		}
		
		private function replaceLineOfText(text:String, line:int, newText:String):String
		{
			var count:int = 0;
			var pos:int = 0;
			while (count < line)
			{
				pos = text.indexOf("\r", pos) + 1;
				if (pos == -1) break;
				count++;	
			}
			
			var pos2:int = text.indexOf("\r", pos);
			if (pos2 == -1) pos2 = text.length;
			if (pos2 == pos) return text;

			return text.substring(0, pos) + newText + text.substring(pos2, text.length);						
		}
		
		private function setDone(args:Array):Object
		{
			var page:IWikiPage = this._app.wiki.currentPage;
			if (!page) return null;
			var text:String = page.text;
			
			var line:String = getLineOfText(text, args[0]);
			
			var todo:String = this._syntax.firstMatch(Syntax.RTodo, line);
			if (!todo) return null;
			
			var task:String = this._syntax.getField(Syntax.RTodo, Syntax.FieldTodoTask, todo);
			var due:String =  this._syntax.getField(Syntax.RTodo, Syntax.FieldTodoDue, todo);
			var doneD:String = Tools.strftime("%Y%m%d");

			var done:String = this._syntax.createFromArgs(Syntax.RDone, Syntax.FieldTodoTask, task, 
														                Syntax.FieldTodoDue, due,
														                Syntax.FieldTodoDone, doneD);

			line = line.replace(todo, done);
			
			page.text = replaceLineOfText(text, args[0], line);
			
			return null;	
		}

		private function setTodo(args:Array):Object
		{
			var page:IWikiPage = this._app.wiki.currentPage;
			if (!page) return null;
			var text:String = page.text;

			var line:String = getLineOfText(text, args[0]);
			var done:String = this._syntax.firstMatch(Syntax.RDone, line);
			if (!done) return null;
			
			var task:String = this._syntax.getField(Syntax.RDone, Syntax.FieldTodoTask, done);
			var due:String =  this._syntax.getField(Syntax.RDone, Syntax.FieldTodoDue, done);
			
			var todo:String = this._syntax.createFromArgs(Syntax.RTodo, Syntax.FieldTodoTask, task, Syntax.FieldTodoDue, due);
			
			line = line.replace(done, todo);
			page.text = replaceLineOfText(text, args[0], line);			
			
			return null;	
		}

		
	}
}