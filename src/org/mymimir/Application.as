package org.mymimir
{
	import flash.display.DisplayObject;
	import flash.display.NativeMenuItem;
	import flash.events.DataEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.ui.Keyboard;
	import flash.utils.unescapeMultiByte;
	
	import mx.containers.Canvas;
	import mx.controls.TextInput;
	import mx.core.UIComponent;
	import mx.core.WindowedApplication;
	import mx.events.ChildExistenceChangedEvent;
	import mx.events.MenuEvent;
	
	import org.mymimir.Backends.LocalStorage;
	import org.mymimir.Components.Dialogs.CDialogNewWiki;
	import org.mymimir.Components.Dialogs.CDialogRename;
	import org.mymimir.Components.Dialogs.DialogSettings;
	import org.mymimir.Converter.*;
	import org.mymimir.Views.*;
	import org.mymimir.Views.PageViews.*;
	import org.mymimir.sdk.Components.Dialogs.MYMDialogError;
	import org.mymimir.sdk.ConvFunctionHandlerManager;
	import org.mymimir.sdk.ConverterFactory;
	import org.mymimir.sdk.Events;
	import org.mymimir.sdk.IApplication;
	import org.mymimir.sdk.IConvFunctionHandler;
	import org.mymimir.sdk.IConverter;
	import org.mymimir.sdk.IURLHandler;
	import org.mymimir.sdk.IViewFunctionHandler;
	import org.mymimir.sdk.IWiki;
	import org.mymimir.sdk.IWikiBackend;
	import org.mymimir.sdk.IWikiPage;
	import org.mymimir.sdk.MYMError;
	import org.mymimir.sdk.MYMMessage;
	import org.mymimir.sdk.ModuleManager;
	import org.mymimir.sdk.Modules.IMYMModule;
	import org.mymimir.sdk.Protocols;
	import org.mymimir.sdk.Tools;
	import org.mymimir.sdk.URLHandler;
	import org.mymimir.sdk.URLHandlerManager;
	import org.mymimir.sdk.ViewFunctionHandlerManager;
	import org.mymimir.sdk.Views.IMYMView;
	import org.mymimir.sdk.WikiPageEvent;
	

	/**
	 * The Application object. Singleton. 
	 * @author stephansmola
	 * 
	 */	
	public class Application extends EventDispatcher implements IApplication
	{		
		private static var instance:Application = null;
		
		[Bindable] private var _debugInfo:Array = new Array();
		
		private var _appWindow:WindowedApplication = null;
		private var _appSettings:XML = null;
		private var _wiki:IWiki = null;
		private var _backend:IWikiBackend;
		private var _history:History = new History();
		private var _searchPath:File;
		
		private var _moduleLoader:ModuleLoader;
		private var _lhManager:URLHandlerManager;
		private var _cfhManager:ConvFunctionHandlerManager;
		private var _vfhManager:ViewFunctionHandlerManager;
		private var _moduleManager:org.mymimir.sdk.ModuleManager;
		
		private var _mainView:Canvas;
		private var _mainWikiView:IMYMView;
		
		
		
		
		/*** Instance handling
		/******************************************************************************************/
		
		
		/**
		 * AWApplication is a singleton. Get the instance. If no Application window is provided, no instance is created when there is none. 
		 * @param appWindow		The application window
		 * @return 				The instance
		 * 
		 */		
		public static function getInstance(appWindow:* = null):IApplication
		{
			if (!instance) 
				if (appWindow) instance = new Application(appWindow, arguments.callee);
				
			return instance;
		}	
			
		
		
		/**
		 * Constructor. AWApplication is a singleton 
		 * @param appWindow		The application window
		 * @param caller		The calling function. Used to handle singleton nature of the class.
		 * 
		 */		
		public function Application(appWindow:*, caller:Function = null)
		{
			this._backend = new LocalStorage();
			super(null);
			this._moduleLoader = new ModuleLoader(this, onModuleLoaded, onModuleLoadError);
			this._moduleLoader.addEventListener(ModuleLoader.ALL_MODULES_LOADED, onAllModulesLoaded);
			
			this._lhManager = new URLHandlerManager();
			this._cfhManager = new ConvFunctionHandlerManager();
			this._moduleManager = new ModuleManager();
			
			if (caller != Application.getInstance)
				throw new Error("Application is singleton. Call getInstance instead.");
				
			if (instance)
				throw new Error("Application is singleton. There alread is an instance.");	

			this._appWindow = appWindow as WindowedApplication;			
		}

		public function init():void
		{
			this.loadAppSettings();			
			ConverterFactory.addConverterType("HTML", HTMLConverter.getInstance);
		}		

		public function restoreLastState():void
		{
			this._appWindow.width = parseInt(this._appSettings.appWindow.@width);
			this._appWindow.height = parseInt(this._appSettings.appWindow.@height);
			this._appWindow.nativeWindow.x = parseInt(this._appSettings.appWindow.@x);
			this._appWindow.nativeWindow.y = parseInt(this._appSettings.appWindow.@y);
			if (this._appSettings.lastWiki.@path != "") 										// If lastWiki is set
			{
				var path:File = new File(this._appSettings.lastWiki.@path);								// And path exists
				if (path.exists) this.openWikiByPath(path);										// Open the Wiki
				else; //TODO: ERROR
			}
		}
		
		/**
		 * Close the application. Stores settings. unloads wiki. 
		 * 
		 */		
		public function close():void
		{
			if (this._wiki)
				this._appSettings.lastWiki.@path = this._wiki.url;

			this.closeWiki();																		// Close Wiki, when there is one
			this._appSettings.appWindow.@width = String(this._appWindow.width);
			this._appSettings.appWindow.@height = String(this._appWindow.height);
			this._appSettings.appWindow.@x = String(this._appWindow.nativeWindow.bounds.x);
			this._appSettings.appWindow.@y = String(this._appWindow.nativeWindow.bounds.y);
						
			var path:File = File.applicationStorageDirectory.resolvePath("pansophySettings.xml");  	// Save application settings
			var fs:FileStream = new FileStream;
			fs.open(path, FileMode.WRITE);
			fs.writeUTFBytes(this._appSettings.toXMLString());
			fs.close();			
		}


		/*** Attribute access
		/******************************************************************************************/

		public function get appWindow():DisplayObject
		{
			return this._appWindow;
		}


		public function getConverterFunctionHandler(func:String):IConvFunctionHandler
		{
			return this._cfhManager.getHandlerForFunction(func);
		}
			
		public function getViewFunctionHandler(func:String):IViewFunctionHandler
		{
			return this._vfhManager.getHandlerForFunction(func);
		}
			
		
		public function getCurrentPageName():String
		{
			if ((this._wiki) && (this._wiki.currentPage)) return this._wiki.currentPage.name;
			return "";
		}
		
		public function getCurrentWikiName():String
		{
			if (this._wiki) return this._wiki.name;
			return "";
		}
		
		public function setWikiStyleSheetURL(url:String):void
		{
			this._wiki.styleSheetURL = url;
		}
		
		
		public function getWikiStyleSheetURL():String
		{
			if (!this._wiki) return null;
			
			return this._wiki.styleSheetURL;	
		}
		
		/**
		 * Returns an object with values for global fieldnames for syntax/conversion, for example
		 * the datapath of the wiki so that it can be used as $datapath in the syntax and converter rules. 
		 * @return An array of the form [<field1>, <value1>, <field2>, <value2>, ...]
		 * 
		 */		
		public function getSyntaxGlobals():Object
		{
			var ret:Object = new Object;
			var glob:Object = new Object;
			/*
			glob.reg = Tools.regExpForStringG(org.mymimir.Engine.Syntax.FieldDatapath);
			glob.value = this._wiki.directoryData;
			ret[org.mymimir.Engine.Syntax.FieldDatapath] = glob;
			*/ 
			return ret;
		}
		
		public function get wiki():IWiki
		{
			return this._wiki;
		}

		public function get backend():IWikiBackend
		{
			return _backend;
		}

		/*** Debug test
		/******************************************************************************************/


		public static function debug(caller:Function, ... args):void
		{
			if (!instance) return;
			instance.addDebug(caller, args);
		}

		private function addDebug(caller:Function, args:Array):void
		{
			var str:String = args.toString();
			str.replace(/,/g, " ");
			
			var newNode:Object = new Object();
			newNode["text"] = str;
			this._debugInfo.push(newNode);
		}
		
		public function get debugList():Array
		{
			return this._debugInfo;
		}


		/*** Settings
		/******************************************************************************************/

		public function readXMLFromFile(file:String):XML
		{
			var inFile:File = new File(file);
			if (!inFile.exists) return null;
			var fs:FileStream = new FileStream;
			fs.open(inFile, FileMode.READ);
			try
			{
				var ret:XML = new XML(fs.readUTFBytes(inFile.size));
			}
			catch(err:TypeError)
			{
				throw new MYMError(MYMError.ErrorLoadXML, err.message, inFile.url);	
			}
			finally
			{
				fs.close();				
			}
			
			return ret;
		}

		public function updateAppSettings():void
		{
			var fWikiSettings:File = File.applicationDirectory.resolvePath("defaults/wikiSettings.xml");
			var wikiSettings:XML = this.readXMLFromFile(fWikiSettings.url);
			var fConverter:File = File.applicationDirectory.resolvePath("defaults/converter.xml");
			var converter:XML = this.readXMLFromFile(fConverter.url);
			var fSyntax:File = File.applicationDirectory.resolvePath("defaults/syntax.xml");
			var syntax:XML = this.readXMLFromFile(fSyntax.url);


			if (this._appSettings.wikiSettings[0] != wikiSettings)
			{	
				delete this._appSettings.wikiSettings;
				this._appSettings.appendChild(wikiSettings);
			}

			if (this._appSettings.syntax[0] != syntax)
			{	
				delete this._appSettings.syntax;
				this._appSettings.appendChild(syntax);
			}
				
			if (this._appSettings.converter[0] != converter) 
			{
				if (this._appSettings.converter[0])
					delete this._appSettings.converter;
				this._appSettings.appendChild(converter);	
			}
				
		}

		
		/**
		 * Load application settings. These are stored in the file pansophySettings.xml in the applicaiton sotrage directory.
		 * If no such file exists it will be created. 
		 * 
		 */		
		public function loadAppSettings():void
		{
			var path:File = File.applicationStorageDirectory.resolvePath("pansophySettings.xml");
			if (path.exists)																		// When there is a settings file
			{
				var fs:FileStream = new FileStream;
				fs.open(path, FileMode.READ);
				this._appSettings = new XML(fs.readUTFBytes(path.size));							// read its contents

				this.updateAppSettings();
 			}
			else																					// No settings file exists yet
			{
				File.applicationStorageDirectory.createDirectory();									// Create app storage
				_appSettings = <pansophy>
									<appWindow width="800" height="600" left="0" right="0" />
									<lastWiki path="" />
									<wikiSettings>
										<attribute name="pageInitialText" value="+ {func:pagename}" />
									</wikiSettings>
								</pansophy>;							// Init settings
			}		
		}
		

		/**
		 * 
		 * @param attribute
		 * @return 
		 * 
		 */
		public function getWikiSetting(attribute:String):String
		{
			if (!this._wiki) return null;
			return this._wiki.getSetting(attribute);
		}
		
		
		/**
		 *  
		 * @param attribute
		 * @return 
		 * 
		 */		
		public function getDefaultWikiSetting(attribute:String):String
		{
			var ret:String;
			var settings:XMLList = this._appSettings.wikiSettings..attribute.(@name == attribute);
			
			if ((!settings) || (!settings.length())) return null
			
			var setting:XML = settings[settings.length() -1];
			

			ret = String(setting.@value);
			if (ret == "") ret = Tools.CDATAStrip(setting.text().toString());
			
			return ret;
		}
		
		
		public function getDefaultWikiSettings(name:String, firstPage:String):XML
		{
			var wS:XMLList = this._appSettings.wikiSettings;
			var ret:XML;
			
			if ((!wS) || (!wS.length())) 
				ret =  <wikiSettings><name></name></wikiSettings>;
			else ret = wS[0];
			
			ret.name = new XML("<name>" + name + "</name>");	
			ret.firstPage = new XML("<firstpage>" + firstPage + "</firstpage>");
			
			return ret;
		}
		
		
		public function getViewSettings(name:String):XML
		{
			var vset:XML;
			if (this._wiki)	vset = this._wiki.getViewSettings(name);
			if (!vset)
			{
				var vsetl:XMLList = this._appSettings.view.(@name == name);
				if ((!!vsetl) || (!vsetl.length())) return null;
				vset = vsetl[0];
			}
			return vset;
		}
		
		public function getConverterSettings(type:String):XML
		{		
			var conv:XMLList = this._appSettings.converter.(@type == type);
			if ((!conv) || (!conv.length())) return null;
			return conv[0];		
		}

		public function getWikiConverterSettings(type:String):XML
		{
			var ret:XML = null;
			if (this._wiki)
				ret = this._wiki.getConverterSettings(type);
				
			if (ret) return ret;
			return null;			
		}

		
		/**
		 * Get the syntax desctription from the application settings.  
		 * @return XML Description of the syntax
		 * 
		 */		
		public function getSyntaxDefinition():XML
		{
			var syntax:XMLList = this._appSettings.syntax;
			if ((!syntax) || (!syntax.length())) return null;
			return syntax[0];
		}
		
		/**
		 * Get syntax description from the wiki settings  
		 * @return XML description of the syntax
		 * 
		 */		
		public function getWikiSyntaxDefinition():XML
		{
			var ret:XML = null;
			if (this._wiki)
				ret = this._wiki.getSyntax();
				
			if (ret) return ret;
			return null;						
		}


		/*** Module handling
		/******************************************************************************************/

		
		private function onAllModulesLoaded(ev:Event):void
		{
			this.showCurrentWikiPage();		
		}
		
				
		private function onModuleLoaded(loadedObject:Object, name:String, source:String):void
		{
			// Add module to the manager
			var module:IMYMModule = loadedObject as IMYMModule;
			if (module) this._moduleManager.addModule(module);
			
			// Check if it's a converter function handler. var is null otherwise
			var convFuncHandler:IConvFunctionHandler = loadedObject as IConvFunctionHandler;
			if (convFuncHandler) this._cfhManager.addHandler(convFuncHandler);
			
			// Check if it's a view function handler. var is null otherwise
			var viewFuncHandler:IViewFunctionHandler = loadedObject as IViewFunctionHandler;
			if (viewFuncHandler) this._vfhManager.addHandler(viewFuncHandler);
			
			// Check if it's a url handler.
			var urlHandler:IURLHandler = loadedObject as IURLHandler;
			if (urlHandler) this._lhManager.addLocationhandler(urlHandler);
		}

		private function onModuleLoadError(name:String = null, source:String = null, errorText:String = null):void
		{
				var err:MYMError = new MYMError(MYMError.ErrorLoadingModule, errorText, source);
			 	var pop:MYMDialogError = new MYMDialogError();
				pop.message = err.message;
				pop.additional = err.info;
				pop.popUpModal(this._appWindow);
		
		}

		public function loadModule(name:String, source:String, description:XML):void
		{
			this._moduleLoader.loadModule(name, source, description);
		}
		
		private function loadInternalModules():void
		{
			this._lhManager = new URLHandlerManager();
			this._cfhManager = new ConvFunctionHandlerManager();
			this._vfhManager = new ViewFunctionHandlerManager();
			this._moduleManager = new ModuleManager();

			loadModule("org.mymimir.functions", "internal", null);
			loadModule("org.mymimir.urlHandler", "internal", null);
		}

		/*** View handling
		/******************************************************************************************/

		public function set mainView(view:Canvas):void
		{
			this._mainView = view;
		}		
		
		
		private function destroyViews():void
		{
			if (this._mainWikiView)
			{
				this._mainWikiView.dispose();
				this._mainWikiView = null;
			}
			
			this._mainView.removeAllChildren();
		}
		


		public function addView(parent:UIComponent, name:String, source:String, description:XML):void
		{
			try
			{
				this._moduleLoader.loadModule(name, source, description, parent);
			}
			catch(err:MYMError)
			{
				var em:MYMDialogError = new MYMDialogError();
				em.message = err.message;
				em.alpha = 1.0;
				em.popUpModal(this._appWindow);
				
				var ev:ErrorView = new ErrorView(description);
				ev.content(name, source, err.message, this._wiki.backend.getWikiSettingsURL());
				parent.addChild(ev);
			}
		}
		
		
		
		private function onMainWikiViewLoaded(ev:ChildExistenceChangedEvent):void
		{
			var view:IMYMView = ev.relatedObject as IMYMView;
			this._mainWikiView = view;
			view.addEventListener(org.mymimir.sdk.Events.VIEW_LOCATION_CHANGE, onViewLocationChange);
			view.wiki = this._wiki;	
			this._lhManager.addLocationhandler(view);	
			this.showCurrentWikiPage();					
		}
		
		
		/**
		 * Create the views.
		 * 
		 */		
		private function createViews():void
		{
			if (!this._wiki) return;
					
			var vds:XMLList = this._wiki.settings.view;
			
			if ((vds) && (vds.length()))
			{
				var vd:XML = vds[vds.length() - 1];
	
				this._mainView.addEventListener(ChildExistenceChangedEvent.CHILD_ADD, onMainWikiViewLoaded);
				this.addView(this._mainView, vd.@name, vd.@source, vd)
				
				if (vds.length() > 1)
				{
					MYMMessage.popUpToInform(Application.getInstance().appWindow, "Multiple Root Views", 
											 MYMMessage.MessageMultipleRootViews, vds.length.toString());
				}
			}
		}	

		
		/**
		 * Create application title. If theres a HTML-Converter, this tries to get the title-tag-text to use it as the Application title. 
		 * @return Title string
		 * 
		 */		
		private function determineAppTitle():String
		{
			var pHtml:XML
			var title:XMLList;
			
 			try
			{
				var conv:IConverter = ConverterFactory.getConverter("HTML");
				if (conv)
				{
					pHtml = new XML(conv.convertText(this._wiki.currentPage.text));
					title = pHtml..title;
				}
			}
			catch (e:TypeError)
			{
				title = null;		
			}
			var titleStr:String;
			
			if ((title) && (title.length()))	
				titleStr = Tools.CDATAStrip(title[0].text().toString());
			if ((titleStr == null) || (titleStr == "")) titleStr = this.getCurrentWikiName() + " - " + this.getCurrentPageName();
			return titleStr;
		}
		



		/*** Wiki handling
		/******************************************************************************************/

				
		/**
		 * Load a wiki from a directory. If no such wiki exists it will be created. 
		 * @param path	The path to the directory.
		 * 
		 */		
		private function openWikiByPath(path:File):void
		{
			this.closeWiki();			
			this._wiki = new Wiki(path.url);
			this._wiki.addEventListener(org.mymimir.sdk.Events.WIKI_LOADED, onWikiLoaded);
			this._wiki.addEventListener(org.mymimir.sdk.Events.WIKI_PAGE_LOADED, onWikiPageLoaded);	
			this._wiki.load();
		}
		
		
		/**
		 * Close the wiki if one is loaded. 
		 * 
		 */		
		private function closeWiki():void
		{

			if (this._wiki) 
			{
				if (this._mainWikiView)
				{
					var viewDesc:XML = this._mainWikiView.description;
					var wSets:XML = this._wiki.settings;
				
				
					/* Store new view settings. This has to be redone in order to not destroy view code when there were problems */
					delete wSets.view;
					wSets.appendChild(viewDesc);
					this._wiki.settings = wSets;
				
				}
				this._wiki.close();
				this._wiki = null;
			}
			
			
			/* Clean up module manager. This calls the cleanUp Method of all modules givnig them e.g. the opportunity to save data */
			this._moduleManager.cleanUp();
			
			/* Remove alle references in Handlermanagers*/			
			if (this._lhManager) this._lhManager.clear();
			if (this._cfhManager) this._cfhManager.clear();
			if (this._vfhManager) this._vfhManager.clear();
			if (this._moduleManager) this._moduleManager.clear();
			
			/* Destroy the views */
			this.destroyViews();
			
			/* Clear the converter factory so new instances will be created */
			org.mymimir.sdk.ConverterFactory.clear();
		}
		
		
		/**
		 * Event handler. Called when the wiki is done loading itself. 
		 * @param ev
		 * 
		 */		
		private function onWikiLoaded(ev:Event):void
		{
			this.destroyViews();
			this.loadInternalModules();
			this.createViews();
		}
		
		
		

		/*** Interface handling
		/******************************************************************************************/

		/**
		 * 
		 * @param ev
		 * 
		 */
		public function onBtnFindClick():void
		{
		}

		/**
		 * 
		 * @param ev
		 * 
		 */
		public function onInpQueryEnter(ev:Event):void
		{
			var inp:TextInput = ev.target as TextInput;
			if (!inp) return;
			if (inp.text == "") return;
			this.gotoURL(org.mymimir.sdk.Protocols.SearchProtocol + inp.text);
		}
		
		
		
		/**
		 * 
		 * @param ev
		 * 
		 */
		public function onButtonBackClick(ev:Event):void
		{
			if (this._history.goBack())
				this.gotoURL(this._history.current);
		}
		
		/**
		 * 
		 * @param ev
		 * 
		 */
		public function onButtonForwardClick(ev:Event):void
		{
			if (this._history.goForward())
				this.gotoURL(this._history.current);
		}
		
		
		
		/**
		 * 
		 * @param ev
		 * 
		 */
		public function onMenuItemClick(ev:MenuEvent):void
		{
			this.doMenuCommand(ev.item.@data);			
		}
		
		/**
		 * 
		 * @param ev
		 * 
		 */
		public function onNativeMenuItemClick(ev:Event):void
		{
			var item:NativeMenuItem = ev.target as NativeMenuItem;
			var comm:String;
			var handled:Boolean;
			
			comm = item.data as String;
			
			/* Special Handling for paste: TODO: Maybe add for all other events as well */
			if ((item.data == "Edit.Paste") || 
				((item.keyEquivalent == "v") && (item.keyEquivalentModifiers.length == 1) && (item.keyEquivalentModifiers[0] == flash.ui.Keyboard.COMMAND)))
			{
				comm = "Edit.Paste";
				handled = this.handlePaste();
			}
			else if ((item.data == "Edit.SelectAll") || 
				((item.keyEquivalent == "a") && (item.keyEquivalentModifiers.length == 1) && (item.keyEquivalentModifiers[0] == flash.ui.Keyboard.COMMAND)))
			{
				comm = "Edit.Paste";
				handled = this.handleSelectAll();
			}

			if (!handled) this.doMenuCommand(comm);
			else ev.preventDefault();
		}
		
		/**
		 * 
		 * @param comm
		 * 
		 */
		private function doMenuCommand(comm:String):void
		{
			switch (comm)
			{
				case "Edit.Copy":	   this._appWindow.nativeApplication.copy();
									   break;
									   
				case "Edit.Cut":	   this._appWindow.nativeApplication.cut();
									   break;
									   
				case "Edit.Paste":	   this._appWindow.nativeApplication.paste();
									   break;
									   
				case "Wiki.Exit":      this.close(); this._appWindow.exit();
								       break;
								    
				case "Wiki.New":       this.newWiki();
								       break;
								    
				case "Wiki.Open":      this.openWiki();
								       break;
								    
				case "Wiki.Settings":  this.openWikiSettings();
									   break;
								    
								    
				case "Wiki.ViewSetup": this.startViewSetup();
									   break;								    
								    
				case "Page.Rename":    this.renameCurrentPage();
				                       break;
			}			
		}
		
		
		
		private function startViewSetup():void
		{
			this._mainWikiView.enableViewSetupMode();
		}
		
		
		
		/**
		 * The paste event comes from the native menu. This passes it forward to anything that's interested in it.
		 * @return 	Paste processed?
		 * 
		 */
		private function handlePaste():Boolean
		{
			var prevent:Boolean = this._moduleManager.handlePaste();
			return prevent;
		}
		

		/**
		 * The select all event comes from the native menu. This passes it forward to anything that's interested in it.
		 * @return 	Paste processed?
		 * 
		 */
		private function handleSelectAll():Boolean
		{
			var prevent:Boolean = this._moduleManager.handleSelectAll();
			return prevent;
		}


		
		/**
		 * Called when the user selets a directory when browsing for a wiki to open.
		 * @param ev	Event
		 * 
		 */
		private function onOpenWikiSelect(ev:Event):void
		{
			this._searchPath = ev.target as File;
			this.openWikiByPath(this._searchPath);
		}
		
		/**
		 * Display a directory open dialog and openthe wiki when selected. 
		 * 
		 */
		private function openWiki():void
		{
			if (! this._searchPath) this._searchPath = File.documentsDirectory;
			this._searchPath.browseForDirectory("The Wiki in which directory do you want to load");
			this._searchPath.addEventListener(Event.SELECT, onOpenWikiSelect);
		}
		
		/**
		 * Event handler. Called when the user clicked the "Create" button in the new Wiki dialog. 
		 * @param ev Event
		 * @see newWiki
		 */		
		private function onNewWikiCreate(ev:Event):void
		{
			var dialog:CDialogNewWiki = ev.target as CDialogNewWiki;
			var dData:Object = dialog.getData();
			var name:String = dData[CDialogNewWiki.DataWikiName];
			var firstPage:String = dData[CDialogNewWiki.DataFirstPage];
			var dirUrl:String = dData[CDialogNewWiki.DataDirectory];
			
			if ((name != "") && (firstPage != "") && (dirUrl != ""))
			{
				if (this._wiki) this._wiki.close();
				this._wiki = new Wiki(dirUrl + "/" + name, name, firstPage);
				this._wiki.create();
				this._wiki.close();
				this._wiki = null;
				this.openWikiByPath(new File(dirUrl + "/" + name));
			}
		}
		
		/**
		 * Opens a pop up to ask the user to enter some data inorder to create a new Wiki. 
		 * @see onNewWikiCreate
		 */
		private function newWiki():void
		{
			var dialog:CDialogNewWiki = new CDialogNewWiki();			
			dialog.addEventListener(org.mymimir.Components.Dialogs.CDialogNewWiki.EventCreate, onNewWikiCreate);
			dialog.popUpModal(this._appWindow);			
		}
		
		
		/**
		 * Called when the current page was renamed. 
		 * @param ev
		 * 
		 */
		private function onCurrentPageRename(ev:Event):void
		{
			var dialog:CDialogRename = ev.target as CDialogRename;
			var data:Object = dialog.getData();
			this._wiki.renameCurrenPage(data[CDialogRename.DataNewName], data[CDialogRename.DataReplaceLinks]);
		}
		
		/**
		 * Called when the user select "Rename" from the page menu 
		 * 
		 */		
		private function renameCurrentPage():void
		{
			var dialog:CDialogRename = new CDialogRename();
			dialog.addEventListener(CDialogRename.EventRename, onCurrentPageRename);
			dialog.popUpModal(this._appWindow);	
		}
				
		
		
		/**
		 * Open the wiki settings dialog. 
		 * 
		 */
		private function openWikiSettings():void
		{
			var dialog:DialogSettings = new DialogSettings();
			dialog.popUpModal(this._appWindow);
		}
		
		
		/**
		 * Return the page instance for the given wiki url. 
		 * @param url	The url
		 * @return 		The instance of the page according to the url. Null if no page for that url exists.
		 * 
		 */
		public function getPageByURL(url:String):IWikiPage
		{
			if (!url) return null;
			var pn:String = url.substring(org.mymimir.sdk.Protocols.WikiPageProtocol.length, url.length);
			if (url == this._wiki.currentPage.url) return this._wiki.currentPage;
			this._wiki.gotoPageByUrl(url);			// This will call gotoURL and this will call the view again so we tell the caller to do nothing
			return null;
		}
		
		


		/*** URL handling
		/******************************************************************************************
		 * How urls are called
		 * 
		 * Central function is gotoURL. All calling of URLs uses this function: 
		 * It decides if the URL is a WikiPage-URL or something else. If it is a Wiki-URL it tell the Wiki to load that page.
		 * Otherwise it calls showLoaction.
		 * 
		 * gotoURL is called from either normal code or several EventHandlers, e.g. the one that's called when a pages requests
		 * a location change. Exception is the handler that's called when the WikiPage is loaded, as it, indirectly is triggered
		 * by gotoURL itself. That eventHandler calls showURL;
		 * 
		 * showURL decides in which view to display the URL. It uses the protocol of the location to do that. Views can register themselves
		 * for different protocols they are able to display. If the current visible view each view area is able to display the URL, it is used.
		 * If a different view in that view area is able to display the view, that one will be brought forth. Otherwise the viewArea stays unchanged.
		 * 
		 * showCurentWikiPage is just a simple helper to open the current page of a Wiki. It calls gotoURL, of course.
		 * 
		*/


		/**
		 * Show a url location. If there is a handler for the given location this will be handling the location. If the location 
		 * is no file location it will be part of the history. TODO: Better handling for what location should be part of history. Config. 
		 * @param location
		 * 
		 */
		private function showLocation(location:String):void
		{
			var handler:IURLHandler = this._lhManager.getHandlerFor(location);
			if (handler) 
				if (handler.handleLocation(location)) 
					if (!URLHandler.isFileURL(location)) 
						this._history.current = location;				
		}


		/**
		 * Go to an URL. The url can be a wiki page, a search path, a file link, etc... 
		 * @param location
		 * 
		 */
		public function gotoURL(location:String):void
		{
			location = flash.utils.unescapeMultiByte(location); 
			var st1:String = unescape(location);
			var st2:String = flash.utils.unescapeMultiByte(location);
			
			if (URLHandler.isWikiLocation(location))
			{
				if (this._wiki) this._wiki.gotoPageByUrl(location);
			}
			else showLocation(location);
		}

		/**
		 * Event handler. Called when the wiki is done loading a page. 
		 * @param ev	WikiPageEvent.
		 * 
		 */		
		private function onWikiPageLoaded(ev:WikiPageEvent):void
		{
			this._history.current = ev.page.url;
			this.showLocation(this._history.current);

			this._appWindow.title = this.determineAppTitle();
		}


		/**
		 * Event handler. Called, when a view wants to change the location. 
		 * @param ev
		 * 
		 */
		private function onViewLocationChange(ev:DataEvent):void
		{
			this.gotoURL(ev.data);
		}

		/**
		 *Show the current page of the wiki 
		 * 
		 */
		private function showCurrentWikiPage():void
		{
			if (!this._wiki) return;
			
			if (!this._wiki.currentPage) this._wiki.loadFirstPage();
			else
			this.gotoURL(this._wiki.currentPage.url);
		}


		/**
		 * Search the wiki. The wiki query will be passed to a handler that can handle a search url 
		 * @param query			The query to search for
		 * @param resultCB		The callback function that will be called after the search is done
		 * @param args			Any additional args that will be passed to the resultCallback
		 * 
		 */
		public function searchWiki(query:String, resultCB:Function, ... args):void
		{
			if (!this._wiki) return;
			this._wiki.backend.searchFullText(query, resultCB, args);
		}

	}
}