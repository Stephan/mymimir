package org.mymimir
{
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;

	public class History extends EventDispatcher
	{
		private var myHistory:Array;
		private var myFuture:Array;
		private var myCurrent:String;

		public function History(target:IEventDispatcher=null)
		{
			super(target);
			myHistory = new Array();
			myFuture = new Array();	
		}
		
		
			
		
		public function set current(current:String):void
		{
			if (myCurrent)
				if (myCurrent == current) return;
				else myHistory.push(myCurrent);
			myFuture = new Array();
			myCurrent = current;
		}
		
		public function clear():void
		{
			myCurrent = null;
			myHistory = new Array();
			myFuture = new Array();
		}
		
		public function get current():String
		{
			return myCurrent;
		}
		
		public function goBack():Boolean
		{
			if (myHistory.length) 
			{				
				if (myCurrent) myFuture.push(myCurrent);
				myCurrent = myHistory.pop();
				return true;				
			}
			return false;
		}
		
		public function goForward():Boolean
		{
			if (myFuture.length) 
			{
				if (myCurrent) myHistory.push(myCurrent);			
				myCurrent = myFuture.pop();
				return true;
			}
			return false;
		}


		private function traceMe():void
		{
			trace(myHistory);
			trace("----------------------------------");
			trace(myCurrent);
			trace("----------------------------------");
			trace(myFuture);
			trace("==================================");
		}

		
	}
}