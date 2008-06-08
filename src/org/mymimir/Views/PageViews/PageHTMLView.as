package org.mymimir.Views.PageViews
{
	import flash.events.DataEvent;
	import flash.events.Event;
	
	import mx.controls.HTML;
	import mx.core.UIComponent;
	
	import org.mymimir.Application;
	import org.mymimir.sdk.Tools;
	import org.mymimir.Wiki;
	import org.mymimir.WikiPage;
	import org.mymimir.sdk.IURLHandler;
	import org.mymimir.sdk.IApplication;
	import org.mymimir.sdk.URLHandler;
	import org.mymimir.sdk.Views.MYMView;
	import org.mymimir.sdk.Protocols;
	import org.mymimir.sdk.WikiPageEvent;
	
	
	/**
	 * Page view to display the HTML created by the HTML converter as a webpage. 
	 * @author stephansmola
	 * 
	 */
	public class PageHTMLView extends PageGenericHTMLView implements IURLHandler
	{
		private static var Protcols:Array = new Array(Protocols.HTTPProtocol, Protocols.WikiPageProtocol, Protocols.SearchProtocol);
		private var _htmlView:HTML;
		private var _location:String;
		
		public function PageHTMLView(description:XML)
		{
			super(description);
			this._protocols = PageHTMLView.Protcols;
			_htmlView = new HTML();
			_htmlView.percentHeight = 100;
			_htmlView.percentWidth = 100;
			this.addChild(this._htmlView);
			
			this._htmlView.addEventListener(Event.LOCATION_CHANGE, onLocationChange);
			this._htmlView.addEventListener(Event.COMPLETE, onHTMLViewComplete);
		}
		
		
		private function onHTMLViewComplete(ev:Event):void
		{
			var loc:String;
			if (!this._htmlView.location)
				loc = this._location;
			else loc = this._htmlView.location;
			this._location = loc;
			if (URLHandler.isAppLocation(loc))
				_htmlView.htmlLoader.window.callAWFunc = this.callAWFunc;
		}
		
		private function callAWFunc(name:String):void
		{
			trace(name, arguments);
		}
		
		override public function init(app:IApplication, description:XML):void
		{
		}

		
		
		private function onLocationChange(ev:Event):void
		{
			this._location = this._htmlView.location;	
			this.dispatchEvent(new DataEvent(org.mymimir.sdk.Events.VIEW_LOCATION_CHANGE, false, false, this._htmlView.location));
		}
		
		
		private function onPageChanged(ev:WikiPageEvent):void
		{
			this._htmlView.htmlText = this.converter.convertText(this._page.text);			
		}
		
		
		override public function get title():String
		{
			return "HTML";
		}
		
		override public function handleLocation(location:String):Boolean
		{
			
			if (URLHandler.isWikiLocation(location))
			{
				super._page = Application.getInstance().getPageByURL(location);
				super._page.addEventListener(org.mymimir.sdk.Events.WIKIPAGE_CHANGED, onPageChanged);
				this._htmlView.htmlText = this.converter.convertText(this._page.text);
				this.dispatchEvent(new Event(org.mymimir.sdk.Events.VIEW_DEMAND_DISPLAY));
				return true;
			}
			else if (URLHandler.isWebLocation(location)) 
			{
				if (location != this._location) this._htmlView.location = location;
				this.dispatchEvent(new Event(org.mymimir.sdk.Events.VIEW_DEMAND_DISPLAY));
				return true;
			}
			else if (URLHandler.isSearchLocation(location))
			{
/* 				var query:String = location.substring(Protocols.SearchProtocol.length, location.length);
				var resTxt:String = this.createSearchResult(query, Application.getInstance().searchWiki(query));
				this._htmlView.htmlText = resTxt;
				this.dispatchEvent(new Event(org.mymimir.sdk.Events.VIEW_DEMAND_DISPLAY));
				return true;
 */			}
			return false; 
		}
		
		
		
		private function createResultDescription(query:String, words:String):String
		{
			var ret:String = words;
			query = Tools.stripWhiteSpace(query);
			var qWords:Array = query.split(" ");
			var regCaptures:RegExp = /([^\#]*)\#([^\#]+)\#([^\#]*)/g
			
			for each (var word:String in qWords)
			{
				var reg:RegExp = new RegExp("((?:[^\\s]+\\s){0,4})(\\w*" + Tools.stripWhiteSpace(word) + "\\w*)((?:\\s[^\\s]+){0,4})", "gi");
								
				ret = ret.replace(reg, "#$1<strong>$2</strong>$3#");
			}
			ret = ret.replace(regCaptures, " (...) $2");
			
			return ret + "(...)";
		}
		
		private function createSearchResult(query:String, results:Array):String
		{
			var ret:String;
			ret = "<h2 class=\"searchResult\">Search results for \"" + query + "\"</h2>"
			ret += "<p class=\"searchResultHits\"><strong>" + results.length.toString() + " hits</strong></p>";
			
			ret += "<dl class=\"searchRes\">";
			for each (var res:Object in results)
			{
				ret += "<dt><a class=\"wiki\" href=\"" + Protocols.WikiPageProtocol + res.page + "\">";
				ret += res.page + "</a></dt>";
				
				ret += "<dd>" + createResultDescription(query, res.words) + "</dd>";
			}
			
			ret += "</dl>";
			
			return ret;
		}
		
	}
}