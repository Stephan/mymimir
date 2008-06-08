package org.mymimir.Views.PageViews
{
	import org.mymimir.sdk.ConverterFactory;
	import org.mymimir.sdk.IConverter;
	import org.mymimir.sdk.IWikiPage;
	import org.mymimir.sdk.Views.MYMView;

	public class PageGenericHTMLView extends MYMView
	{
		protected var _page:IWikiPage;
		private var _converter:IConverter;
		
		public function PageGenericHTMLView(description:XML)
		{
			super(description);
			_converter = ConverterFactory.getConverter("HTML");
		}

				
		override public function get wikiPage():IWikiPage
		{
			return _page;
		}
		
		
		protected function get converter():IConverter
		{
			return _converter;
		}
		
		override public function get name():String
		{
			return "generic HTML view";
		}
	}
}