package org.mymimir.InternalModules
{
	import flash.net.URLRequest;
	
	import org.mymimir.sdk.IApplication;
	import org.mymimir.sdk.IURLHandler;
	import org.mymimir.sdk.Modules.MYMModule;
	import org.mymimir.sdk.Protocols;
	import org.mymimir.sdk.Tools;
	import org.mymimir.sdk.URLHandler;

	public class InternalURLHandler extends MYMModule implements IURLHandler
	{
		private var _protocols:Array;
		private var _port:String;

		public function InternalURLHandler()
		{
			super();
			this._protocols = [org.mymimir.sdk.Protocols.FileProtocol];
		}
		
		
		override public function init(app:IApplication, description:XML):void
		{
			super.init(app, description);
			
			this._port = "8080";
			if (description)
			{
				var port:String = org.mymimir.sdk.Tools.getStringFromXMLAttribute(description, "port");
				if (port) this._port = port;
			}
		}
		
		
		public function canHandleLocation(location:String):Boolean
		{
			return org.mymimir.sdk.URLHandler.isFileURL(location);
		}
		
		public function handleLocation(location:String):Boolean
		{
			this.callFile(location);
			return true;
		}
		
		public function get supportedProtocols():Array
		{
			return this._protocols;
		}
		
		private function callFile(url:String):void
		{
			var regW1:RegExp = /file:\/+(\w:[^:]*)/;
			var regW2:RegExp = /file:\/+(\/\/[^:]*)/;
			
			if (url.match(regW1)) url = url.replace(regW1, "$1");
			else if (url.match(regW2)) url = url.replace(regW2, "$1");
			else return;
			
			var fUrl:String = "http://localhost:" + this._port + "/helper.sts.org/" + url;
			var request:URLRequest = new URLRequest(fUrl);
			flash.net.sendToURL(request);
		}		
		
	}
}