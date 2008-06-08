package org.mymimir.Views
{
	import mx.controls.TextArea;
	
	import org.mymimir.sdk.Views.MYMView;

	public class ErrorView extends MYMView
	{
		public function ErrorView(description:XML)
		{
			
			super(description);
		}
		
		
		public function content(name:String, source:String, errText:String, filePath:String):void
		{
			var text:TextArea = new TextArea();
			text.editable = false;
			this.setWidthHeight(text);
			this.addChild(text);
			
			var msg:String = "<font size=\"14\"><b>Error loading module</b></font>\r" + 
							 "Module <b><i>"+ name + "</i></b> could not be loaded.\r" + 
						     "The specified source was <b><i>" + source + "</i></b>\r\r" + 
						     "<b><font size=\"12\">The module loader reported</font></b>\r" + 
						     errText +
						     "\r\r" +
						     "You can find the settings file of the Wiki at <b>" + filePath + "</b>";
						     
						     
			text.htmlText = msg;
		}
		
		override public function get title():String
		{
			return "Error";
		}
		
	}
}