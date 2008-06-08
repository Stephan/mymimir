// ActionScript file
// ActionScript file

package org.mymimir.Components
{
	import flash.desktop.Clipboard;
	import flash.desktop.ClipboardFormats;
	import flash.desktop.NativeDragActions;
	import flash.desktop.NativeDragManager;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.NativeDragEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.text.TextLineMetrics;
	import flash.ui.Keyboard;
	import flash.utils.Timer;
	
	import mx.controls.TextArea;
	import mx.graphics.codec.PNGEncoder;
	
	import org.mymimir.Application;
	import org.mymimir.Engine.Syntax;
	import org.mymimir.sdk.IWiki;
	
	
	public class WikiEditor extends TextArea
	{
		public static const eventTextChanged:String = "WikiEditor.TextChanged";
		public static const eventTextChangedLive:String = "WikiEditor.TextChangedLive";
		public static const eventWikiLinkClicked:String = "WikiEditor.WikiLinkClicked";
		public static const eventWikiLinksChanged:String = "WikiEditor.WikiLinksChanged";
		public static const eventTodosChanged:String = "WikiEditor.TodosChanged";
		protected static const _IMGExtensions:Array = new Array("gif", "png", "jpg");

		private var _syntax:Syntax;
		private var _undoTimer:Timer = new Timer(1000, 0);
		private var _saveTimer:Timer = new Timer(3000, 0);
		[Bindable] private var _undoHistory:Array = new Array();
		private var _undoFuture:Array = new Array();
		private var _undoCurrent:Object;
		private var _maxUndoLevels:int = 50;
		
		private var _completionSelector:CompletionPopUp;
		private var _completionStartedAt:int;
		private var _completionAborted:Boolean;
		private var _completionPrefix:String;
		private var _completionWikiLinkPrefix:String;
		private var _completionWikiLinkSuffix:String;
		
		private var _wiki:IWiki;
		private var _dragPos:Point = new Point();
		private var _bulletMode:Boolean = false;
		private var _bulletIdent:String = "";
		private var _liveUpdate:Boolean = false;
	
	

		
		public function WikiEditor(saveInterval:int)
		{
		 	super();
		 	
			this._syntax = new Syntax(org.mymimir.Application.getInstance().getSyntaxDefinition());
			this._syntax.addRules(Application.getInstance().getWikiSyntaxDefinition());
			
			// Get prefix/suffix of the WikiLink creation string to know when to popup/close the selector
			var crea:String = this._syntax.getCreationString(Syntax.RWikiLink, Syntax.FilterPageBlock);
			var p:int = crea.indexOf(Syntax.FieldPageName);
			if (p != -1)
			{
				this._completionWikiLinkPrefix = crea.substring(0, p);
				p = p + Syntax.FieldPageName.length;
				this._completionWikiLinkSuffix = crea.substring(p, crea.length);
			}
						 	
 		 	this.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		 	this.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		 	
		 	this.addEventListener(flash.events.NativeDragEvent.NATIVE_DRAG_OVER, this.onNativeDragIn);
		 	this.addEventListener(flash.events.NativeDragEvent.NATIVE_DRAG_DROP, this.onNativeDrop);
		 	this.addEventListener(flash.events.NativeDragEvent.NATIVE_DRAG_OVER, this.onNativeDragOver);
		 	
		 	
 			_undoTimer = new Timer(1000, 0);
			_saveTimer = new Timer(saveInterval, 0);
			
		 	this._undoTimer.addEventListener(flash.events.TimerEvent.TIMER, this.onUndoTimer);
		 	this._saveTimer.addEventListener(TimerEvent.TIMER, this.onSaveTimer);
		}
		
		public function set liveUpdate(value:Boolean):void
		{
			this._liveUpdate = value;
		}
		
		public function set wiki(wiki:IWiki):void
		{
			this._wiki = wiki;
		}
		
		override public function set text(value:String):void
		{
			super.text = value;
			this._undoHistory = new Array();
			this._undoFuture = new Array();
			this._undoCurrent = null;
		} 
		
		override protected function createChildren():void
		{
			super.createChildren();
		}
		
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth, unscaledHeight)
		}
		
		
		private function onKeyDown(e:flash.events.KeyboardEvent):void
		{
			this._undoTimer.reset();
			this._undoTimer.start();
			this._saveTimer.reset();
			this._saveTimer.start();
			
			if (!this._undoCurrent)
			{
				switch (e.keyCode)
				{
					case Keyboard.UP:
					case Keyboard.DOWN:
					case Keyboard.LEFT:
					case Keyboard.RIGHT:
					case Keyboard.PAGE_UP:
					case Keyboard.PAGE_DOWN:
					case Keyboard.END:
					case Keyboard.HOME:
									break;
					default: this._undoCurrent = this.makeUndoObject();
				}	
			}
			
			
			if (this._liveUpdate) this.dispatchEvent(new Event(WikiEditor.eventTextChangedLive));
				
			switch (e.keyCode)
			{
				
				case Keyboard.BACKSPACE:
					if (this.checkForBulletIdentPos())
					{
						this.unBullet();
						e.preventDefault();
					}
					break;
				
				
				case Keyboard.UP:
					if (this._completionSelector)
					{
						this.completionSelUp();
						e.preventDefault();
					}		
					break;				

				case Keyboard.DOWN:
					if (this._completionSelector)
					{
						this.completionSelDown();
						e.preventDefault();
					}						
					break;
				
				case Keyboard.TAB:
					if (this._completionSelector)
						this.finishCompletion();
					else	
					if (this.checkForBulletIdentPos())
						if (e.shiftKey) this.bulletIdentLess()
						else this.bulletIdentMore();
					else
						this.insertTextAtSel("\t");
						
					e.preventDefault();
					break;	

				case Keyboard.Z:
					if ((e.controlKey) || (e.commandKey))
						this.undo();
					break;
						
					
				case Keyboard.SPACE:
					if ((e.controlKey) || (e.commandKey))
					{
						this.popupCompletionSelector();
						e.preventDefault();
					}
					break;
					
				case Keyboard.ESCAPE:
					if (this._completionSelector)
					{
						this.closeCompletionSelector();
						this._completionAborted = true;
					}
					break;			

				case Keyboard.ENTER:
					if (this._completionSelector)
					{
						this.finishCompletion();
						e.preventDefault();
					}
					this.addUndoLevel();
					break;
					
				default: 
					this._completionAborted = false;
					break; 
												
			}
		}

		private function onKeyUp(e:flash.events.KeyboardEvent):void
		{
			if (this._liveUpdate) this.dispatchEvent(new Event(WikiEditor.eventTextChangedLive));
			
			switch (e.keyCode)
			{
				case Keyboard.TAB:
					e.preventDefault();
					break;		

				case Keyboard.UP:
					if (this._completionSelector)
						e.preventDefault();
					break;
				case Keyboard.DOWN:
					if (this._completionSelector)
						e.preventDefault();
					break;

				case Keyboard.ENTER:
					if (this._completionSelector) e.preventDefault();
					if (this.processBulletMode()) e.preventDefault();	
					break;
					
					
				case Keyboard.LEFT:			//Avoid completion selector
				case Keyboard.RIGHT:		//weh just moving the cursor
				case Keyboard.PAGE_UP:
				case Keyboard.PAGE_DOWN:
					break;
					
				default: 
					if ((!this._completionSelector) && (!this._completionAborted))
					{
						if (this._completionWikiLinkPrefix)
						if (this.getCharactersBeforeCursor(this._completionWikiLinkPrefix.length) == this._completionWikiLinkPrefix)
						{
							this._completionPrefix = this._completionWikiLinkPrefix;
							this.popupCompletionSelector();
						}
					}
					else if (this._completionSelector)
					{
						if ((this._completionWikiLinkSuffix) && 
						    (this.getCharactersBeforeCursor(this._completionWikiLinkSuffix.length) == this._completionWikiLinkSuffix))
							this.closeCompletionSelector();
						else this.updateCompletionSelector();
					}
			}
		}
		
		
		private function onUndoTimer(ev:Event):void
		{
			this.addUndoLevel();
			this._undoTimer.reset();			
		}
		
		private function onSaveTimer(ev:Event):void
		{
			this.dispatchEvent(new Event(WikiEditor.eventTextChanged));
		}
		
		private function insertTextAtSel(inText:String):void
		{
			this.addUndoLevel();

			var intCursorLocation : int = this.selectionBeginIndex;

			var strFirstHalf : String = this.text.substr(0, intCursorLocation);
			var strSecondHalf : String = this.text.substr(intCursorLocation, this.text.length);

			super.text = strFirstHalf + inText + strSecondHalf;
			this.setSelection((intCursorLocation + inText.length), (intCursorLocation + inText.length));		
//			this.dispatchEvent(new Event(WikiEditor.eventTextChanged));
		}

		public function replaceTextAt(str:String, pos1:int, pos2:int):void
		{
			this.addUndoLevel();

			var strBegin:String = this.text.substr(0, pos1);
			var strEnd:String = this.text.substr(pos2, this.text.length - pos2);
			this.text = strBegin + str + strEnd;
//			this.dispatchEvent(new Event(WikiEditor.eventTextChanged));
		}

		
		public function getCharIndexAt(x:int, y:int):int
		{
    		var idx:int = this.textField.getCharIndexAtPoint(x, y);
    		
    		if (idx == -1)
    		{
    			idx = this.textField.getLineIndexAtPoint(x, y);
    			idx = this.textField.getLineOffset(idx) + this.textField.getLineText(idx).length - 1;
    		}
			if (idx == -1) 
				idx = this.text.length;

			return idx;
		}


		public function getSelectedText():String
		{
			var ret:String = this.text.substr(this.selectionBeginIndex, this.selectionEndIndex - this.selectionBeginIndex);
			return ret;
		}
		
		public function getLineAtPos(pos:int):String
		{
			var text:String = this.text;
			var pos1:int = this.text.lastIndexOf("\r", pos) + 1;
			if (pos1 == -1) pos1 = 0;
			var pos2:int = this.text.indexOf("\r", pos1);
			if (pos2 == -1) pos2 = this.text.length;
			
			return this.text.substr(pos1, pos2 - pos1);				
		}

		
		public function getCurrentLine():String
		{
			return this.getLineAtPos(this.selectionBeginIndex - 1);
		}

		public function getPreviousLine():String
		{
			var pos:int = this.text.lastIndexOf("\r", this.selectionBeginIndex) - 2;
			if (pos < 0) return null;
			
			return this.getLineAtPos(pos);
		}
		
		public function getCurrentLinePos():int
		{
			var pos1:int = this.text.lastIndexOf("\r", this.selectionBeginIndex - 1);
			if (pos1 == -1) pos1 = 0;
			return this.selectionBeginIndex - pos1 - 1;
		}
		
		
		public function getCharactersBeforeCursor(count:int):String
		{
			var cl:String = this.getCurrentLine();
			var p:int = this.getCurrentLinePos();
			var p2:int = p - count;
			if (p2 < 0) p2 = 0;
			return cl.substring(p2, p);
		}
		
		public function getCurrentEnteredWord():String
		{
			var cl:String = this.getCurrentLine();
			var p:int = this.getCurrentLinePos();
			if (!p) return null;
			
			var p2:int = cl.lastIndexOf(" ", p);
			if (p2 == -1)
				p2 = cl.lastIndexOf("\t", p);
				
			if (p2 == -1) return cl.substr(0, p);
			return cl.substr(p2, p);	
		}
		
		
		private function makeUndoObject():Object
		{
			var uO:Object = new Object;
			
 			uO.text = this.text;
 			uO.selBegin = this.selectionBeginIndex;
 			uO.selEnd = this.selectionEndIndex;
 			
 			return uO;			
		}
		
		private function processUndoObject(uO:Object):void
		{
			super.text = uO.text;
			this.selectionBeginIndex = uO.selBegin;
			this.selectionEndIndex = uO.selEnd;
		}
		
		
 		private function addUndoLevel():void
 		{
 			trace("UndoLevel");
 			if (_undoHistory.length)
 			{
 				var uO:Object = this._undoHistory.pop();
 				if (uO)
 				if (uO.text != this._undoCurrent.text)
 				{
 					this._undoHistory.push(uO);
 					trace("\tKeep last");	
 				}
 			}
 			this._undoHistory.push(this._undoCurrent);
 			this._undoCurrent = this.makeUndoObject();			
 			_undoFuture = new Array();
 		}	
 		
 		private function undo():void
 		{
			if (!this._undoHistory.length) return;
			this._undoFuture.push(this._undoCurrent);
			this._undoCurrent = this._undoHistory.pop();
			this.processUndoObject(this._undoCurrent);	
			this._undoTimer.reset();
 		}
 		
 		private function redo():void
		{
			if (!_undoFuture.length) return;
			this._undoHistory.push(this._undoCurrent);
			this._undoCurrent = this._undoFuture.pop();
			this.processUndoObject(this._undoCurrent);
		}		
		
		
		
		private function unBullet():void
		{
			var cL:String = this.getCurrentLine();
			var p:int = this.getCurrentLinePos();
			
			this.replaceTextAt(cL.substring(p, cL.length), this.selectionBeginIndex - p, this.selectionBeginIndex - p + cL.length);
			this.setSelection(this.selectionBeginIndex - p, this.selectionBeginIndex - p);
		}
		
		
		private function bulletIdentLess():void
		{
			var reg:RegExp = /^(\t\t+(\*|\#) )/;
			var cL:String = this.getCurrentLine();
			var cP:int = this.getCurrentLinePos();
			var cS:String = cL.substr(0, cP);
						
			if (cS.match(reg))
			{
				var bs:String = cS.replace(reg, "$2");
				this.replaceTextAt(bs + " ", this.selectionBeginIndex - 3, this.selectionBeginIndex);
				this.setSelection(this.selectionBeginIndex - 1, this.selectionBeginIndex - 1);
			}
			
		}
		
		private function bulletIdentMore():void
		{
			var reg:RegExp = /^(\t+(\*|\#) )/;
			var cL:String = this.getCurrentLine();
			var cP:int = this.getCurrentLinePos();
			var cS:String = cL.substr(0, cP);
			
			if (cS.match(reg))
			{
				var bs:String = cS.replace(reg, "$2");
				this.replaceTextAt("\t" + bs + " ", this.selectionBeginIndex - 2, this.selectionBeginIndex);
				this.setSelection(this.selectionBeginIndex + 1, this.selectionBeginIndex + 1);
			}
		}

		
		private function checkForBulletIdentPos():Boolean
		{
			var reg:RegExp = /^(\t+(\*|\#) ).*/;
			var cL:String = this.getCurrentLine();
			
			if (!cL)
				return false;
			if (cL.match(reg))
			{
				var p:int = this.getCurrentLinePos();
				this._bulletIdent = cL.replace(reg, "$1");
				if (p == this._bulletIdent.length) 
					return true
			}			
			return false;
		}
		
		private function checkForBulletMode():void
		{
			var reg:RegExp = /^(\t+(\*|\#) ).*/;
			var cL:String = this.getPreviousLine();
			
			if (!cL)
			{
				this._bulletMode = false;
				return;
			}
			if (cL.match(reg))
			{ 
				this._bulletMode = true;
				this._bulletIdent = cL.replace(reg, "$1");
			}
			else this._bulletMode = false;
		}		
		
		private function processBulletMode():Boolean
		{
			this.checkForBulletMode();
			if (!this._bulletMode) return false;
			this.insertTextAtSel(this._bulletIdent);
			return true;			
		}
		
		
		/**
		 * Event handler. Handles native drag in events. Accepts URL_FORMAT and FILE_LIST_FORMAT. 
		 * @param event
		 * 
		 */		
		public function onNativeDragIn(event:NativeDragEvent):void
		{
	   		NativeDragManager.dropAction = NativeDragActions.MOVE;
	    	if ((event.clipboard.hasFormat(ClipboardFormats.URL_FORMAT)) ||
	      	    (event.clipboard.hasFormat(ClipboardFormats.FILE_LIST_FORMAT)))
	      	{
	    		this.setFocus();
	        	NativeDragManager.acceptDragDrop(this); //'this' is the receiving component
	    	}
	 	}		
	 	 	

	 	/**
	 	 * 
	 	 * @param file
	 	 * @return 
	 	 * 
	 	 */			 	 	
	 	private function getFileName(file:File):String
	 	{
	 		if (!file) return null;
	 		if (file.isDirectory) return null;
	 		
	 		var p:int;
	 		var e:String;
	
	 		e = file.url;
	 		p = e.lastIndexOf("/", e.length - 1);
	 		e = e.substr(p + 1, e.length - p -1);
	 		
	 		return e;
	 	}


	 	/**
	 	 * Event handler. Handles native Drop event. If it is a file, this puts a file-link into the text. 
	 	 * @param event
	 	 * 
	 	 */	 	
	 	public function onNativeDrop(event:NativeDragEvent):void
	 	{
	 		var text:String;
	 		var fileTo:File;
	 		var fn:String;
	 		
	 		if (event.clipboard.hasFormat(ClipboardFormats.FILE_LIST_FORMAT))
	 		{ 		
	 			text = "";
	 			var fl:Array = event.clipboard.getData(ClipboardFormats.FILE_LIST_FORMAT) as Array;
	 			for each (var item:File in fl) 
	 			{
	 				if (event.shiftKey)
	 				{
	 					var e:String = item.extension;
	 					if (WikiEditor._IMGExtensions.indexOf(e) != -1)
	 					{
	 						if (item.isDirectory) continue;
/* 	 						e = getFileName(item);
	 						if (!e) continue;
	 						fileTo = new File(Application.getInstance().getDataPath()).resolvePath(e);
	 						
	 						if (fileTo.exists)
	 						{
 								e = org.mymimir.sdk.Tools.getUniqueFileName(fileTo.extension);
	 							fileTo = new File(Application.getInstance().getDataPath()).resolvePath(e);
	 						}
 */	 						
 							if (text != "") text = text + " ";
	 						fn = Application.getInstance().backend.storeFileInData(item);
	 						text += this._syntax.createFromArgs(Syntax.RRelIMG, "$file", 
	 															Application.getInstance().backend.getFilenameFromDataURL(fn));
	 						
/* 	 						item.copyTo(fileTo, true);
	 						
	 						if (text != "") text = text + " ";
	 						text += this._syntax.createFromArgs(Syntax.RRelIMG, "$file", e);	 					
 */	 					}
	 				}
	 				else if ((event.ctrlKey) || (event.commandKey))
	 				{
 	 					if (item.isDirectory) continue;
	 					if (text != "") text = text + " ";
						fn = Application.getInstance().backend.storeFileInData(item);
	 					text += this._syntax.createFromArgs(Syntax.RRelFileLink, "$file", 
	 														Application.getInstance().backend.getFilenameFromDataURL(fn));

/*	 					var fn:String = Tools.getUniqueFileName(item.extension);
	 					fileTo = new File(Application.getInstance().getDataPath()).resolvePath(fn)
	 					item.copyTo(fileTo, true);
	 					
	 					if (text != "") text = text + " ";
	 					text += this._syntax.createFromArgs(Syntax.RRelFileLink, "$file", getFileName(fileTo));	 					
 */	 				}
	 				else
	 				{
	 					var url:String = item.url;
	 					if (item.isDirectory)
							if (url.charAt(url.length - 1) != "/")
								url = url + "/";
						if (text != "") text = text + " ";
	 					text += this._syntax.createFromArgs(Syntax.RFileLink, "$url", url);
	 				}
	 			}
	 		}
	    	
			if (text)
			{
				var idx:int = this.getCharIndexAt(this._dragPos.x, this._dragPos.y);
				this.replaceTextAt(text, idx, idx);
	   			this.setSelection(idx + text.length, idx + text.length);
	  		}
	 	}	
	 	
	 	/**
	 	 * Event handler. Handles Native Drag-Over Events
	 	 * @param event
	 	 * 
	 	 */	 	
	 	public function onNativeDragOver(event:NativeDragEvent):void
	 	{
	 		this._dragPos.x = event.localX
	 		this._dragPos.y = event.localY;
	 	}
	 			
		
		public function processSpecialPaste():Boolean
		{
			var clip:Clipboard = flash.desktop.Clipboard.generalClipboard;
			
			if (clip.hasFormat(ClipboardFormats.BITMAP_FORMAT))
			{
				var bmpData:BitmapData = clip.getData(ClipboardFormats.BITMAP_FORMAT) as BitmapData;
				var bmp:Bitmap = new Bitmap(bmpData);

				var matrix:Matrix = new Matrix();
				matrix.translate(0 - (bmpData.rect.x + 1), 0 - (bmpData.rect.y + 1));
				bmpData.draw(bmpData, matrix );				
				
				var png:* = null;
				var pngEnc:PNGEncoder = new PNGEncoder();
				png = pngEnc.encode(bmpData);
				bmpData.dispose();
							
				var fn:String;
				fn = Application.getInstance().backend.storeBytesAsFileInData(png, "png");
				/* 
				var file:File = new File(Application.getInstance().getDataPath()).resolvePath(fn);
				var fs:FileStream = new FileStream;
				fs.open( file, flash.filesystem.FileMode.WRITE );
				fs.writeBytes(png, 0, 0);
				fs.close();
 */			
				this.insertTextAtSel(this._syntax.createFromArgs(Syntax.RRelIMG, "$file", 
									 Application.getInstance().backend.getFilenameFromDataURL(fn)));
				
				return true;
			}
			
			return false;
			
		}		
		
		
		
		private function popupCompletionSelector():void
		{
			if (!this._completionSelector)
			{
				this._completionSelector = new CompletionPopUp();
				this._completionSelector.popup(this);
				var tM:TextLineMetrics = this.measureText("Q");
				this._completionSelector.lineHeight = tM.height;
				this._completionStartedAt = this.getCurrentLinePos();
			}
			this.updateCompletionSelector();
		}
		
		private function getCurrentCharPos():Point
		{
			var ret:Point = new Point;
			var tM:TextLineMetrics = this.measureText("Q");			
			var charRect:Rectangle = this.textField.getCharBoundaries(this.selectionBeginIndex - 1);
			
			if (charRect)			
			{
				ret.y = charRect.y;
				ret.x = charRect.right + 10;
			}
			else
			{
				ret.x = tM.width;
				var ar:Array = this.text.substr(0, this.selectionBeginIndex).match(new RegExp("\\r", "g"));
				ret.y = (tM.height + 2) * ar.length;
			}
			
			return ret;
		}
		
		
		
		private function cbUpdateComSelPagesGot(success:Boolean, pages:Array, ... args):void
		{
			var list:XMLList = new XMLList;
			for each (var page:String in pages)
			{
				var ch:XML = <name />;
				ch.@label = page;
				ch.@value = page;
				list[list.length()] = ch;			
			}
			
			this._completionSelector.listData = list;
			this._completionSelector.labelFied = "@label";
			
			var chPos:Point = this.getCurrentCharPos();
			this._completionSelector.move(chPos.x, chPos.y);			
		}
		
		private function updateCompletionSelector():void
		{
			if (!this._wiki) return;
			if (!this._completionSelector) return;
			
			if (this.getCurrentLinePos() < this._completionStartedAt)
			{
				this.closeCompletionSelector();
				return;
			}
			
			var filter:String = this.getCurrentLine().substring(this._completionStartedAt, this.getCurrentLinePos()) + "%";

			//var pages:Array = this._wiki.getPagesFiltered(filter);
			this._wiki.backend.getPagesByFilter(filter, this.cbUpdateComSelPagesGot);

		}


		private function completionSelDown():void
		{
			if (!this._completionSelector) return;
			this._completionSelector.selectDown();
		}
		
		private function completionSelUp():void
		{
			if (!this._completionSelector) return;
			this._completionSelector.selectUp();
		}
		
		private function finishCompletion():void
		{
			var sel:XML = this._completionSelector.selectItem as XML;
			if (sel)
			{
				var selStr:String = sel.@value;
				var p2:int = this.getCurrentLinePos() - this._completionStartedAt;
				this.replaceTextAt(selStr, this.selectionBeginIndex - p2, this.selectionBeginIndex);
				this.selectionBeginIndex = this.selectionEndIndex = this.selectionBeginIndex + selStr.length - p2;
			}
			
			this.closeCompletionSelector();
		}
		
		private function getStringToComplete():String
		{
			var gl:String = this.getCurrentLine();
			var bPos:int = gl.lastIndexOf(this._completionPrefix, this.getCurrentLinePos());

			if (bPos == -1) return null;
			return gl.substr(bPos + 1, this.selectionBeginIndex - bPos - 1);			
		}

			
		private function closeCompletionSelector():void
		{
			if (this._completionSelector) this._completionSelector.close();
			this._completionSelector = null;
		}
	}
}