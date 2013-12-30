package org.tuio.connectors.tcp
{
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import org.tuio.osc.OSCBundle;
	import org.tuio.osc.OSCEvent;
	import org.tuio.osc.OSCMessage;
	
	/**
	 * A class for receiving OSCBundles from a TCP socket stream.
	 */
	public class OSCSocket extends Socket
	{
		private var Debug:Boolean = true;
		private var Buffer:ByteArray = new ByteArray();
		private var PartialRecord:Boolean = false;
		private var isBundle:Boolean = false;
		private var flosc:Boolean = false;
    	
		public function OSCSocket(flosc:Boolean = false) {
			this.flosc = flosc;
			configureListeners();
		}

		private function configureListeners():void {
	        addEventListener(Event.CLOSE, closeHandler);
	        addEventListener(Event.CONNECT, connectHandler);
	        addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
	        addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			if (flosc)
			   addEventListener(ProgressEvent.SOCKET_DATA, floscDataHandler);
			else
				addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);
	    }
		
		private function floscDataHandler(event:ProgressEvent):void {
    		var data:ByteArray = new ByteArray();
        	super.readBytes(data, data.length, super.bytesAvailable);
			var msg:Array = processMessage(XML(data.readUTFBytes(data.bytesAvailable)));
			for each(var m:Array in msg)
				this.dispatchEvent(new OSCEvent(null,m));			
	    }		
	    
	    private function socketDataHandler(event:ProgressEvent):void {
    		var data:ByteArray = new ByteArray();
    		if(PartialRecord){
    			Buffer.readBytes(data,0,Buffer.length);
    			PartialRecord = false;
    		}

        	super.readBytes(data,data.length,super.bytesAvailable);
   			
			var Length:int;			
			
    		// While we have data to read
			while(data.position < data.length){								
				isBundle = OSCBundle.isBundle(data);
				
				if (isBundle) { //check if the bytes are already a OSCBundle
					if (data.bytesAvailable > 20) { //there should be size information
						data.position += 16;
						if (data.readUTFBytes(1) != "#") {
							data.position -= 1;
							Length = data.readInt() + 20;
							data.position -= 20;
						} else {
							data.position -= 17;
							Length = 16;
						}
					} else { 
						Length = data.length+1;
					}
				} else {
					Length = data.readInt() + 4;
					data.position -= 4;
				}
					
				// If we have enough data to form a full packet.
				if (Length <= (data.length - data.position)) {
					var packet:ByteArray = new ByteArray();
					if (isBundle) packet.writeInt(Length);
		    		data.readBytes(packet,packet.position,Length);
		    		packet.position = 0;
					this.dispatchEvent(new OSCEvent(packet));
		   		} else {
					// Read the partial packet
					Buffer = new ByteArray();
					data.readBytes(Buffer,0,data.length - data.position);
					PartialRecord = true;
		   		}
	    		
			}

	    }
	    
	    private function closeHandler(event:Event):void {
	        if(Debug)trace("Connection Closed");
	    }
	
	    private function connectHandler(event:Event):void {
	        if(Debug)trace("Connected");
	    }
	
	    private function ioErrorHandler(event:IOErrorEvent):void {
	        if(Debug)trace("ioErrorHandler: " + event);
	    }
	
	    private function securityErrorHandler(event:SecurityErrorEvent):void {
	        if(Debug)trace("securityErrorHandler: " + event);
	    }		

	private static function processMessage(msg:XML):Array {
			var fseq:String;
			var node:XML;
			var Message:Array = [];
			var data:Array = [];
			var i:int;
			//XML.prettyPrinting = true;			
			//trace(msg);
			
			for each(node in msg.MESSAGE) {
				if(node.ARGUMENT[0]) {
					var type:String;	
					if(node.@NAME == "/tuio/2Dcur") {
						type = node.ARGUMENT[0].@VALUE;				
						if (type == "set") {
							data = [];

							try {
								data.push( { type:String(node.ARGUMENT[0].@TYPE), value:String(node.ARGUMENT[0].@VALUE)} );								
								data.push( { type:"i", value:int(node.ARGUMENT[1].@VALUE)} );								
								for (i=2; i < 9; i++)	{
									if (node.ARGUMENT[i])
										data.push( {type:String(node.ARGUMENT[i].@TYPE), value: isNaN(Number(node.ARGUMENT[i].@VALUE)) ? String(node.ARGUMENT[i].@VALUE) : Number(node.ARGUMENT[i].@VALUE)} );
								}
								
								while (data[0].value != "set")
									data.shift();
									
								Message.push(data);
							
							} catch (e:Error) {
								trace("Error Parsing TUIO XML");
							}
						}
						else if (type == "alive") {
							data.push( { type:String(node.ARGUMENT[0].@TYPE), value:String(node.ARGUMENT[i].@VALUE) } );
							for (i = 1; i < node.*.length(); i++)
								data.push( { type:String(node.ARGUMENT[i].@TYPE), value:int(node.ARGUMENT[i].@VALUE) } );
							Message.push(data);
						}
						else if (type == "fseq") {							
							//Message.push( {type:String(node.ARGUMENT[0].@TYPE), value:String(node.ARGUMENT[0].@VALUE) } );
							//Message.push( {type:String(node.ARGUMENT[1].@TYPE), value:int(node.ARGUMENT[1].@VALUE) } );
						}						
					}
				}
			}
			return Message;
		}		
	}
}