package org.mymimir.Converter
{
	import flash.utils.escapeMultiByte;
	
	import org.mymimir.Engine.Syntax;
	import org.mymimir.sdk.IConverter;

	public class HTMLConverter extends ConverterGeneral
	{
		private static var _name:String = "HTML";
		
		private var _inPre:Boolean = false;
		private var _inTable:Boolean = false;
		private var _tableSectionClass:String = "";
		private var _tableNewSection:Boolean = false;
		private var _tableFirstSection:Boolean = false;
		private var _inBulletList:Boolean = false;
		private var _paragraphStarted:Boolean = false;
		private var _ignoreParagraphs:Boolean = false;
		private var _bulletDepth:int = 0;
		private var _bulletMode: Array = new Array();
		private var _currentBulletMode:String;
		private var _currentBlock: String;
		private var _blockCode:String;
		
		private var _lastConverted:String;
		private var _lastConversion:String;
		
		
		
		public function HTMLConverter()
		{
			super(HTMLConverter._name);
		}
		
		
		public static function getInstance():IConverter
		{
			/*if (!_instance) _instance = new HTMLConverter();
			return _instance;
			*/
			return new HTMLConverter();
		}
		
				
		override public function convertText(text:String):String
		{
			var html:String = "";
			
			if (text != this._lastConverted) 
			{
				text = super.convertText(text);
					
				this._lastConverted = text;
				if (text == null) return "";
				text = text.replace(/\n/g, "\r");
								
				this.initConverter();
				this._syntax.initBlockFilterStack();

				html = this.doConvertText(text, true);
				
				html = this.cleanUp(html);
				this._lastConversion = html;
			}
			
			this._syntax.initBlockFilterStack();
			
			html = this.processFunctions(this._prefix + this._lastConversion + this._suffix);
			
			
			// Escape URL for Wiki-Pages to allow utf-8 chars like Umlaute in page names
			var r:RegExp = new RegExp("((src|href)=\")(wiki:\/\/)([^\"]+)(\")", "g");
			var matches:Array = html.match(r);
			
			for each (var m:String in matches)
			{
				var pre:String = m.replace(r, "$1");
				var proto:String = m.replace(r, "$3");
				var url:String = flash.utils.escapeMultiByte(m.replace(r, "$4"));
				var suf:String = m.replace(r, "$5");
				html = html.replace(m, pre + proto + url + suf);
			}
			
			return 	html;
		}
		
		override protected function doConvertText(text:String, lineBreak:Boolean = false):String
		{
			var lineCount:int = 0;
			var add:String = "";
			if (lineBreak) add = "\r";
			if (!text) return text;
			var html:String = "";
			text = this.replaceSpecialsInText(text);
			var lines:Array = text.split("\r");				
			for each (var line:String in lines)
			{
				this._syntax.setGlobalField(Syntax.FieldSourceLine, line);				
				this._syntax.setGlobalField(Syntax.FieldLineNumber, lineCount.toString());
				html += this.convertLineToHTML(line) + add;
				lineCount += 1;
			}
			return html;
		}
		
		
		private function initConverter():void
		{
			_inPre = false;
			_inTable = false;
			_inBulletList = false;
			_paragraphStarted = false;
			_ignoreParagraphs = false;
			_bulletDepth = 0;
			_currentBlock = null;
			_bulletMode = new Array();
			_tableFirstSection = false;
			_tableSectionClass = "";
			_tableNewSection = false;
		}
		
		/**
		 * Clean up some attributes to not confuse the next conversion. 
		 * 
		 */		
		private function cleanUp(html:String):String
		{
			var ret:String = "";
			
			if (this._inBulletList) ret += this.closeAllBullets();
			if (this._inTable) ret += this._syntax.replace(Syntax.RTableEnd, this._syntax.createFromArgs(Syntax.RTableEnd));
			if (this._paragraphStarted) ret = ret + "</p>";
			
			ret = html + ret;
			ret = ret.replace(/<p>[\s\r\n]*<\/p>/g, "");													// Remove empty paragraphs 
			
			this.initConverter();
			
			return ret;
		}
		
		
		override public function convertLine(line:String):String
		{
			return this.convertLineToHTML(line);
		}
		

		/**
		 * Convert one single line. 
		 * @param line	Line to convert
		 * @return 		Converted text.
		 * 
		 */		
		private function convertLineToHTML(line:String, escapeHTML:Boolean = true):String
		{
			var html:String = line;
		
			if ((this.isEmpty(line)) && (!this._inPre)	&& (!this._inTable))									// If it is an empty line
				if (this._paragraphStarted) return "</p><p>";								// And we have previously started a paragraph, start a new one
				else return "";																// Otherwise return nothing
			
			html = this.escape(html);
		
			
			var block:String 
			
			block = this._syntax.isBlockBegin(html)
			if (block) 
			{	
				html = this._syntax.replace(block, html);
				this._blockCode = "";
				if (html.search(/<pre[^\/]*>/g) != -1)
					this._inPre = true;
				this._syntax.blockFilter = block;
				return this.closeAllBullets() + this.handleParagraphs(html);
			}
					
			block = this._syntax.isBlockEnd(html);
			if (block) 
			{
				this._syntax.setGlobalField(Syntax.FieldBlockContentCode, this._blockCode);
				html = this._syntax.replace(block, html);
				this._syntax.clearBlockFilter();
				this._blockCode = null;
							
				if (html.search(/<\/pre\s*>/g) != -1)
					this._inPre = false;
				return this.handleParagraphs(html);
			}
			
			if ((!block) && (this._blockCode != null)) this._blockCode += line + "\r";
			
										
			//Table
			if (!this._inTable)
			{
				if (this.startsTable(html))
				{
					this._inTable = true;
					return this.processTableHead(html);
				}	
			}
			else 
			{
				if (this.endsTable(html))
				{
					this._inTable = false;
					return "</tbody>" + this._syntax.replace(Syntax.RTableEnd, html);
				}
				else return this.processTableRow(html);
			}

					
			html = this._syntax.replaceG(Syntax.REscapeRelIMG, html);			// Escape the : in relimglinks so we can use them as Descriptions for file links
			
						
			html = this.processHeadlines(html);

			html = this.processBullets(html);
					
			html = this.convertInlineElements(html);
			
			if (!this._inPre) html = this.handleParagraphs(html);
									
			return html;
		}
		
		
		private static const RegIgnoreParagraphs:RegExp = 		/<pre>|<table>|<ul>|<ol>|<dl>|<hr\/>/;
		private static const RegStopIgnoringParagraphs:RegExp = /<\/pre>|<\/table>|<\/ul>|<\/ol>|<\/dl>|<hr\/>/;
		private static const RegCloseParagraphBefore:RegExp = 	/<h.>|<hr\/>|<pre>|<table>|<ul>|<ol>|<dl>|<li>|<title>|<head>/
		
		private function handleParagraphs(str:String):String
		{
			if (this._ignoreParagraphs) 
			{
				if ((str.search(HTMLConverter.RegStopIgnoringParagraphs) != -1))
					this._ignoreParagraphs = false;
				return str;
			}
			if ((str.search(HTMLConverter.RegIgnoreParagraphs) != -1))
			{
				this._ignoreParagraphs = true;
			}

			if ((str.search(HTMLConverter.RegCloseParagraphBefore) != -1))
			{
				if (this._paragraphStarted)
				{
					str = "</p>\r" + str;
					this._paragraphStarted = false;
				}
			}
			else
			{
				if ((!this._paragraphStarted) && (!this._inTable) && (!this._ignoreParagraphs))
				{
					this._paragraphStarted = true;
				 	str = "<p>" + str;
				}
			}
			
			return str;
		}
		
		
		
		private function convertInlineElements(str:String):String
		{
			str = this._syntax.replaceG(Syntax.RTodo, str);
			str = this._syntax.replaceG(Syntax.RDone, str);
			str = this._syntax.replaceG(Syntax.RWikiLink, str);
			str = this._syntax.replaceG(Syntax.RWebLink, str);
			
			str = this._syntax.applyNonStandardRules(str);		

			return str;
		}
		
		
		/**
		 * Checks if a string is empty, i.e. it contains only whitespace 
		 * @param str
		 * @return 
		 * 
		 */		
		private function isEmpty(str:String):Boolean
		{
			if (!str) return true;
			var test:Array = str.match(/^\s*$/);
			if (test) return true;
			return false;
		}
		
		
		/**
		 * Escape special characters. The user can escape special characters using a backslash.
		 * :, [, ], { and } can be escaped. they are replaced by their HTML unicode entites. 
		 * @param str	String
		 * @return 		String with replaced characters
		 * 
		 */		
		private function escape(str:String):String
		{
			var ret:String = str;
			ret = ret.replace(/\\\:/g, "&#0058;");
			ret = ret.replace(/\\\[/g, "&#0091;");	
			ret = ret.replace(/\\\]/g, "&#0093;");	
			ret = ret.replace(/\\\{/g, "&#0123;");	
			ret = ret.replace(/\\\}/g, "&#0125;");
			return ret;				
		}
		
		/**
		 * Process headline rules on string 
		 * @param str	Input
		 * @return 		Converted text
		 * 
		 */		
		private function processHeadlines(str:String):String
		{
			str = this._syntax.replaceG(Syntax.RHeadlineL1, str);						
			str = this._syntax.replaceG(Syntax.RHeadlineL2, str);						
			str = this._syntax.replaceG(Syntax.RHeadlineL3, str);						
			str = this._syntax.replaceG(Syntax.RHeadlineL4, str);						
									
			return str;
		}
		
		
		/**
		 * Tests if a line begins a table. 
		 * @param str	The line to test
		 * @return 		True if it begins a table
		 * 
		 */		
		private function startsTable(str:String):Boolean
		{
			return this._syntax.doesMatch(Syntax.RTableBegin, str);
		}
		
		/**
		 * Tests if a line ends a table 
		 * @param str	The line to test
		 * @return 		True if it ends a table
		 * 
		 */
		private function endsTable(str:String):Boolean
		{
			return this._syntax.doesMatch(Syntax.RTableEnd, str);
		}
		
		
		
		
		private static const RegTableCellHasClassCode:RegExp = /^\-([a-zA-Z0-9\-]+)\s+(.+)/;
		
		/**
		 * Process table segments. Splits a tring up by the table cell delimiter defined by the syntax. 
		 * @param str		The string to process
		 * @param element	The element to use. td or th
		 * @return 			A string with the generated HTML code. No tr added.
		 * 
		 */
		private function processTableSegments(str:String, element:String):String
		{
			if (this.isEmpty(str)) return "";
			
			var segments:Array = str.split(this._syntax.tableCellDelimiter);
			var ret:String = "";
			
			var cls:String;
			var regres:Object;
			
			for each (var seg:String in segments)
			{
				regres = HTMLConverter.RegTableCellHasClassCode.exec(seg);
				if (regres)
				{
					cls = " class=\"" + regres[1] + "\"";
					seg = regres[2];
				}
				else cls = "";
				ret += "<" + element + cls + ">" + this.convertInlineElements(seg) + "</" + element + ">";
			}
			
			return ret;			
		}
		
		private function processTableHead(str:String):String
		{
			var begin:String = this._syntax.replace(Syntax.RTableBegin, str);
			str = this._syntax.replaceOverride(Syntax.RTableBegin, str, "");			
			begin = begin.substr(0, begin.length - str.length);
			 
			var ret:String = this.processTableSegments(str, "th");

			this._tableFirstSection = true;
			this._tableNewSection = true;
			if (ret != "") return begin + "<thead><tr>" + ret + "</tr></thead><tfoot/>";
			return begin;
		}
				
		private function processTableSectionFlag(str:String):String
		{
			var reg:RegExp = new RegExp("^\\-([^\\s\\t]*)[\\s\\t]*$");
			var arr:Array = str.match(reg); 
			if (str.match(reg))
			{
				return str.replace(reg, "$1");
			}
			return null;
		}
		
				
		private function processTableRow(str:String):String
		{
			var section:String = this.processTableSectionFlag(str);
			var pref:String = "";
			
			if (section != null)
			{
				this._tableNewSection = true;
				this._tableSectionClass = section;
				return "";
			}
			if (this._tableNewSection)
			{
				if (!this._tableFirstSection)
					pref = "</tbody>";
				else this._tableFirstSection = false;
				pref += "<tbody class=\"" + this._tableSectionClass + "\">";
				this._tableNewSection = false;
			}
			
			var ret:String = this.processTableSegments(str, "td"); 
			if (ret != "") 
			{
				return pref + "<tr>" + ret + "</tr>";
			}
			return ret;	
		}
		
			
		
		
		private function checkBulletMode(str:String):String
		{
			var regUL:RegExp = /^(\t+\* ).*/;
			var regOL:RegExp = /^(\t+\# ).*/;
			
			if (str.match(regUL))
			{
				return "ul";
			}
			if (str.match(regOL))
			{
				return "ol";
			}
			return null;
		}		
		
		private function removeBulletCode(str:String):String
		{
			var reg:RegExp;
			if (this._currentBulletMode == "ul")
				reg = /^\t+\* (.*)/;
			else
				reg = /^\t+\# (.*)/;
				
			return str.replace(reg, "$1");							
		}


		private function getBulletDepth(str:String):int
		// Get depth of the bullet. Done by counting the tabs. But only advance by +/- 1
		{
			var reg1:RegExp;
			reg1 = /^(\t+).*/;
			
			var reg2:RegExp = /\t/g;
			var tmp:String = str.replace(reg1, "$1");
			var arr:Array = tmp.match(reg2);
			
			if (arr) return arr.length;
			
			return 0;
		}			
		
		private function processBullets(str:String):String
		{
			var ret:String = str;
			var newMode:String;
			
			newMode = this.checkBulletMode(str);
		
			if (newMode)																					// When we are in bullets now
			{
				if (!this._inBulletList)																	// ... but have not been before
				{
					this._currentBulletMode = newMode;
					this._bulletMode = new Array();
					ret = this.removeBulletCode(ret);														// Remove bullet code
					this._inBulletList = true;																// We are now in bullets
					this._bulletDepth = 1;																	// always start at depth 1
					ret = "<" + this._currentBulletMode + "><li>" + ret;									// Create list according to mode and start list item
				}
				else																						// ... we already have been in bullet mode
				{
					var depth:int = this.getBulletDepth(ret);												// Get bullet depth
					if (this._bulletDepth < depth)															// If we're deeper than before
					{
						this._bulletMode.push(this._currentBulletMode);
						this._currentBulletMode = newMode;
						ret = this.removeBulletCode(ret);														// Remove bullet code
						ret = "<" + this._currentBulletMode + "><li>" + ret;								// 		Open new list and start list item
					}
					else if (this._bulletDepth > depth)														// If we're shallower than before
					{						
						var prev:String = "";
						for (var i:int = this._bulletDepth; i > depth; i--)
						{
							prev += "</li></" + this._currentBulletMode + ">";
							this._currentBulletMode = this._bulletMode.pop();
						}
						this._currentBulletMode = newMode;
						ret = this.removeBulletCode(ret);													// Remove bullet code
						ret = prev + "</li><li>" + ret;														//		Close previous item and close previous list and start list item
					}
					else 
					{
						ret = this.removeBulletCode(ret);														// Remove bullet code
						ret = "</li><li>" + ret;															// If we#re on the same level, close previous list item and start new one						
					}
					this._bulletDepth = depth;																//Set current depth
				}
			}
			else 																							// ... we're not in bullet mode
			{
				if (this._inBulletList)																		// ... but have been before
				{
					ret = this.closeAllBullets() + this.handleParagraphs(ret);
					this._inBulletList = false;
				}
			}
			return ret;			
		}
		
		private function closeAllBullets():String
		{
			if (!this._inBulletList) return "";
			
			var ret:String = "";
			var cb:String;
			this._inBulletList = false;																// Now we're not
			var pref:String;					
			pref = "</li>";																			// Close previous list item
			for (var i:int = this._bulletDepth; i > 1; i--)											// For all open lists except the first one
			{
				cb = this._bulletMode.pop();
				pref = pref + "</" + cb + ">";										// ... close that list
			}
			ret = pref + "</" + this._currentBulletMode + ">" + ret;										// Close first list also.
			this._bulletDepth = 0;
			
			return ret;
		}
		
		
	}
}