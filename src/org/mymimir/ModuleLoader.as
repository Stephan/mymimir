package org.mymimir
{
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import mx.core.UIComponent;
	import mx.events.ModuleEvent;
	import mx.modules.IModuleInfo;
	import mx.modules.ModuleManager;
	
	import org.mymimir.InternalModules.InternalFunctionHandler;
	import org.mymimir.InternalModules.InternalURLHandler;
	import org.mymimir.Views.*;
	import org.mymimir.Views.PageViews.*;
	import org.mymimir.sdk.IApplication;
	import org.mymimir.sdk.Modules.IMYMModule;
	import org.mymimir.sdk.MYMError;
	import org.mymimir.sdk.Views.IMYMView;
	import org.mymimir.sdk.Views.MYMViewModule;

	public class ModuleLoader extends EventDispatcher
	{
		public static const ALL_MODULES_LOADED:String = "ModuleLoader.AllModulesLoaded";	
		
		private var _app:IApplication;
		private var _schedule:Array;
		private var _currentTask:Object;
		private var _moduleInfo:IModuleInfo;
		
		private var _loadedCB:Function;
		private var _errorCB:Function;
		
		
		public function ModuleLoader(app:IApplication, loadedCB:Function, errorCB:Function)
		{
			this._app = app;
			this._schedule = new Array();
			this._loadedCB = loadedCB;
			this._errorCB = errorCB;
		}
		
		public function loadModule(name:String, source:String, description:XML, parent:UIComponent = null):void
		{
			var reg:RegExp = /^\/(Modules\/.+)/;
			
			var task:Object = new Object;
			task["parent"] = parent;
			task["name"] = name;
			task["description"] = description;
			task["source"] = source;
			
			this._schedule.push(task);
			
			if ((this._schedule.length == 1) && (!this._currentTask))
				this.nextTask();
		}
		
		
		
		
		private function nextTask():void
		{
			if (!this._schedule.length) 
			{
				this.dispatchEvent(new Event(ModuleLoader.ALL_MODULES_LOADED));
				return;
			}
			
			this._currentTask = this._schedule.shift();
			
			if (this._currentTask["source"] == "internal") loadInternalModule()
			else
			{
				this._moduleInfo = ModuleManager.getModule(this._currentTask["source"]);	
				this._moduleInfo.addEventListener(mx.events.ModuleEvent.READY, onModuleReady);
				this._moduleInfo.addEventListener(mx.events.ModuleEvent.ERROR, onModuleError);
				this._moduleInfo.load();
			}
		}
		
		
		private function loadInternalModule():void
		{
 			var view:IMYMView;
 			var object:Object;
 			var description:XML = this._currentTask["description"];
 			
 			
			switch(this._currentTask["name"])
			{
				case "org.mymimir.editor": 		object = new PageEditor(description); 
										   			break;
										   			
				case "org.mymimir.html": 			object = new PageHTMLView(description); 
										   			break;
										   			
				case "org.mymimir.code": 			object = new PageCodeView(description); 
										   			break;
										   
				case "org.mymimir.tree": 			object = new TreeView(description);
										 			break;

				case "org.mymimir.tabbedView": 	object = new TabbedView(description); 
										   			break;

				case "org.mymimir.tripleView": 	object = new TripleView(description); 
										   			break;
										   			
				case "org.mymimir.hDivided":		object = new HDividedView(description);
													break;
										   
				case "org.mymimir.debug": 			object = new DebugView(description);
													break;
													
													
				case "org.mymimir.functions":		object = new InternalFunctionHandler();
													break;

				case "org.mymimir.urlHandler":		object = new InternalURLHandler();
													break;
										
				default:	throw new MYMError(MYMError.ErrorUnknownView, "", this._currentTask["name"], this._currentTask["source"]);
			}
			
			// Do module initialisation if necessary
			var module:IMYMModule = object as IMYMModule;
			if (module)
				module.init(_app, description);	

			
			// If it's a view module, we'll have to add it to its designated parent
			view = object as IMYMView;
			if (view)
			{
				if (this._currentTask["parent"])
					this._currentTask["parent"].addChild(view as DisplayObject);
				else throw new MYMError(MYMError.ErrorViewNoParent, "", this._currentTask["name"], this._currentTask["source"]);
			}
			
			if (this._loadedCB != null) this._loadedCB.call(this, object, this._currentTask["name"], this._currentTask["source"]);
			
			this._currentTask = null;
			this.nextTask();
		}
		
		
		private function onModuleReady(ev:ModuleEvent):void
		{
			var loadedObject:Object;
			var view:MYMViewModule
			
			loadedObject = this._moduleInfo.factory.create();
			
			if (!loadedObject) throw new MYMError(MYMError.ErrorLoadingModule, ev.errorText);

			// Do module initialisation if necessary
			var module:IMYMModule = loadedObject as IMYMModule;
			if (module)
				module.init(_app, this._currentTask["description"]);	
			
			
			// If it's a view module, we'll have to add it to its designated parent
			view = loadedObject as MYMViewModule;
			if (view)
			{
				if (!module) view.init(_app, this._currentTask["description"]);	
				if (this._currentTask["parent"])
					this._currentTask["parent"].addChild(view);
				else throw new MYMError(MYMError.ErrorViewNoParent, "", this._currentTask["name"], this._currentTask["source"]);
			}	
						
			if (this._loadedCB != null) this._loadedCB.call(this, loadedObject, this._currentTask["name"], this._currentTask["source"]);

			this._moduleInfo = null;
			this._currentTask = null;
			
			this.nextTask();
		}
		
		
		
		private function onModuleError(ev:ModuleEvent):void
		{
			if (this._errorCB != null) 
				this._errorCB.call(this, this._currentTask["name"], 
								   this._currentTask["source"], 
								   ev.errorText);
/* 								   
			var errView:ErrorView = new ErrorView(this._currentTask["description"]);
			errView.content(this._currentTask["name"], this._currentTask["source"], ev.errorText);
			this._currentTask["parent"].addChild(errView);
			
 */								   
			this._moduleInfo = null;
			this._currentTask = null;
			
			this.nextTask();
			
		}
		
	}
}