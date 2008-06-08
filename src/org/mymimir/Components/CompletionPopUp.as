package org.mymimir.Components
{
	import flash.display.DisplayObject;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import mx.containers.VBox;
	import mx.controls.List;
	import mx.managers.PopUpManager;

	public class CompletionPopUp extends VBox
	{
		private var _list:List;
		private var _domain:Rectangle;
		private var _lineHeight:int;
		private var _parent:DisplayObject;
		
		public function CompletionPopUp()
		{
			super();
			this.visible = true;
			
			this.createChildren();
		}
		
		override protected function createChildren():void
		{
			if (!_list)
			{
				_list = new List();
				_list.visible = true;
				_list.tabEnabled = false;
				_list.focusEnabled = false;
				_list.rowCount = 5;
				this.addChild(_list);
				this.focusEnabled = false;
			}
		}	
		
		
		public function set listData(data:XMLList):void
		{
			_list.dataProvider = data;
			_list.selectedIndex = 0;
			_list.invalidateSize();
		}
		
		public function set labelFied(field:String):void
		{
			_list.labelField = field;
		}
		
		public function set selectedIndex(idx:int):void
		{
			_list.selectedIndex = idx;
			_list.scrollToIndex(idx);
		}
		
		public function selectDown():void
		{
			var idx:int = _list.selectedIndex + 1;
			_list.selectedIndex = idx;
			_list.scrollToIndex(idx);
		}

		public function selectUp():void
		{
			if (_list.selectedIndex == 0) return;
			var idx:int = _list.selectedIndex - 1;
			_list.selectedIndex = idx;
			_list.scrollToIndex(idx);
		}

		public function get selectItem():Object
		{
			return _list.selectedItem;
		}
		
		public function set domain(value:Rectangle):void
		{
			this._domain = value;
		}
		
		public function set lineHeight(value:int):void
		{
			this._lineHeight = value;
		}
		
		
		override public function move(x:Number, y:Number):void
		{
			var myBounds:Rectangle = this.getBounds(this._parent);
			
			var myRight:int = x + myBounds.width;
			var myBottom:int = y + myBounds.height;
			
			if (myRight > _domain.width)
			{
				x = _domain.width - myBounds.width;
				y += _lineHeight + 2;
				myBottom += _lineHeight + 2;
			}
			
			if (myBottom > _domain.height)
			{
				y = y - 2 * (_lineHeight + 2) - myBounds.height;
				if (myRight > _domain.width)
					y -= 2 * (_lineHeight + 2);
			}
			
			var pos:Point = this._parent.localToGlobal(new Point(x, y));
			super.move(pos.x, pos.y);				
		}
		
		
		
		public function popup(parent:DisplayObject, pos:Point = null):void
		{
			this._parent = parent;
			this._domain = parent.getBounds(parent);
			
			PopUpManager.addPopUp(this, parent, false);	
			PopUpManager.centerPopUp(this);
			
			if (pos)
				this.move(pos.x, pos.y);
		}
		
		public function close():void
		{
			PopUpManager.removePopUp(this);			
		}

	}
}

/*

{



	public class CompletionPopUp extends VBox
	{
		

	
		public function CompletionPopUp()
		{

		}

	}
}

*/