package org.mymimir.Views
{
	import flash.events.DataEvent;
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	import mx.events.ChildExistenceChangedEvent;
	
	import org.mymimir.sdk.Events;
	import org.mymimir.sdk.IURLHandler;
	import org.mymimir.sdk.IWiki;
	import org.mymimir.sdk.Tools;
	import org.mymimir.sdk.URLHandlerManager;
	import org.mymimir.sdk.Views.IMYMView;
	import org.mymimir.sdk.Views.MYMView;
	
	public class CompositeView extends MYMView
	{
		protected var _newProtocols:Boolean;
		protected var _views:Array;
		protected var _lhManager:URLHandlerManager;
		protected var _multiHandling:Boolean;
		
		public function CompositeView(description:XML)
		{
			super(description);
			this._views = new Array();
			this._lhManager = new URLHandlerManager();
			this._protocols = new Array();
			
			this._multiHandling = org.mymimir.sdk.Tools.getBooleanFromXMLAttribute(description, "multiHandling");
		}
		
		override public function set wiki(wiki:IWiki):void
		{
			for each (var view:IMYMView in this._views)
				view.wiki = wiki;
			this._wiki = wiki;
		}
		

		protected function onViewAdded(ev:ChildExistenceChangedEvent):void
		{
			var view:IMYMView = ev.relatedObject as IMYMView; 
			
			this._views.push(view);
						
			view.addEventListener(org.mymimir.sdk.Events.VIEW_LOCATION_CHANGE, onLocationChange);
			view.addEventListener(org.mymimir.sdk.Events.VIEW_DEMAND_DISPLAY, onViewDemandsDisplay);
			view.addEventListener(org.mymimir.sdk.Events.VIEWSETUP_FINISH, onViewsetupFinish);
			view.addEventListener(org.mymimir.sdk.Events.VIEWSETUP_MOVE_DOWN, onViewsetupMoveDown);
			view.addEventListener(org.mymimir.sdk.Events.VIEWSETUP_MOVE_UP, onViewsetupMoveUp);
			view.addEventListener(org.mymimir.sdk.Events.VIEWSETUP_MOVE_LEFT, onViewsetupMoveLeft);
			view.addEventListener(org.mymimir.sdk.Events.VIEWSETUP_MOVE_RIGHT, onViewsetupMoveRight);
			
			view.wiki = this._wiki;
			
			this._newProtocols = true;
			
			this._lhManager.addLocationhandler(view);			
		}
		
		override public function get supportedProtocols():Array
		{
			if (this._newProtocols)
			{
				this._protocols = new Array();
				for each (var lh:IURLHandler in this._views)
				{
					this._protocols = this._protocols.concat(lh.supportedProtocols);
				}
				this._newProtocols = false;
			}
			return super.supportedProtocols;
		}


		override public function get description():XML
		{
			var ret:XML = this._description;
			delete ret.view;

			for each (var view:IMYMView in this._views)
			{
				ret.appendChild(view.description);
			}			
		
			return ret;
		}


		private function onLocationChange(ev:DataEvent):void
		{
			this.dispatchEvent(ev);
		}
		
		
		protected function onViewDemandsDisplay(ev:Event):void
		{
			var view:IMYMView = ev.currentTarget as IMYMView;
			
			if (view.displayed) return;
			
			for each (var v:IMYMView in this._views)
			{
				if (v.displayed) v.doOnLeave();
			}
			
			view.doOnEnter();
			this.dispatchEvent(new Event(org.mymimir.sdk.Events.VIEW_DEMAND_DISPLAY));		
		}
		
		
		
		protected function set multiHandling(value:Boolean):void
		{
			this._multiHandling = value;
		}
		
		public function get multiHandling():Boolean
		{
			return _multiHandling;
		}
		
		
		protected function getDisplayedView():IMYMView
		{
			for each (var view:IMYMView in this._views)
				if (view.displayed) return view;
			return null;
		}
		
		
		protected function getHandlerFor(location:String):IURLHandler
		{
			return this._lhManager.getHandlerFor(location); 
		}
		
		override public function handleLocation(location:String):Boolean
		{
			var handler:IURLHandler;
			var handled:Boolean;
			
			var displayed:IURLHandler = getDisplayedView() as IURLHandler;
			if ((displayed) && (displayed.canHandleLocation(location))) handler = displayed;
			else
				handler = getHandlerFor(location);
			
			if (handler) 
			{
				handled = handler.handleLocation(location);
				if (!this._multiHandling) 
				{
					this._lastHandledLocation = location;
					if (!this._multiHandling) return handled;
				}
			}
			
			if (this._multiHandling)
			{
				for each (var view:IMYMView in this._views)
					if ((view != handler) && (view.canHandleLocation(location)))
						handled = view.handleLocation(location) || handled;
			}
			
			
			if (handled) this._lastHandledLocation = location;
			return handled;
		}
		
		
		override public function enableViewSetupMode():void
		{
			for each (var view:IMYMView in this._views)
			{
				view.enableViewSetupMode();
			}
		}
		
		
		protected function onViewsetupMoveDown(ev:MouseEvent):void { }
		protected function onViewsetupMoveUp(ev:MouseEvent):void { }
		protected function onViewsetupMoveLeft(ev:MouseEvent):void { }
		protected function onViewsetupMoveRight(ev:MouseEvent):void { }
		
	}
}