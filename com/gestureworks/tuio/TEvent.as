package com.gestureworks.tuio
{
	import flash.events.Event;

	public class TEvent extends Event
	{		
		public static var COMPLETE:String = "complete";
		public static var CHANGE:String = "change";
		
		public var object:Object = new Object();
		
		public function TEvent(type:String, _object:Object, bubbles:Boolean = false, cancelable:Boolean = false)
		{
			super(type, bubbles, cancelable);
			
			object = _object;
		}

		override public function clone():Event
		{
			return new TEvent(type, object, bubbles, cancelable);
		}
	}
}