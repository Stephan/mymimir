package org.mymimir.Views
{
	import mx.controls.DataGrid;
	import mx.controls.dataGridClasses.DataGridColumn;
	import mx.core.UIComponent;
	
	import org.mymimir.Application;
	import org.mymimir.sdk.Views.MYMView;
	
	public class DebugView extends org.mymimir.sdk.Views.MYMView
	{
		private var _grid:DataGrid
		
		public function DebugView(description:XML)
		{
			super(description);
			
			this._grid = new DataGrid();
			this.setWidthHeight(_grid);
			this.addChild(this._grid);
			
			var cols:Array = new Array();
			var c:DataGridColumn = new DataGridColumn("text");
			cols.push(c);
			
			this._grid.columns = cols;
			
			Application.debug(arguments.callee, "Debugview started");
		}
		
		
		override public function get title():String
		{
			return "Debug";
		}

	}
}