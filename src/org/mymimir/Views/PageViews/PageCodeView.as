package org.mymimir.Views.PageViews
{
	import flash.events.Event;
	
	import mx.controls.TextArea;
	
	import org.mymimir.Application;
	import org.mymimir.sdk.IURLHandler;
	import org.mymimir.sdk.IWikiPage;
	import org.mymimir.sdk.MYMMessage;
	import org.mymimir.sdk.Protocols;
	import org.mymimir.sdk.URLHandler;
	
	/**
	 * Page view for displaying the HTML code created by the HTML converter 
	 * @author stephansmola
	 * 
	 */
	public class PageCodeView extends PageGenericHTMLView implements IURLHandler
	{
		private static var Protocols:Array = new Array(org.mymimir.sdk.Protocols.WikiPageProtocol);
		
		private var _code:TextArea;

		public function PageCodeView(description:XML)
		{
			this._title = "Converted HTML"
			
			super(description);
			this._protocols = PageCodeView.Protocols;
			
			_code = new TextArea;
			_code.percentHeight = 100;
			_code.percentWidth = 100;
			_code.editable = false;
			this.addChild(this._code);
		}

		override public function get supportedProtocols():Array
		{
			return PageCodeView.Protocols;
		}

		
		override public function handleLocation(location:String):Boolean
		{
			if (!URLHandler.isWikiLocation(location)) return false;
			var page:IWikiPage = Application.getInstance().getPageByURL(location);
			if (page) 
			{
				this._page = page;
				
				var html:XML;
			 	try
				{
					html = new XML(this.converter.convertText(this._page.text));
					this._code.text = html.toXMLString();
				}
				catch(er:TypeError)
				{
					//org.mymimir.sdk.PSYMessage.popUpToInform(this, "Oops", er.message);
					this._code.text = this.converter.convertText(this._page.text);
				} 
				
				this.dispatchEvent(new Event(org.mymimir.sdk.Events.VIEW_DEMAND_DISPLAY));						
				return true;
			}
			return false;
		}
		
		
	}
}