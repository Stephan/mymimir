package org.mymimir.Views
{
	import flash.display.DisplayObject;
	import flash.display.InteractiveObject;
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	import mx.containers.Canvas;
	import mx.containers.TabNavigator;
	import mx.core.Container;
	import mx.events.ChildExistenceChangedEvent;
	import mx.events.IndexChangedEvent;
	
	import org.mymimir.Application;
	import org.mymimir.sdk.IURLHandler;
	import org.mymimir.sdk.Views.IMYMView;

	public class TabbedView extends CompositeView
	{
		protected var _tabStrip:TabNavigator;
		
		public function TabbedView(description:XML)
		{
			super(description);
			this._tabStrip = new TabNavigator();
			this._tabStrip.addEventListener(flash.events.Event.CHANGE, onTabStripChange);
			this.setWidthHeight(this._tabStrip);
			this.addChild(this._tabStrip);
						
			var views:XMLList = description.view;
			for each (var vd:XML in views)
			{
				var canv:Canvas = new Canvas;
				canv.percentHeight = 100;
				canv.percentWidth = 100;
				this._tabStrip.addChild(canv);
				
				canv.addEventListener(ChildExistenceChangedEvent.CHILD_ADD, this.onViewAdded);
								
				Application.getInstance().addView(canv, vd.@name, vd.@source, vd)
			}
		}


		override protected function onViewAdded(ev:ChildExistenceChangedEvent):void
		{
			super.onViewAdded(ev);
			
 			var canv:Canvas = ev.currentTarget as Canvas;
			var view:IMYMView = ev.relatedObject as IMYMView;

			canv.label = view.title;
			canv.invalidateDisplayList();
		}
		
		
		
		override protected function onViewDemandsDisplay(ev:Event):void
		{
			var view:IMYMView = ev.currentTarget as IMYMView;
			if (view.displayed) return;
			
			super.onViewDemandsDisplay(ev);
			
			this._tabStrip.selectedIndex = this._views.indexOf(view);
		}
		
		
		private function onTabStripChange(ev:IndexChangedEvent):void
		{			
			var oldView:IMYMView = this._views[ev.oldIndex] as IMYMView;
			var newView:IMYMView = this._views[ev.newIndex] as IMYMView;
			 
			oldView.doOnLeave();
			newView.handleLocation(_lastHandledLocation);
			newView.doOnEnter();
		}
		
		
		
		override protected function getHandlerFor(location:String):IURLHandler
		{
			var posHandlers:Array = this._lhManager.getAllHandlersForLocation(location);
			if (posHandlers)
			{
				var selChild:Container = this._tabStrip.selectedChild;
				for each (var handler:IURLHandler in posHandlers)
				{
					var dO:DisplayObject = handler as DisplayObject;
					var dOP:DisplayObject = dO.parent;
					try 
					{
						if (selChild.getChildIndex(dOP) != -1) return handler;					
					}
					catch (er:ArgumentError) { /*Ignore */ }
				}
				return super.getHandlerFor(location);
			}
			else return null;
		}		
		
		
		
		override protected function onViewsetupMoveLeft(ev:MouseEvent):void 
		{
			var view:InteractiveObject = ev.relatedObject;
			var canv:Canvas = view.parent as Canvas;
			
			if (canv)
			{
				try {
				var idx:int = this._tabStrip.getChildIndex(canv);
				} catch (err:ArgumentError)
				{ return; }
				
				if (idx > 0)
				{
					this._tabStrip.removeChild(canv);
					this._tabStrip.addChildAt(canv, idx - 1);
					this._tabStrip.selectedChild = canv;
				}
			}
		}
		
		override protected function onViewsetupMoveRight(ev:MouseEvent):void 
		{ 
			var view:InteractiveObject = ev.relatedObject;
			var canv:Canvas = view.parent as Canvas;
			
			if (canv)
			{
				try {
				var idx:int = this._tabStrip.getChildIndex(canv);
				} catch (err:ArgumentError)
				{ return; }
				
				if (idx < (this._tabStrip.numChildren - 1))
				{
					this._tabStrip.removeChild(canv);
					this._tabStrip.addChildAt(canv, idx + 1);
					this._tabStrip.selectedChild = canv;
				}
			}
			ev.preventDefault();
		}

		
	}
}