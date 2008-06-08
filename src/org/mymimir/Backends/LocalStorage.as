package org.mymimir.Backends
{
	import flash.data.SQLConnection;
	import flash.data.SQLResult;
	import flash.data.SQLStatement;
	import flash.errors.SQLError;
	import flash.events.ErrorEvent;
	import flash.events.EventDispatcher;
	import flash.events.SQLEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileStream;
	import flash.net.Responder;
	import flash.utils.ByteArray;
	
	import org.mymimir.sdk.Events;
	import org.mymimir.sdk.IWiki;
	import org.mymimir.sdk.IWikiBackend;
	import org.mymimir.sdk.IWikiPage;
	import org.mymimir.sdk.MYMError;
	import org.mymimir.sdk.Tools;




	/**
	 * Locat storage backend. Stores all the files on your local harddrive (and network paths). The folder structure is
	 * 
	 * 		<ul>
	 * 			<li>Root
	 * 				<ul><li>Pages
	 * 						<ul><li>Page1.wiki</li>
	 * 							<li>Page2.wiki</li>
	 * 							<li>(…)</li>
	 * 						</ul>
	 * 					</li>
	 * 					<li>Data (stores dropped Files, images, etc)</li>
	 * 					<li>Style
	 * 						<ul><li>wiki.css</li>
	 * 							<li>(put here anything else you need for your styles)</li>
	 * 						</ul>
	 * 					</li>
	 * 					<li>settings.xlm</li>
	 * 				</ul>
	 * 			</li>
	 * 		</ul> 
	 * @author smola
	 * 
	 */
	public class LocalStorage extends EventDispatcher implements IWikiBackend
	{
 		private static const settingsFileName:String = "settings.xml";
		private static const dbFileName:String = "wiki.db";
		private static const pagesDirName:String = "Pages";
		private static const dataDirName:String = "Data";
		private static const styleDieName:String = "Style";
		private static const stylePath:String = "Style/wiki.css";
		private static const pageFileExtension:String = ".wiki";
		private static const regFT:RegExp = /[^\wäÄöÖüÜáÁàÀéÈèÈíÍìÌóÓòÒúÚùÙñÑ]+/g;
		

		private var _wiki:IWiki;
		private var _directory:File;
		private var _pageDirectory:File;
		private var _dataDirectory:File;
		private var _styleDirectory:File;
		private var _dbFile:File;

		private var _asyncElement:Object;
		private var _asyncStat:SQLStatement;
		private var _asyncRes:Responder
		private var _asyncConn:SQLConnection;
		private var _asyncQueue:Array = new Array();
		
		

		public function LocalStorage()
		{
		}



		/* Interface implementation
		*******************************************************************************************/

		/**
		 * Set wiki property 
		 * @param value
		 * 
		 */
		public function set wiki(value:IWiki):void
		{
			if (this._wiki) this.close();
			this._wiki = value;
		}
		
		
		/**
		 * Open the wiki that's set in the wiki property. 
		 * @return 
		 * 
		 */
		public function open():Boolean
		{
			if (!this._wiki) return false;
			if (this._directory) this.close();
			
			this._directory = new File(this._wiki.url);
			if ((!this._directory.exists) || (!this._directory.isDirectory))
			{
				this.dispatchEvent(new ErrorEvent(org.mymimir.sdk.Events.BACKEND_ERROR_FAILED_TO_OPEN, true, false,
									"Could not find directory " + this._wiki.url));
				return false;
			}
									
			this._pageDirectory = this._directory.resolvePath(LocalStorage.pagesDirName);
			if ((!this._directory.exists) || (!this._directory.isDirectory))
			{
					this.dispatchEvent(new ErrorEvent(org.mymimir.sdk.Events.BACKEND_ERROR_FAILED_TO_OPEN, true, false,
										"Could not find pages directory "));
				return false;
			}

			this._dataDirectory = this._directory.resolvePath(LocalStorage.dataDirName);
			if ((!this._directory.exists) || (!this._directory.isDirectory))
			{
					this.dispatchEvent(new ErrorEvent(org.mymimir.sdk.Events.BACKEND_ERROR_FAILED_TO_OPEN, true, false,
										"Could not find data directory "));
				return false;
			}
			
			this._dbFile = this._directory.resolvePath(LocalStorage.dbFileName);
			
			return true;
		}
		
		public function promptForOpen(resultCB:Function, ... args):void
		{
			
		}
		
  	   /* Create
		******************************************************************************************/
		
		public function create():Boolean
		{
			if (!this._wiki) return false;
			if (this._directory) this.close();
			
			if (this.createDirectories())
			{
				if (this.createDatabase())
				{
					return true;		
				}
			}
			
			return false;
		}
		
		
		private function createDirectories():Boolean
		{
			this._directory = new File(this._wiki.url);
			this._directory.createDirectory();
			this._pageDirectory = this._directory.resolvePath(LocalStorage.pagesDirName);
			this._pageDirectory.createDirectory();
			this._dataDirectory = this._directory.resolvePath(LocalStorage.dataDirName);
			this._dataDirectory.createDirectory();
			this._styleDirectory = this._directory.resolvePath(LocalStorage.styleDieName);
			this._styleDirectory.createDirectory();
		
			return true;
		}
		
		
		
		/* Database creation
		 ******************************************************************************************/
		
		
		private function doSQLSync(connection:SQLConnection, sqlStr:String):void
		{
			var sqlStat:SQLStatement = new SQLStatement;
			
			sqlStat.sqlConnection = connection;
			sqlStat.text = sqlStr;
			sqlStat.execute();			
		}
		
		private function createDatabase():Boolean
		{
			var connection:SQLConnection = new SQLConnection();
			this._dbFile = this._directory.resolvePath(LocalStorage.dbFileName);
			
			connection.open(this._dbFile);
			
			createTablePages(connection);
			createTableLinks(connection);
			createTableTodos(connection);
			createTableFTPages(connection);
			
			connection.close();
			
			return true;
		}


		private function createTablePages(connection:SQLConnection):void
		{
			var sqlPages:String = "CREATE TABLE pages (id INTEGER PRIMARY KEY AUTOINCREMENT," +					// Table to store pages (not the contents)
						  				   		     " name TEXT," + 											// Page name
												     " created TEXT," + 										// Created timestamp
												     " changed TEXT" +											// Changed time tamp
												     " );";
			this.doSQLSync(connection, sqlPages);			
		}
		
		
		/**
		 * Create links table. This stores for every page to which other pages it links. Used for page tree. 
		 * 
		 */		
		private function createTableLinks(connection:SQLConnection):void
		{
			var sqlLinks:String = "CREATE TABLE links (id INTEGER PRIMARY KEY AUTOINCREMENT," +					// Table to store page links used for quicker tree creation 
							                         " name TEXT," + 											// Name of the page (link from)
							                         " link TEXT" + 											// link to ...
							                         ");"
			this.doSQLSync(connection, sqlLinks);			
		}
		
		
		/**
		 * Create todo table. Stores all todos in the wiki. 
		 * 
		 */		
		private function createTableTodos(connection:SQLConnection):void
		{
			var sqlTodos:String = "CREATE TABLE todos (id INTEGER PRIMARY KEY AUTOINCREMENT," +					// Table for todos 
													   "page	TEXT," +										// Page on which todo is
													   "headlines TEXT," + 										// Headline hierarchy preceding todo
													   "begin TEXT," + 											// Start date
													   "end TEXT," + 											// End date
													   "pred INTEGER," + 										// Predecessor todo
													   "text TEXT," + 											// Todotext
													   "done INTEGER" +											// done=1
													  ");"
			this.doSQLSync(connection, sqlTodos);			
		}
		
		
		/**
		 * Create full text search table. Quite cheap atm. Stores for every page all words separated by space in one string. 
		 * 
		 */		
		private function createTableFTPages(connection:SQLConnection):void
		{
			var sqlFtPages:String = "CREATE TABLE ftPages (id INTEGER PRIMARY KEY AUTOINCREMENT," + 
														  "page		TEXT," + 
														  "words	TEXT" + 
														  ");";								  
			this.doSQLSync(connection, sqlFtPages);
		}
		

		
		
		public function close(resultCB:Function = null, ... args):void
		{
			this._directory = null;
			this._pageDirectory = null;
			this._dataDirectory = null;
			this._styleDirectory = null;
			this._dbFile = null;
		}
		
		
		
		public function getWikiSettingsURL():String
		{
			var file:File = this._directory.resolvePath(LocalStorage.settingsFileName);
			return file.url;			
		}
		
		
		public function getWikiSettings(resultCB:Function=null, ... args):void
		{
			var file:File = this._directory.resolvePath(LocalStorage.settingsFileName);
			var settings:XML;
			if (!file.exists) 
			{
				if (resultCB != null)
					resultCB.apply(this, [false, null].concat(args));
				return;
			}
			
			var stream:FileStream = new FileStream;
			stream.open(file, flash.filesystem.FileMode.READ);
			try
			{
				settings = new XML(stream.readUTFBytes(file.size));
			}
			catch(err:TypeError)
			{
				if (resultCB != null)
					resultCB.apply(this, [false, null].concat(args));
				throw new MYMError(MYMError.ErrorLoadXML, err.message, file.url);	
			}
			finally
			{
				stream.close();
			}			
			if (resultCB != null)
				resultCB.apply(this, [true, settings].concat(args));
		}
		
		public function setWikiSettings(settings:XML, resultCB:Function=null, ... args):void
		{
			var file:File = this._directory.resolvePath(LocalStorage.settingsFileName);
			var stream:FileStream = new FileStream;
			stream.open(file, flash.filesystem.FileMode.WRITE);
			stream.writeUTFBytes(settings.toXMLString());
			stream.close();
			if (resultCB != null)
				resultCB.apply(this, [true].concat(args));
		}
		
		
		public function checkPageExists(name:String):Boolean
		{
			return this.createPageFileObject(name).exists;
		}
		
		
		public function getPageText(name:String, resultCB:Function=null, ... args):void
		{
			var file:File = this.createPageFileObject(name);
			if (!file.exists)
			{
				if (resultCB != null)
					resultCB.apply(this, [false, null].concat(args));
			}
			
			var stream:FileStream = new FileStream;
			stream.open(file, flash.filesystem.FileMode.READ);
			var text:String = stream.readUTFBytes(file.size);
			stream.close();
			
			if (resultCB != null)
				resultCB.apply(this, [true, text].concat(args));
			
		}
		
		public function renamePage(oldName:String, newName:String, resultCB:Function=null, ... args):void
		{
			var file1:File = this.createPageFileObject(oldName);
			var file2:File = this.createPageFileObject(newName);
			
			if ((!file1.exists) || (file2.exists))
			{
				if (resultCB != null)
					resultCB.apply(this, [false, newName].concat(args));
				return;
			}
			
			file1.moveTo(file2, false);

			if (resultCB != null)
				resultCB.apply(this, [true, newName].concat(args));
			
		}
		
		public function deletePage(name:String, resultCB:Function=null, ... args):void
		{
		}
		
		
		public function setPageText(name:String, content:String, resultCB:Function=null, ... args):void
		{
			var file:File = this.createPageFileObject(name);
			var stream:FileStream = new FileStream;
			stream.open(file, flash.filesystem.FileMode.WRITE);
			stream.writeUTFBytes(content);
			stream.close();
			
			if (resultCB != null)
				resultCB.apply(this, [true].concat(args));
			
		}
		
		public function storePageData(page:IWikiPage, resultCB:Function=null, ... args):void
		{
			this.beginAsyncLUW();
			this.storePage(page.name);
			this.storePageLinksAsync(page.name, page.links);
			this.storePageTodosAsync(page.name, page.todos);
			
			this.nextEndsAsyncLUW(resultCB, args);
			this.storeFTAsync(page.name, page.text);
		}




				
				
		private function cbGetPages(success:Boolean, result:SQLResult, error:SQLError, resultCB:Function, ... args):void
		{
			if (success)
			{
				if (result.data)
				{
					var pages:Array = new Array();
					for each (var item:Object in result.data)
						pages.push(item.name);
					if (resultCB != null)
						resultCB.apply(this, [true, pages].concat(args));					
				}
				else
				{
					if (resultCB != null)
						resultCB.apply(this, [true, null].concat(args));
				}
			}	
			else
			{
				if (resultCB != null)
					resultCB.apply(this, [false, null].concat(args));				
			}
		}
		
		
		public function getPages(resultCB:Function=null, ... args):void
		{
			this.queueAsync("SELECT name FROM pages ORDER BY name;", this.cbGetPages, resultCB, args);
		}
		

		public function getPagesByFilter(filter:String, resultCB:Function=null, ... args):void
		{
			this.queueAsync("SELECT name FROM pages WHERE name LIKE '" + filter + "' ORDER BY name", this.cbGetPages, resultCB, args);
		}
		
		public function getNotLinkedPages(resultCB:Function=null, ... args):void
		{
			this.queueAsync("SELECT pages.name as name, count(links.link) / count(links.link) as count" + 
											   "  FROM pages" + 
											   "  LEFT OUTER JOIN links" + 
											   "    ON links.name = pages.name" + 
											   " WHERE pages.name NOT IN (SELECT link FROM links)" + 
											   " GROUP BY pages.name" + 
											   " ORDER BY count DESC, pages.name ASC;", this.cbGetPages, resultCB, args);
		}

		public function getLinkeByPages(name:String, resultCB:Function=null, ... args):void
		{
			this.queueAsync("SELECT name FROM links WHERE link = '" + name + "';", this.cbGetPages, resultCB, args);
		}





		private function cbGetTodos(success:Boolean, result:SQLResult, error:SQLError, resultCB:Function, ... args):void
		{
			if (success)
			{
				if (result.data)
				{
					var todos:Array = result.data;
					if (resultCB != null)
						resultCB.apply(this, [true, todos].concat(args));					
				}
				else
				{
					if (resultCB != null)
						resultCB.apply(this, [true, null].concat(args));
				}
			}	
			else
			{
				if (resultCB != null)
					resultCB.apply(this, [false, null].concat(args));				
			}			
		}

		public function getTodos(resultCB:Function=null, ... args):void
		{
			this.queueAsync("SELECT page, text as task, begin as due FROM todos;", this.cbGetTodos, resultCB, args);
		}
		
		
		
		
		
		
		
		public function cbGetPageLinks(success:Boolean, result:SQLResult, error:SQLError, resultCB:Function, ... args):void
		{
			if (success)
			{
				if (result.data)
				{
					var links:Array = new Array;
					
					for each (var item:Object in result.data)
						links.push(item.link)
					if (resultCB != null)
						resultCB.apply(this, [true, links].concat(args));					
				}
				else
				{
					if (resultCB != null)
						resultCB.apply(this, [true, null].concat(args));
				}
			}	
			else
			{
				if (resultCB != null)
					resultCB.apply(this, [false, null].concat(args));				
			}			
		}
		
		public function getPageLinks(name:String, resultCB:Function=null, ... args):void
		{
			this.queueAsync("SELECT links1.link AS link, COUNT(links2.link) / COUNT(links2.link) as count" + 
											   "  FROM links AS links1" + 
											   "  LEFT OUTER JOIN links AS links2" + 
											   "    ON links2.name = links1.link" + 
											   "  WHERE links1.name = '" + name + "'" + 
											   "  GROUP BY links1.link" + 
											   "  ORDER BY count DESC, links1.link ASC", this.cbGetPageLinks, resultCB, args);
		}
		
		
		
		
		
		public function cbGetAllPageLinks(success:Boolean, result:SQLResult, error:SQLError, resultCB:Function, ... args):void
		{
			if (success)
			{
				if (result.data)
				{
					var links:Object = new Object();
					var page:String = null;
					
					for each (var item:Object in result.data)
					{
						if (item.name != page)
						{		
							page = item.name;
							links[page] = new Array();
						}
						links[page].push(item.link);
					}
					if (resultCB != null)
						resultCB.apply(this, [true, links].concat(args));					
				}
				else
				{
					if (resultCB != null)
						resultCB.apply(this, [true, null].concat(args));
				}
			}	
			else
			{
				if (resultCB != null)
					resultCB.apply(this, [false, null].concat(args));				
			}			
		}
		
		public function getAllPageLinks(resultCB:Function = null, ... args):void
		{
			this.queueAsync("SELECT name, link FROM links ORDER BY name", this.cbGetAllPageLinks, resultCB, args);
		}		
		
		
		
		
		
		private function cbSearchFT(success:Boolean, result:SQLResult, error:SQLError, qWords:Array, previousResult:Array, resultCB:Function, ... args):void
		{
			if ((qWords) && (qWords.length > 1))
			{
				var wClause:String = "";
				var notIn:String = "";
				for each (var w:String in qWords)
				{
					if (wClause != "") wClause += " OR ";
					wClause += "words LIKE '%" + Tools.stripWhiteSpace(w) + "%'";
				}
				
				for each (var p:Object in res)
				{
					if (notIn != "") notIn += ", ";
					notIn += "'" + p.page + "'";
				}
							
							
				this.queueAsync("SELECT page, words FROM ftPages WHERE ( " + wClause + " ) AND page NOT IN (" + notIn + ");",
								this.cbSearchFT, null, result.data, resultCB, args);
			}
			else
			{
				var res:Array;
				if ((result.data) && (previousResult))
					res = result.data.concat(previousResult);
				else if (result.data) res = result.data;
				else if (previousResult) res = previousResult;
				
				if (resultCB != null)
					resultCB.apply(this, [true, res].concat(args));
			}			
		}
		
		public function searchFullText(query:String, resultCB:Function=null, ... args):void
		{
			query = Tools.stripWhiteSpace(query);
			
			var dbRes:SQLResult;
			var qWords:Array = query.split(" ");
			var wClause:String = "";
			var res:Array;
			var w:String;
			var notIn:String = "";
			
			
			for each (w in qWords)
			{
				if (wClause != "") wClause += " AND ";
				wClause += "words LIKE '%" + Tools.stripWhiteSpace(w) + "%'";
			}
						
			this.queueAsync("SELECT page, words FROM ftPages WHERE " + wClause + ";", this.cbSearchFT, qWords, null, resultCB, args);			
		}
		
		public function storeArbData(storageName:String, key:Object, data:Object, resultCB:Function=null, ... args):void
		{
		}
		
		public function getArbData(storageName:String, key:Object, resultCB:Function=null, ... args):void
		{
		}
		
		public function storeFileInData(file:File, resultCB:Function = null, ... args):String
		{
			if (file.isDirectory) 
			{
		 		if (resultCB != null)
		 			resultCB.apply(this, [false, null].concat(args));
				return null;					
			}
			
	 		var fn:String = this.getUniqueFilename(file.extension);
	 		var fileTo:File = this._dataDirectory.resolvePath(fn)
	 		file.copyTo(fileTo, true);
	 		
	 		if (resultCB != null)
	 			resultCB.apply(this, [true, fn].concat(args));
	 		
	 		return fileTo.url;			
		}
		
		public function storeBytesAsFileInData(bytes:ByteArray, extension:String, resultCB:Function = null, ... args):String
		{
	 		var fn:String = this.getUniqueFilename(extension);
	 		var fileTo:File = this._dataDirectory.resolvePath(fn)
	 		var fs:FileStream = new FileStream();

			fs.open(fileTo, flash.filesystem.FileMode.WRITE );
			fs.writeBytes(bytes, 0, 0);
			fs.close();
	 		
	 		if (resultCB != null)
	 			resultCB.apply(this, [true, fn].concat(args));
			
	 		return fileTo.url;			
		}		
		
		public function getDataURLForFilename(filename:String):String
		{
			var file:File = this._dataDirectory.resolvePath(filename);
			if (file.exists) return file.url;
			return null;
		}
		
		public function getFilenameFromDataURL(url:String):String
		{
			var f:File = new File(url);
			return this._dataDirectory.getRelativePath(f);
		}
		
		public function getUniqueFilename(extension:String):String
		{
			var t:Number = new Date().time;
			var ret:String;
			while (1 == 1)
			{
				ret = t.toString() + "." + extension;
				if (!this._dataDirectory.resolvePath(ret).exists)
					return ret;
			}
			return null;
		}
		
		public function getStylesheetURL():String
		{
			var f:File = this._directory.resolvePath(LocalStorage.stylePath)
			if (f.exists) return f.url + "?trickster=1";
			return null;
		}
		
		
		/* Tools
		*******************************************************************************************/
		
		protected function createPageURL(name:String):String
		{
			return this._pageDirectory.resolvePath(name + LocalStorage.pageFileExtension).url;
		}
		
		protected function createPageFileObject(name:String):File
		{
			var ret:File = this._pageDirectory.resolvePath(name + LocalStorage.pageFileExtension);
			return ret;
		}



		/* DB access
		*******************************************************************************************/		
		/**
		 * Stores the page into the pages table if it is not yet in it. 
		 * @param name
		 * 
		 */
		private function storePage(name:String):void
		{
			this.queueAsync("DELETE FROM pages WHERE name = '" + name + "';");
			this.queueAsync("INSERT INTO pages (name) VALUES ('" + name + "');");
		}
		
		private function storePageLinksAsync(name:String, links: Array):void
		{
			this.queueAsync("DELETE FROM links WHERE name = '" + name + "';");
			
			if (links)
			{
				for each (var link:String in links)
				{
					this.queueAsync("INSERT INTO links (name, link) VALUES ('" + name + "', '" + link.substr(1, link.length - 2) + "');");
				}
			}	
		}
		
		private function storePageTodosAsync(name:String, todos:Array):void
		{
			this.queueAsync("DELETE FROM todos WHERE page = '" + name + "';");
			if (todos)
			{
				for each (var todo:Object in todos)
				{
					this.queueAsync("INSERT INTO todos (page, begin, text) VALUES ('" + name + "', '" + todo.due + "', '" + todo.task + "');");
				}
			}
		}
		
		private function storeFTAsync(page:String, text:String):void
		{
			text = text.replace(LocalStorage.regFT, " ");									// Remove everything thats not a character or digit
			this.queueAsync("DELETE FROM ftPages WHERE page = '" + page + "';");
			this.queueAsync("INSERT INTO ftPages (page, words) VALUES ('" + page + "', '" + text + "');");			
		}


		/* Async DB queue
		*******************************************************************************************/
		
		private var _beginLUW:Boolean = false;
		private var _endLUW:Boolean = false;
		private var _endLUWCB:Function;
		private var _endLUWArgs:Array;
		
		private function beginAsyncLUW():void
		{
			this._beginLUW = true;
		}
		
		private function nextEndsAsyncLUW(resultCB:Function, ... args):void
		{
			this._endLUW = true;
			this._endLUWCB = resultCB;
			this._endLUWArgs = args;
		}
				
		private function queueAsync(sql:String, cbResult:Function = null, ... args):void
		{
			var newEl:Object = new Object();
			newEl.sql = sql;
			newEl.cbResult = cbResult;
			newEl.args = args;
			newEl.beginLUW = this._beginLUW;
			newEl.endLUW = this._endLUW;
			newEl.endLUWCB = this._endLUWCB;
			
			if (this._beginLUW) this._beginLUW = false;	
			if (this._endLUW) this._endLUW = false; 
			
			this._asyncQueue.push(newEl);
			if ((this._asyncQueue.length != 0) && (!this._asyncConn))
				this.processAsyncQueue();
		}



		public function processAsyncQueue():void
		{
			this._asyncConn = new SQLConnection();
			this._asyncRes = new Responder(this.onAsyncOpened, this.onAsyncOpenError);
			this._asyncConn.openAsync(this._dbFile, "create", this._asyncRes);
		}

		private function onAsyncOpened(res:SQLEvent):void
		{
			this._asyncStat = new SQLStatement;	
			this._asyncStat.sqlConnection = this._asyncConn;
			this._asyncRes = new Responder(this.onAsyncResult, this.onAsyncError);
			this.processNextAsync();					
		}
		
		private function onAsyncOpenError(err:SQLError):void
		{
			throw new Error(err.message);
		}


		private function onAsyncResult(res:SQLResult):void
		{
			if (this._asyncElement.endLUW)
			{
				this._asyncConn.commit();
				if (this._asyncElement.endLUWCB != null)
					this._asyncElement.endLUWCB.apply(this, [true, res, null].concat(this._asyncElement.endLUWArgs));
			}
			if (this._asyncElement.cbResult != null) 
				this._asyncElement.cbResult.apply(this, [true, res, null].concat(this._asyncElement.args));
			this.processNextAsync();
		}
		
		private function onAsyncError(err:SQLError):void
		{
			if (this._asyncElement.cbResult != null) 
				this._asyncElement.cbResult.apply(this, [false, null, err].concat(this._asyncElement.args));
			this._asyncQueue.removeAll();			
		}


		private function processNextAsync():void
		{
			this._asyncElement = this._asyncQueue.shift();
			if (!this._asyncElement) 
			{
				this._asyncConn.close();
				this._asyncConn = null;
				return;
			}		
			trace("Process:", this._asyncElement.sql);

			if (this._asyncElement.beginLUW)
				this._asyncConn.begin();
			this._asyncStat = new SQLStatement();
			this._asyncStat.sqlConnection = this._asyncConn;		
			this._asyncStat.text = this._asyncElement.sql;
			this._asyncStat.execute(-1, this._asyncRes);
		}

	}
}