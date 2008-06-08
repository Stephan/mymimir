package org.mymimir.Views.PageViews
{
	import flash.events.DataEvent;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.ui.Keyboard;
	
	import mx.containers.HDividedBox;
	import mx.controls.DataGrid;
	import mx.controls.dataGridClasses.DataGridColumn;
	
	import org.mymimir.Components.WikiEditor;
	import org.mymimir.Engine.Syntax;
	import org.mymimir.Application;
	import org.mymimir.sdk.Events;
	import org.mymimir.sdk.IApplication;
	import org.mymimir.sdk.IURLHandler;
	import org.mymimir.sdk.IWiki;
	import org.mymimir.sdk.IWikiPage;
	import org.mymimir.sdk.Protocols;
	import org.mymimir.sdk.Tools;
	import org.mymimir.sdk.Views.MYMView;
	import org.mymimir.sdk.WikiPageEvent;
	
	/**
	 * Page view for editing the wiki page text. 
	 * @author stephansmola
	 * 
	 */
	public class PageEditor extends MYMView implements IURLHandler
	{
		public static var AttributeInfo:XML = <attributes>
												<attribute name="fontFamily">
													Name of the font to use. Unlike in a full CSS implementation, comma-separated lists are not supported. 
													You can use any font family name. If you specify a generic font name, it is converted to an 
													appropriate device font. The default value is "Verdana".
												</attribute>
												<attribute name="fontSize">
													Height of the text, in pixels. The default value is 10.
												</attribute>
												<attribute name="color">
													Color of the text. Default is black. You can use CSS style colo notation like #000000.
												</attribute>
												<attribute name="backgroundColor">
													Background color of the editor. Default is white. You can use CSS style colo notation like #FFFFFF.
												</attribute>
											 </attributes>
										 
										 	 
		private static var TextAreaStyles:Array = ["fontFamily", "fontSize", "color", "backgroundColor"];
		private static var ViewName:String = "org.mymimir.editor";
		
		private static var Protocols:Array = new Array(org.mymimir.sdk.Protocols.WikiPageProtocol);
		
		
		private var _hBox:HDividedBox;
		private var _grid:DataGrid;
		private var _editor:WikiEditor;
		private var _page:IWikiPage;
		private var _syntax:Syntax;
		private var _locationChangeHandler:Function;

		public function PageEditor(description:XML)
		{
			super(description);
			this._protocols = PageEditor.Protocols;

			var saveInterval:int; 
			
			try {
				saveInterval = Tools.getIntFromXMLAttribute(description, "autoSaveInterval");
			} catch (er:TypeError) {
				saveInterval = 10000;
			}
				
			_editor = new WikiEditor(saveInterval);
			_editor.percentHeight = 100;
			_editor.percentWidth = 100;

			var debug:Boolean = Tools.getBooleanFromXMLAttribute(description, "debug");
			
			if (debug)
			{
				this._hBox = new HDividedBox();
				this.setWidthHeight(this._hBox);
				this.addChild(this._hBox);			
				
				this._hBox.addChild(this._editor);
				
				this._grid = new DataGrid();
				this.setWidthHeight(this._grid);
				this._hBox.addChild(this._grid);
				
				var cols:Array = new Array();
				var col:DataGridColumn;
				col = new DataGridColumn("text");
				cols.push(col);
				this._grid.columns = cols;
			}
			else this.addChild(this._editor);			
			
			
			_editor.editable = true;
			_editor.doubleClickEnabled = true;
			
			var attrs:XMLList = description.attributes();
			for each (var attr:XML in attrs)
				if (PageEditor.TextAreaStyles.indexOf(String(attr.name())) != -1)
					this._editor.setStyle(attr.name(), attr.toString());

			this._editor.liveUpdate = org.mymimir.sdk.Tools.getBooleanFromXMLAttribute(description, "liveUpdate");			
			
			this._syntax = new Syntax(Application.getInstance().getSyntaxDefinition());
						
			_editor.addEventListener(WikiEditor.eventTextChanged, onTextChange);
			_editor.addEventListener(WikiEditor.eventTextChangedLive, onTextChangeLive);
			_editor.addEventListener(MouseEvent.DOUBLE_CLICK, onEditorDoubleClick);
			_editor.addEventListener(KeyboardEvent.KEY_DOWN, onEditorKeyDown);
		}
		
		override public function init(app:IApplication, description:XML):void
		{			
			var settings:XML = app.getViewSettings(PageEditor.ViewName);
			if (settings)
			{
				for each (var attr:XML in settings.attr)
				{
					var n:String = new String(attr.@name);
					if (PageEditor.TextAreaStyles.indexOf(n) != -1)
						this._editor.setStyle(n, new String(attr.@value));
				}
			}
			
		}

		
		private function onPageChanged(ev:WikiPageEvent):void
		{
			this._editor.text = this._page.text;
		}
		
		private function onPageUpdate(ev:WikiPageEvent):void
		{
			this._page.text = this._editor.text;
		}
		
		override public function handleLocation(location:String):Boolean
		{
			if (this._page) 
			{
				this._page.text = this._editor.text;
				this._page.store();	
			}

			var page:IWikiPage = Application.getInstance().getPageByURL(location);
			if (page) 
			{
				this._page = page;
				this._page.addEventListener(org.mymimir.sdk.Events.WIKIPAGE_CHANGED, onPageChanged);
				this._page.addEventListener(org.mymimir.sdk.Events.WIKIPAGE_UPDATE, onPageUpdate);
				this._editor.text = this.wikiPage.text;
				this._editor.setSelection(0, 0);
				this.dispatchEvent(new Event(org.mymimir.sdk.Events.VIEW_DEMAND_DISPLAY));
			
				return true;
			}
			return false;
		}
		
		override public function get wikiPage():IWikiPage
		{
			return this._page;
		}
		
		override public function set wiki(wiki:IWiki):void
		{
			this._wiki = wiki;
			if (this._editor) this._editor.wiki = wiki;
		}
		
		override public function get title():String
		{
			return "Edit";
		}
		
		private function onTextChange(ev:Event):void
		{
			this.wikiPage.text = _editor.text;
			this.wikiPage.store();
		}
		
		private function onTextChangeLive(ev:Event):void
		{
			this.wikiPage.text = _editor.text;
		}
		
		
		private function checkLinkHit(line:String, rule:String, field:String):String
		{
			var cP:int = this._editor.getCurrentLinePos();
			var match:String;
			
			// Test WikiLink clicked
			var matches:Array = this._syntax.allMatches(rule, line);
			for each (match in matches)
			{
				var p:int = line.indexOf(match);
				if ((cP >= p) &&
				    (cP <= (p + match.length)))
				    {
				    	var link:String = this._syntax.getField(rule, field, match);
				    	return link;
				    }
			}			
			return null;
		}
		
		private function checkAnyLinkHit():void
		{
			var link:String;
			var l:String = this._editor.getCurrentLine();
			
			link = this.checkLinkHit(l, Syntax.RWikiLink, Syntax.FieldPageName)
			if (link) this.dispatchEvent(new DataEvent(org.mymimir.sdk.Events.VIEW_LOCATION_CHANGE, false, false, org.mymimir.sdk.Protocols.WikiPageProtocol + link));
			
			link = this.checkLinkHit(l, Syntax.RWebLink, Syntax.FieldURL)
			if (link) this.dispatchEvent(new DataEvent(org.mymimir.sdk.Events.VIEW_LOCATION_CHANGE, false, false, link));
		}
		
		private function onEditorDoubleClick(ev:MouseEvent):void
		{
			if (this.checkAnyLinkHit()) ev.preventDefault();
		}
		
		
		private function onEditorKeyDown(ev:KeyboardEvent):void
		{
			if (ev.keyCode == Keyboard.F2)
			{
				if (checkAnyLinkHit())	ev.preventDefault();
			} 
		}
		
		
		override public function doOnLeave():void
		{
			super.doOnLeave();
			this._page.text = this._editor.text;
		}
		
		override public function doOnEnter():void
		{
			super.doOnEnter();	
		}
		
		
		override public function handlePaste():Boolean
		{
			if (this._displayed) return this._editor.processSpecialPaste();
			return false;
		}
		
		override public function handleSelectAll():Boolean
		{
			if (this._displayed) 
			{
				this._editor.setSelection(0, this._editor.text.length);
				return true;
			}
			
			return false;
		}
		
	}
}