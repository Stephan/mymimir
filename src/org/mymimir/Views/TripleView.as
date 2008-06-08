package org.mymimir.Views
{
	import mx.containers.Canvas;
	import mx.containers.HDividedBox;
	import mx.core.UIComponent;
	import mx.events.ChildExistenceChangedEvent;
	
	import org.mymimir.Application;
	import org.mymimir.sdk.Tools;
	import org.mymimir.sdk.Views.IMYMView;

	public class TripleView extends CompositeView
	{

		private var _hBox:HDividedBox;
		private var _leftArea:Canvas;
		private var _rightArea:Canvas;
		
		public function TripleView(description:XML)
		{
			super(description);
			var descLeft:XMLList = description.leftPanel;
			var descRight:XMLList = description.rightPanel;
			var descCollaps:XMLList = description.collapsePanel;


			_hBox = new HDividedBox();		
			this.setMargins(_hBox, "0", "0", "0", "0");
			this.setWidthHeight(this._hBox);	
			this.addChild(this._hBox);
			
			this._leftArea = new Canvas();
			this._hBox.addChild(this._leftArea);			

			this._rightArea = new Canvas();
			this._hBox.addChild(this._rightArea);			
						
			initPanel(_leftArea, descLeft);			
			initPanel(_rightArea, descRight);	
		}
		
		override public function dispose():void
		{
			super.dispose();
			this._hBox.removeAllChildren();
			this._hBox = null;
			this._leftArea.removeAllChildren();
			this._leftArea = null;
			this._rightArea.removeAllChildren();
			this._rightArea = null;
		}
		
		
		private function initPanel(panel:UIComponent, desc:XMLList):void
		{
			if ((!desc) || (!desc.length())) return;
			
			Tools.setWidthFromAttribute(panel, desc[0], "width");
			panel.percentHeight = 100;

			var pd:XML = desc[0]; 			
			
			var views:XMLList = pd.view;
			if ((views) && (views.length()))
			{
				var vd:XML = views[0];				
				Application.getInstance().addView(panel, vd.@name, vd.@source, vd);
				panel.addEventListener(ChildExistenceChangedEvent.CHILD_ADD, this.onViewAdded);
			}
		}
		
		override public function handleLocation(location:String):Boolean
		{
			return super.handleLocation(location);
		}
		
	}
}