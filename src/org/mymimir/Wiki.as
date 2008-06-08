package org.mymimir
{
	import flash.data.SQLResult;
	import flash.errors.SQLError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import org.mymimir.Engine.Syntax;
	import org.mymimir.sdk.Events;
	import org.mymimir.sdk.IWiki;
	import org.mymimir.sdk.IWikiBackend;
	import org.mymimir.sdk.IWikiPage;
	import org.mymimir.sdk.Tools;
	import org.mymimir.sdk.WikiPageEvent;

	/**
	 * The Wiki.
	 *  
	 * @author stephansmola
	 * 
	 */
	public class Wiki extends EventDispatcher implements IWiki
	{
		private static const WIKI_GOTO_PAGE:String = "Wiki.GotoPage";
		private static const WIKI_SETTINGS_LOADED:String ="Wiki.SettingsLoaded";

		public static const settingPageInitialText:String = "pageInitialText";
		public static const settingHTMLPrefix:String = "htmlPrefix";
		public static const settingHTMLSuffix:String = "htmlSuffix";
			
		private static const RWikiLocation:RegExp = /^wiki:\/\/(.+)/;
		
		private var _backend:IWikiBackend;
		private var _firstPage:String;
		private var _currentPage:WikiPage;
		private var _nextPage:WikiPage;
		private var _todos:Array;
		private var _url:String;
		private var _name:String;
		private var _styleSheetUrl:String;
		
		private var _settings:XML;
		private var _syntax:Syntax;


		/**
		 * Constructor.
		 *  
		 * @param url Path of the Wiki
		 * 
		 */
		public function Wiki(url:String, name:String = null, firstPage:String = null)
		{
			super(null);
			this._name = name;
			this._firstPage = firstPage;
			this._url = url;
			this._backend = Application.getInstance().backend;
			this._backend.wiki = this;		
			this._backend.addEventListener(org.mymimir.sdk.Events.BACKEND_ERROR_FAILED_TO_OPEN, onFailedToOpen);	
		}
		
		
		
		public function create():void
		{
			this.doCreate();
		}
		
		private function onFailedToOpen(ev:Event):void
		{
			
		}
		

		public function get currentPage():IWikiPage
		{
			return this._currentPage;
		}
	
	
		public function get url():String
		{
			return this._url;
		}
	
		public function get name():String
		{
			return Tools.CDATAStrip(this._settings.name.text().toString());
		}
		
		public function set styleSheetURL(url:String):void
		{
			this._styleSheetUrl = url;
			if (this._currentPage)
				this._currentPage.dispatchEvent(new WikiPageEvent(org.mymimir.sdk.Events.WIKIPAGE_CHANGED, this._currentPage));
		}
		
		public function get styleSheetURL():String
		{
			if (this._styleSheetUrl) return this._styleSheetUrl;
			return this._backend.getStylesheetURL();
		}
	
		public function get syntax():Syntax
		{
			return this._syntax;
		}
	
		public function get backend():IWikiBackend
		{
			return _backend;
		}
		
	
		/**
		 * Create Wiki in directory.
		 * 
		 */		
		private function doCreate():void
		{
			if (this._backend.create())
			{
				this.dispatchEvent(new Event(org.mymimir.sdk.Events.WIKI_NEW));
				loadSettings();	
				this.loadFirstPage();
			}
			else
			{
				//TODO: ERROR
			}
		}
	
	
	
		private function onSettingsLoadedAfterLoad(ev:Event):void
		{
			this.dispatchEvent(new Event(org.mymimir.sdk.Events.WIKI_CHANGED));
			this.loadFirstPage();
			this.dispatchEvent(new Event(org.mymimir.sdk.Events.WIKI_LOADED));		// Tell everyone that's interested that we're done loading
			this.removeEventListener(Wiki.WIKI_SETTINGS_LOADED, this.onSettingsLoadedAfterLoad);			
		}
	
		/**
		 * Load the Wiki from hd. 
		 * 
		 */		
		public function load():void
		{
			if (this._backend.open())
			{
				this.addEventListener(Wiki.WIKI_SETTINGS_LOADED, this.onSettingsLoadedAfterLoad);
				loadSettings();
			}
			else
			{
				//TODO:Error
			}
		}

		/**
		 * load the first page of the wiki. 
		 * 
		 */		
		public function loadFirstPage():void
		{	
 			if (!this.firstPage)
			{	
				return;
			}
			else
				this.gotoPage(this.firstPage);							// Go to the first node in the tree			
		}
		
		
		/**
		 * Close wiki. 
		 * 
		 */		
		public function close():void
		{
			if (this._currentPage) this._currentPage.store();
			this.saveSettings();
			
			if (this._backend)
			{
				this._backend.close();
			} 
			
			this._currentPage = null;
			this._settings = null;
			this._firstPage = null;
		}
		
		
		
		private function cbSettingsSet(success:Boolean, ... args):void
		{
			if (success)
			{
				this.dispatchEvent(new Event(Wiki.WIKI_SETTINGS_LOADED));
			}
		}
		
		private function cbSettingsLoaded(success:Boolean, settings:XML, ... args):void
		{
			if (success)
			{
				this._settings = settings;
				this.dispatchEvent(new Event(Wiki.WIKI_SETTINGS_LOADED))
			}
			else
			{
				this._settings = Application.getInstance().getDefaultWikiSettings(this._name, this._firstPage);
				this._backend.setWikiSettings(this._settings, this.cbSettingsSet);
				this.dispatchEvent(new Event(Wiki.WIKI_SETTINGS_LOADED))
			}
		}
		
		/**
		 * Load settings. If there is a file settings.xml in the wiki directory, this will be read. 
		 * Otherwise, default settings are taken and the file will be created with these defaults.
		 */
		private function loadSettings():void
		{
			this._syntax = new Syntax(org.mymimir.Application.getInstance().getSyntaxDefinition());
			this._backend.getWikiSettings(this.cbSettingsLoaded);
			this._syntax.addRules(Application.getInstance().getWikiSyntaxDefinition());						
		}
		
		
		
		public function get firstPage():String
		{
			if (!this._firstPage)
			{
				this._firstPage = this._settings.firstpage.text().toString();
			}
			return this._firstPage;
		}
		
		public function set firstPage(value:String):void
		{
			this._firstPage = value;
			delete this._settings.firstpage;
			var nn:XML = new XML("<firstPage>" + this._firstPage + "</firstPage>");
			this._settings.appendChild(nn);			
		}
		

		public function get initialPageText():String
		{
			return this.getSetting(Wiki.settingPageInitialText);
		}		

		public function set initialPageText(value:String):void
		{
		}		

		
		public function set settings(value:XML):void
		{
			if (value) this._settings = value;
		}
		
		public function get settings():XML
		{
			return this._settings;
		}
		
		public function getViewSettings(name:String):XML
		{
			var vset:XMLList = this._settings.view.(@name == name);
			if ((!vset) || (!vset.length())) return null;
			return vset[0];
		}
		
		
		public function getConverterSettings(type:String):XML
		{
			var conv:XMLList = this._settings.converter.(@type == type);
			if ((!conv) || (!conv.length())) return null;
			return conv[0];				
		}
		
		/**
		 * Get syntax description from the wiki settings file 
		 * @return XML description of the syntax
		 * 
		 */		
		public function getSyntax():XML
		{
			var syn:XMLList =  this._settings.syntax;
			if ((!syn) || (!syn)) return null;
			return syn[0];		
		}
		
		/**
		 * Save the settings file. 
		 * 
		 */
		private function saveSettings():void
		{
			this._backend.setWikiSettings(this._settings);
		}
		
		/**
		 * Get a settings value. 
		 * @param attribute	
		 * @return Attribute value.
		 * 
		 */
		public function getSetting(attribute:String):String
		{
			var attrs:XMLList = this._settings..attribute.(@name == attribute);					// Get the nodes that have the attribute name
			if ((!attrs) || (!attrs.length())) 													// If there is none
				return Application.getInstance().getDefaultWikiSetting(attribute);					// ... get the applications default
			
			var attr:XML = attrs[attrs.length() - 1];											// Take the last node found, others are ignored
			
			var ret:String = String(attr[0].@value);											// get the value attribute
			if (ret == "") ret = Tools.CDATAStrip(attr.text().toString());						// If it's empty get the text of the node
			
			return ret;																			// Retourn what we found
		}
		
		
		/**
		 * Loads the page. The page object is already created and the contents is already loaded from file.
		 * This prepares everything and adds some event listeners. 
		 * @param page	The page to load
		 * 
		 */		
		private function loadPage(page:WikiPage):void
		{
			if (this._currentPage)
			{
				this._currentPage.removeEventListener(org.mymimir.sdk.Events.WIKIPAGE_STORED, this.onPageStored);
				this._currentPage.removeEventListener(org.mymimir.sdk.Events.WIKIPAGE_CREATED, this.onPageCreated);
			}
			
			this._currentPage = page;
			this._currentPage.addEventListener(org.mymimir.sdk.Events.WIKIPAGE_STORED, this.onPageStored);
			this._currentPage.addEventListener(org.mymimir.sdk.Events.WIKIPAGE_CREATED, this.onPageCreated);
			this._currentPage.store();

			this.dispatchEvent(new WikiPageEvent(org.mymimir.sdk.Events.WIKI_PAGE_LOADED, this._currentPage));
		}
				
		
		
		private function cbPageStored(success:Boolean, result:SQLResult, err:SQLError, page:IWikiPage, ... args):void
		{
			this.dispatchEvent(new Event(org.mymimir.sdk.Events.WIKI_CHANGED));	
		}
		
		/**
		 * Event handler. Called when a WikiPage stored its contents to a file. 
		 * @param ev	The event
		 * 
		 */		
		private function onPageStored(ev:WikiPageEvent):void
		{
/* 			this._db.begin();
			this._db.storePage(ev.page.name);
			this._db.storePageLinks(ev.page.name, ev.page.links);
			this._db.storeFT(ev.page.name, ev.page.text);
			this.updatePageTree();
			this._db.commit();
				
 */			
 /* 		
 			this._db.storePageAsync(ev.page.name);
 			this._db.storePageLinksAsync(ev.page.name, ev.page.links);
 			this._db.storePageTodosAsync(ev.page.name, ev.page.todos);
 			this._db.storeFTAsync(ev.page.name, ev.page.text);
 			this._db.processAsyncQueue();
 			
  */		
  			
  			this._backend.storePageData(ev.page, this.cbPageStored, ev.page);
  			this.updateTodos();
  			
  			if (this._nextPage)
 			{
 				var nextPage:WikiPage = this._nextPage;
 				this._nextPage = null;
				this.loadPage(nextPage);
 			}
		}
		
			
		
		/**
		 * Event handler. Called when a WikiPage was newly created. 
		 * @param ev	The event.
		 * 
		 */		
		private function onPageCreated(ev:WikiPageEvent):void
		{
			this.dispatchEvent(new Event(org.mymimir.sdk.Events.WIKI_CHANGED));
			//this._db.storePage(ev.page.name);
		}
		
		
		/**
		 * Go to the WikiPage with the given name 
		 * @param page	name of the page
		 * 
		 */		
		private function gotoPage(name:String):void
		{
			if (this._currentPage)
			{
				this._currentPage.update();
			}
			
			
			if ((this._currentPage) && (this._currentPage.isChanged)) 
			{
				this._nextPage = new WikiPage(name, this);
				this._currentPage.store();
			}			
			else this.loadPage(new WikiPage(name, this));
		}
		
		
		public function gotoPageByUrl(url:String):Boolean
		{
			if (!url.match(Wiki.RWikiLocation));
			
			var page:String = url.replace(Wiki.RWikiLocation, "$1");
			this.gotoPage(page);
			
			return true;
		}
		
		
		
		public function getPagesFiltered(filter:String = "", resultCB:Function = null):void
		{			
			this._backend.getPagesByFilter(filter, resultCB);
		}
		
		
		
		
		public function getTodos(resultCB:Function = null):void
		{
			this._backend.getTodos(resultCB);
		}
		
		public function get todos():Array
		{
			return this._todos;
		}
		
		
		private function cbUpdateTodosTodosGot(success:Boolean, todos:Array, ... args):void
		{
			if (success) this._todos = todos;
		}
		
		private function updateTodos():void
		{
			this._backend.getTodos(this.cbUpdateTodosTodosGot);
		}

		
		
		public function cbRenameCurrentPageLinkedByGot(success:Boolean, linkedBy:Array, oldName:String, newName:String, ... args):void
		{
			var page:IWikiPage = this.getPageInstance(oldName);
			
			if (page.rename(newName))
				this._backend.renamePage(oldName, newName);
			else return;

			for each (var pName:String in linkedBy)
			{
				var tPage:WikiPage = new WikiPage(pName, this);
				tPage.replaceLinks(oldName, newName);
				tPage.store(false);
			}
				
			this.dispatchEvent(new Event(org.mymimir.sdk.Events.WIKI_CHANGED));
			
		}
		
		public function renameCurrenPage(newName:String, replaceReferences:Boolean):void
		{
			var oldName:String = this._currentPage.name;
			if (replaceReferences)
			{
				this._backend.getLinkeByPages(oldName, this.cbRenameCurrentPageLinkedByGot, oldName, newName);
			}
			else
			{
				if (this._currentPage.rename(newName))
					this.dispatchEvent(new Event(org.mymimir.sdk.Events.WIKI_CHANGED));
			}
		}
		
		
		public function search(query:String, resultCB:Function):void
		{
			this._backend.searchFullText(query, resultCB);
		}
		
		
		public function getPageInstance(name:String):IWikiPage
		{
			if (name == this._currentPage.name) return this._currentPage;
			var ret:WikiPage = new WikiPage(name, this);
			return ret;
		}
		
	}
}