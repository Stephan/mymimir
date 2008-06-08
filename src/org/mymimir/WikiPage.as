package org.mymimir
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import org.mymimir.Engine.Syntax;
	import org.mymimir.sdk.Events;
	import org.mymimir.sdk.IWikiPage;
	import org.mymimir.sdk.MYMError;
	import org.mymimir.sdk.MYMMessage;
	import org.mymimir.sdk.Protocols;
	import org.mymimir.sdk.WikiPageEvent;

	public class WikiPage extends EventDispatcher implements IWikiPage
	{	
		private static const wikiFileExtension:		String = ".wiki";
		 
//		private var _converter:IConverter;
		private var _wiki:Wiki;
		private var _changed:Boolean;
		private var _name:String;
		private var _text:String;
		private var _htmlText:String;
		private var _updateEventListener:Function;
		

		/**
		 * Constructor
		 * 
		 * @param name Name of the page. This is the unique identifier of the page in the whole wiki.
		 * @param wiki The wiki this page is part of
		 * 
		 */
		public function WikiPage(name:String, wiki:Wiki)
		{
			super(null);
			

			_wiki = wiki
			_name = name;
			
			if (!this.restore())																// Page does not exist yet
			{
				this._text = this._wiki.getSetting(Wiki.settingPageInitialText);
				this._changed = true;
				this.dispatchEvent(new WikiPageEvent(org.mymimir.sdk.Events.WIKIPAGE_CREATED, this));
			}
		}
		
		override public function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void
		{
			super.addEventListener(type, listener, useCapture, priority, useWeakReference);
			if (type == org.mymimir.sdk.Events.WIKIPAGE_UPDATE) this._updateEventListener = listener;
		}
		
		public function get name():String
		{
			return this._name;
		}
		
		public function get url():String
		{
			return org.mymimir.sdk.Protocols.WikiPageProtocol + this._name;
		}
		
		/**
		 * Get if WikiPage has changed.
		 * 
		 * @return true when WikiPage has changed, false otherwise
		 * 
		 */		
		public function get isChanged():Boolean
		{
			return _changed;
		}
		
		
		
		private function onUpdateErrorTimer(ev:Event):void
		{
			throw new MYMError(MYMError.ErrorPageUpdate, "", this._name);	
		}
		
		
		public function update():void
		{
			if (this._updateEventListener != null)
				this._updateEventListener(new WikiPageEvent(org.mymimir.sdk.Events.WIKIPAGE_UPDATE, this));
		}
		
		
		public function get text():String
		{
			return this._text;
		}
		
		public function set text(value:String):void
		{
			if (this._text != value)
			{
				this._text = value;
				this._changed = true;
				this.dispatchEvent(new WikiPageEvent(org.mymimir.sdk.Events.WIKIPAGE_CHANGED, this));
			}
		}
		
		
		/**
		 *  
		 * @return the HTML conversion of the page text 
		 * 
		 */		
/* 		public function get htmlText():String
		{
			if ((!this._htmlText) || (this._changed))
				this._htmlText =  this._converter.convertText(this._wiki.getSetting(Wiki.settingHTMLPrefix), false) +
				   				  this._converter.convertText(this._text) +
				   				  this._converter.convertText(this._wiki.getSetting(Wiki.settingHTMLSuffix), false);
			
			return this._htmlText;
		}
 */		
		/**
		 * 
		 * @return A File object for the page. Path is the pages path of the wiki plus <pageName>.wiki. 
		 * 
		 */		
/* 		private function getPageFile(name:String = null):File
		{
			if (!name) name = this._name;
			var dirPages:File = new File(this._wiki.directoryPages);
			var ret:File = dirPages.resolvePath(name + WikiPage.wikiFileExtension);
			return ret;
		}
 */		
 
 		protected function cbPageTextGot(success:Boolean, text:String, ... args):void
 		{
 			this._text = text;
			this.dispatchEvent(new WikiPageEvent(org.mymimir.sdk.Events.WIKI_PAGE_LOADED, this)); 			
 		} 
 
		/**
		 * Load page contents from file. The filename is <pageName>.wiki
		 * The Directory is the "Pages" directory of the Wiki directory. 
		 * 
		 */		
		public function restore():Boolean
		{
			if (!this._wiki.backend.checkPageExists(this._name))
				return false;
				
			this._wiki.backend.getPageText(this._name, cbPageTextGot);
			return true;
		/* 	var page:File = this.getPageFile();
			if (!page.exists) return false;
			
			var stream:FileStream = new FileStream;
			stream.open(page, flash.filesystem.FileMode.READ);
			this._text = stream.readUTFBytes(page.size);
			stream.close();
			
			this.dispatchEvent(new WikiPageEvent(org.mymimir.sdk.Events.WIKI_PAGE_LOADED, this));
			return true; */	
		}
		
		
		
		private function cbPageTextSet(success:Boolean, dispatch:Boolean, ... args):void
		{
			if (success)
			{
				if (dispatch)
				{
					var ev:WikiPageEvent = new WikiPageEvent(org.mymimir.sdk.Events.WIKIPAGE_STORED, this);
					this.dispatchEvent(ev);	
				}	
				this._changed = false;
			}		
		}
		
		/**
		 * Store the page contents to file.
		 * 
		 * @param dispatch	If set to true, this sends a WikiPage.eventStored.
		 * 
		 */		
		private function doStore(dispatch:Boolean = true):void
		{
			if (!this._changed) return;
			
			this._wiki.backend.setPageText(this._name, this.text, this.cbPageTextSet, dispatch);		
/* 			var file:File = getPageFile();
			var stream:FileStream = new FileStream;
			stream.open(file, FileMode.WRITE);
			stream.writeUTFBytes(this._text);
			stream.close();
			
			if (dispatch)
			{
				var ev:WikiPageEvent = new WikiPageEvent(org.mymimir.sdk.Events.WIKIPAGE_STORED, this);
				this.dispatchEvent(ev);	
			}	
			this._changed = false;
 */		}
		
		public function store(dispatch:Boolean = true):void
		{
			this.doStore(dispatch);		
		}
		
		
		public function get links():Array
		{
			this.update();
			return this._text.match(/\[([^\[\]<>]+)\]/g);
		}
		
		
		public function get todos():Array
		{
			this.update();
			var t:Array = this._wiki.syntax.allMatches(org.mymimir.Engine.Syntax.RTodo, this._text);
			var newEl:Object;
			var ret:Array = new Array();
			
			for each (var todo:String in t)
			{
				newEl = new Object();
				newEl.task = this._wiki.syntax.getField(Syntax.RTodo, Syntax.FieldTodoTask, todo);
				newEl.due = this._wiki.syntax.getField(Syntax.RTodo, Syntax.FieldTodoDue, todo);
				ret.push(newEl);
			}
			
			return ret;
		}
		
		
		private function cbPageRenamed(success:Boolean, newName:String, ... args):void
		{
			if (success)
			{
				this._name = newName;
				this._changed = true;
				this.dispatchEvent(new WikiPageEvent(org.mymimir.sdk.Events.WIKIPAGE_CHANGED, this));				
			}
			else
			{
				MYMMessage.popUpToInform(Application.getInstance().appWindow, 
										 "Operation failed", MYMMessage.MessagePageExists, newName);
				
			}
		}
		
		public function rename(newName:String):Boolean
		{
			if (this._wiki.backend.checkPageExists(newName))
			{
				MYMMessage.popUpToInform(Application.getInstance().appWindow, 
										 "Operation failed", MYMMessage.MessagePageExists, newName);
				return false;				
			}
			
			this._wiki.backend.renamePage(this._name, newName, cbPageRenamed);
			return true;
			
/* 			var file1:File = this.getPageFile();
			var file2:File = this.getPageFile(newName);
			
			if (file2.exists)
			{
				MYMMessage.popUpToInform(Application.getInstance().appWindow, 
										 "Operation failed", MYMMessage.MessagePageExists, newName);
				return false;
			}
			
			if (file1) file1.moveTo(file2, false);
			this._name = newName;
			this._changed = true;
			this.dispatchEvent(new WikiPageEvent(org.mymimir.sdk.Events.WIKIPAGE_CHANGED, this));
			
			return true;
 */		}
		
		
		public function replaceLinks(oldLink:String, newLink:String):void
		{
			var reg:RegExp = new RegExp("\\[" + oldLink + "\\]", "g");
			this._text = this._text.replace(reg, "[" + newLink + "]");
			this._changed = true;
			this.dispatchEvent(new WikiPageEvent(org.mymimir.sdk.Events.WIKIPAGE_CHANGED, this));
		}
		
	}
}