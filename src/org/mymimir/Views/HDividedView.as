package org.mymimir.Views
{
	import mx.containers.HDividedBox;
	import mx.events.ChildExistenceChangedEvent;

	import org.mymimir.Application;
	
	
	public class HDividedView extends CompositeView
	{
		
		private var _hDBox:HDividedBox;
		
		public function HDividedView(description:XML)
		{
			super(description);
			
			_hDBox = new HDividedBox();		
			this.setMargins(_hDBox, "0", "0", "0", "0");
			this.setWidthHeight(this._hDBox);	
			this.addChild(this._hDBox);
			_hDBox.addEventListener(ChildExistenceChangedEvent.CHILD_ADD, this.onViewAdded);

			var views:XMLList = description.view;
			for each (var vd:XML in views)
				Application.getInstance().addView(_hDBox, vd.@name, vd.@source, vd)
		}
		
	}
}