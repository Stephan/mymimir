package org.mymimir
{
	import flash.data.SQLConnection;
	import flash.data.SQLResult;
	import flash.data.SQLSchemaResult;
	import flash.data.SQLStatement;
	import flash.data.SQLTableSchema;
	import flash.errors.IllegalOperationError;
	import flash.errors.SQLError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.SQLEvent;
	import flash.filesystem.File;
	import flash.net.Responder;
	
	import mx.collections.ArrayCollection;
	
	import org.mymimir.sdk.MYMError;
	import org.mymimir.sdk.MYMMessage;
	import org.mymimir.sdk.Tools;
	
	/**
	 * Class to manage the SQLITE-Database of a Wiki 
	 * @author stephansmola
	 * 
	 */	
	public class WikiDB extends EventDispatcher
	{
		public static const EventAsyncQueueDone:String = "WikiDB.AsyncQueueDone";
		
		private static const TablePages:String = "pages";
		private static const TableLinks:String = "links";
		private static const TableTodos:String = "todos";
		private static const TableFTPages:String = "ftPages";
		private static var regFT:RegExp = /[^\wäÄöÖüÜáÁàÀéÈèÈíÍìÌóÓòÒúÚùÙñÑ]+/g;
		
		private var _path:File;
		private var _connection:SQLConnection;
		private var _beginCount:int;
		private var _openedByBegin:Boolean;
		
		private var _asyncQueue:ArrayCollection;
		
		
		public function WikiDB(path:File)
		{
			super(null);
			this._connection = new SQLConnection;
			this._path = path;
			if (!path.exists) this.create()
			else this.update();
			
			this._asyncQueue = new ArrayCollection(new Array);			
		}
		
		
		/**
		 * Close DB. 
		 * 
		 */		
		public function close():void
		{
			this.closeDatabaseSync();
		}
		
		
		/**
		 * Close snyc DB connection 
		 * 
		 */		
		public function closeDatabaseSync():void
		{
			if (!this._connection.connected) return;
			try
			{
				this._connection.close();
				trace ("DB closed");
			}
			catch (error:SQLError)
			{
				trace("Error on close", this._connection.inTransaction, this._connection.connected, "\n", this._connection);
			}
		}
		
		/**
		 * Open DB synchonously. 
		 * 
		 */
		public function openDatabaseSync():void
		{
			if (this._connection.connected) return;
			try
			{
				_connection.open(this._path);
				trace("DB opened");
			}
			catch (error:flash.errors.IllegalOperationError)
			{
				throw new MYMError(MYMError.ErrorConnectDB, "", this._path.url);
			}		
		}

		/**
		 * Do snychronous SQL call. If no connection is opened, this opens the connection and closes it again afterwards. Already opened connections stay open.
		 * @param sqlStr	SQL statement
		 * @return 			The result.
		 * 
		 */		
		private function doSQLSync(sqlStr:String):SQLResult
		{
			var opened:Boolean = false;
			if (!this._connection.connected)
			{
				this.openDatabaseSync();
				opened = true;
			}
			
			var sqlStat:SQLStatement = new SQLStatement;
			
			sqlStat.sqlConnection = this._connection;
			sqlStat.text = sqlStr;
			sqlStat.execute();
			
			var ret:SQLResult = sqlStat.getResult();
			sqlStat = null;
			if (opened) this.closeDatabaseSync();
			
			return ret;
		}


		/**
		 * Begin a transaction. Calls can be nested. Only the final call to commit really commits the db changes. 
		 * If there's no open connection one will be opened.
		 * 
		 */
		public function begin():void
		{
			trace ("Begin");
			if (!this._connection.connected) 
			{
				this.openDatabaseSync();
				if (!this._connection.connected) return;
				this._openedByBegin = true;
			}
			if (this._beginCount == 0) 
				this._connection.begin();
				
			this._beginCount += 1;
		}
		
		
		private function onFinalCommit(ev:Event):void
		{
			trace("OnFinalCommit");
			if (this._openedByBegin) 
				this.closeDatabaseSync();
		}
		/**
		 * Commit db changes. Calls can be nested. Only the last call to commit really commits the changes. 
		 * If the connection was opened by the first begin call it will be closed on the final commit.
		 */
		public function commit():void
		{
			trace("Commit");
			if (!this._connection.connected) return;
			this._beginCount -= 1;
			if (this._beginCount == 0) 
			{
				this._connection.commit(new Responder(this.onFinalCommit));
			}
		}












		private var _asyncElement:Object;
		private var _asyncStat:SQLStatement;
		private var _asyncRes:Responder;
		private var _asyncConn:SQLConnection;
		
		
		private function queueAsync(sql:String, cbDone:Function = null, cbError:Function = null):void
		{
			var newEl:Object = new Object();
			newEl.sql = sql;
			newEl.cbDone = cbDone;
			newEl.cbError = cbError;
			
			this._asyncQueue.source.push(newEl);
		}



		public function processAsyncQueue():void
		{
			this.closeDatabaseSync();
			this._asyncConn = new SQLConnection();
			this._asyncRes = new Responder(this.onAsyncOpened, this.onAsyncOpenError);
			this._asyncConn.openAsync(this._path, "create", this._asyncRes);
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


		private function onAsyncResult(ev:SQLResult):void
		{
			if (this._asyncElement.cbDone != null) this._asyncElement.cbDone.call(this, this._asyncStat.getResult());
			this.processNextAsync();
		}
		
		private function onAsyncError(err:SQLError):void
		{
			if (this._asyncElement.cbError != null) this._asyncElement.cbError.call(this, err);
			this._asyncQueue.removeAll();			
		}


		private function processNextAsync():void
		{
			this._asyncElement = this._asyncQueue.source.shift();
			if (!this._asyncElement) 
			{
				this.dispatchEvent(new Event(WikiDB.EventAsyncQueueDone));
				this._asyncConn.close();
				return;
			}		
			trace("Process:", this._asyncElement.sql);
		
			this._asyncStat.text = this._asyncElement.sql;
			this._asyncStat.execute(-1, this._asyncRes);
		}



















		
		/**
		 * Create database 
		 * 
		 */		
		private function create():void
		{
			this.update();
		}
		
		/**
		 * Create pages table. This stores the pages with their name, date of creation and date of change. 
		 * 
		 */		
		private function createTablePages():void
		{
			var sqlPages:String = "CREATE TABLE pages (id INTEGER PRIMARY KEY AUTOINCREMENT," +					// Table to store pages (not the contents)
						  				   		     " name TEXT," + 											// Page name
												     " created TEXT," + 										// Created timestamp
												     " changed TEXT" +											// Changed time tamp
												     " );";
			this.doSQLSync(sqlPages);			
		}
		
		
		/**
		 * Create links table. This stores for every page to which other pages it links. Used for page tree. 
		 * 
		 */		
		private function createTableLinks():void
		{
			var sqlLinks:String = "CREATE TABLE links (id INTEGER PRIMARY KEY AUTOINCREMENT," +					// Table to store page links used for quicker tree creation 
							                         " name TEXT," + 											// Name of the page (link from)
							                         " link TEXT" + 											// link to ...
							                         ");"
			this.doSQLSync(sqlLinks);			
		}
		
		
		/**
		 * Create todo table. Stores all todos in the wiki. 
		 * 
		 */		
		private function createTableTodos():void
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
			this.doSQLSync(sqlTodos);			
		}
		
		
		/**
		 * Create full text search table. Quite cheap atm. Stores for every page all words separated by space in one string. 
		 * 
		 */		
		private function createTableFTPages():void
		{
			var sqlFtPages:String = "CREATE TABLE ftPages (id INTEGER PRIMARY KEY AUTOINCREMENT," + 
														  "page		TEXT," + 
														  "words	TEXT" + 
														  ");";								  
			this.doSQLSync(sqlFtPages);
		}
		
		
		/**
		 * Update Database. Checks DB for the created tables and creates missing tables if necessary. 
		 * 
		 */		
		private function update():void
		{
			this.openDatabaseSync();
			var pages:Boolean = false;
			var links:Boolean = false;
			var todos:Boolean = false;
			var ftPages:Boolean = false;

			try
			{
				this._connection.loadSchema();
				var schema:SQLSchemaResult = this._connection.getSchemaResult();
								
				for each (var tab:SQLTableSchema in schema.tables)
				{
					if (tab.name == WikiDB.TablePages) pages = true;
					else if (tab.name == WikiDB.TableLinks) links = true;
					else if (tab.name == WikiDB.TableTodos) todos = true;
					else if (tab.name == WikiDB.TableFTPages) ftPages = true;
				}
			}
			catch (err:SQLError)
			{
				// Do  nothing, everything will be newly created;
			}
			
			if (!pages) this.createTablePages();
			if (!links) this.createTableLinks();
			if (!todos) this.createTableTodos();
			if (!ftPages) this.createTableFTPages();
			
			this.closeDatabaseSync();		
		}
				
		
		/**
		 *	All page names. Synchronous call. 
		 * @return  Page names as an array of strings
		 * 
		 */		
		public function get pages():Array
		{
			var res:SQLResult = this.doSQLSync("SELECT name FROM pages;");
			
			if (!res.data) return null;	
			var ret:Array = new Array();

			for each (var item:Object in res.data)
				ret.push(item.name);
			
			return ret;
		}
		
		public function get todos():Array
		{
			var res:SQLResult = this.doSQLSync("SELECT page, text as task, begin as due FROM todos;");
			return res.data;
		}
		
		
		public function getPagesFiltered(filter:String):Array
		{
			var res:SQLResult = this.doSQLSync("SELECT name FROM pages WHERE name LIKE '" + filter + "' ORDER BY name");

			if (!res.data) return null;	
			var ret:Array = new Array();

			for each (var item:Object in res.data)
				ret.push(item.name);
			
			return ret;
		}		
		
		
		
		public function get nonLinkedPages():Array
		{
			var res:SQLResult = this.doSQLSync("SELECT name FROM pages WHERE name NOT IN ( SELECT link FROM links );");

			if (!res.data) return null;	
			var ret:Array = new Array();

			for each (var item:Object in res.data)
				ret.push(item.name);
			
			return ret;
		}

		public function get nonLinkedPagesOrdered():Array
		{
/*
			SELECT pages.name, count(links.link) / count(links.link) as count
			  FROM pages
			LEFT OUTER JOIN links
			ON links.name = pages.name
			WHERE pages.name NOT IN (SELECT link FROM links)
			GROUP BY pages.name
			ORDER BY count DESC, pages.name ASC
*/			
			var res:SQLResult = this.doSQLSync("SELECT pages.name as name, count(links.link) / count(links.link) as count" + 
											   "  FROM pages" + 
											   "  LEFT OUTER JOIN links" + 
											   "    ON links.name = pages.name" + 
											   " WHERE pages.name NOT IN (SELECT link FROM links)" + 
											   " GROUP BY pages.name" + 
											   " ORDER BY count DESC, pages.name ASC;");

			if (!res.data) return null;	
			var ret:Array = new Array();

			for each (var item:Object in res.data)
				ret.push(item.name);
			
			return ret;
		}		
		
		/**
		 * Get all pages a given page links to. Synchronous call.
		 * @param page	The page we want the links for
		 * @return 		The links of the page as an array of Strings
		 * 
		 */		
		public function pageLinksForPage(page:String):Array
		{
			var res:SQLResult = this.doSQLSync("SELECT link FROM links WHERE name = '" + page + "' ORDER BY link;");
			
			if (!res.data) return null;
			var ret:Array = new Array;
			
			for each (var item:Object in res.data)
				ret.push(item.link)
				
			return ret;
		}

		/**
		 * Get all pages a given page links to. Synchronous call.
		 * @param page	The page we want the links for
		 * @return 		The links of the page as an array of Strings
		 * 
		 */		
		public function pageLinksForPageOrdered(page:String):Array
		{
			/*
				SELECT links1.link AS link, COUNT(links2.link) / COUNT(links2.link) as count
				FROM links AS links1
				LEFT OUTER JOIN links AS links2
				ON links2.name = links1.link
				WHERE links1.name = '4ECM'
				GROUP BY links1.link
				ORDER BY count DESC			
			*/
			
			var res:SQLResult = this.doSQLSync("SELECT links1.link AS link, COUNT(links2.link) / COUNT(links2.link) as count" + 
											   "  FROM links AS links1" + 
											   "  LEFT OUTER JOIN links AS links2" + 
											   "    ON links2.name = links1.link" + 
											   "  WHERE links1.name = '" + page + "'" + 
											   "  GROUP BY links1.link" + 
											   "  ORDER BY count DESC, links1.link ASC");			

			//var res:SQLResult = this.doSQLSync("SELECT link FROM links WHERE name = '" + page + "' ORDER BY link;");
			
			if (!res.data) return null;
			var ret:Array = new Array;
			
			for each (var item:Object in res.data)
				ret.push(item.link)
				
			return ret;
		}

		
		/**
		 * get all pages that link to the given page 
		 * @param page
		 * @return 
		 * 
		 */		
		public function linkedByPages(page:String):Array
		{
			var res:SQLResult = this.doSQLSync("SELECT name FROM links WHERE link = '" + page + "';");
			
			if (!res.data) return null;
			var ret:Array = new Array;
			
			for each (var item:Object in res.data)
				ret.push(item.name)
				
			return ret;			
		}
		
		
		
		
		public function storePageLinksAsync(name:String, links: Array):void
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
		
		/**
		 * Stores all wiki links in a string to the database. This is used for the page tree generation. 
		 * @param name		The name of the page to store the links for.
		 * @param links		An array of strings of wiki page links to store.
		 * 
		 */		
		private function storePageLinks(name:String, links: Array):void
		{
			trace("Store links for", name);
			this.begin();
			
			this.doSQLSync("DELETE FROM links WHERE name = '" + name + "';");
			var sqlStr: String = "";
			
			if (links)
			{
				for each (var link:String in links)
				{
					this.doSQLSync("INSERT INTO links (name, link) VALUES ('" + name + "', '" + link.substr(1, link.length - 2) + "');");
				}
			}
			
			this.commit();
		}
		
		
		public function storePageTodosAsync(name:String, todos:Array):void
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
		
		
		
		/**
		 * Stores the page into the pages table if it is not yet in it. 
		 * @param name
		 * 
		 */
		private function storePage(name:String):void
		{
			//this.begin();
			var dbRes:SQLResult = this.doSQLSync("SELECT name FROM pages WHERE name = '" + name + "';");
			if ((!dbRes) || (!dbRes.data))
				this.doSQLSync("INSERT INTO pages (name) VALUES ('" + name + "');");
			//this.commit();
		}
		

		
		/**
		 * Stores the page into the pages table if it is not yet in it. 
		 * @param name
		 * 
		 */
		public function storePageAsync(name:String):void
		{
			this.queueAsync("DELETE FROM pages WHERE name = '" + name + "';");
			this.queueAsync("INSERT INTO pages (name) VALUES ('" + name + "');");
		}
				
		
		
		/**
		 * Delete all page references from db. 
		 * @param page
		 * 
		 */		
		public function deletePage(page:String):void
		{
			this.doSQLSync("DELETE FROM pages WHERE name ='" + page + "';");
			this.doSQLSync("DELETE FROM links WHERE name = '" + page + "';");
			this.doSQLSync("DELETE FROM links WHERE link = '" + page + "';");
			this.doSQLSync("DELETE FROM todos WHERE page = '" + page + "';");			
			this.doSQLSync("DELETE FROM ftPages WHERE page = '" + page + "';");			
		}
		
		/**
		 * Rename page on db. 
		 * @param oldName
		 * @param newName
		 * 
		 */		
		public function renamePage(oldName:String, newName:String):Boolean
		{
			var dbRes:SQLResult = this.doSQLSync("SELECT name FROM pages WHERE name = '" + newName + "';");
			if ((dbRes) && (dbRes.data))
				if (dbRes.data.length)
				{
					MYMMessage.popUpToInform(Application.getInstance().appWindow, 
											 "Operation failed", MYMMessage.MessagePageExists, newName);
					return false;
				} 
			
			this.begin();
			// Rename in pages table
			this.doSQLSync("UPDATE pages SET name = '" + newName + "' WHERE name ='" + oldName + "';");
			
			// Rename in links table
			this.doSQLSync("UPDATE links SET name = '" + newName + "' WHERE name = '" + oldName + "';");
			this.doSQLSync("UPDATE links SET link = '" + newName + "' WHERE link = '" + oldName + "';");
		
			this.doSQLSync("UPDATE todos SET page = '" + newName + "' WHERE page = '" + oldName + "';");
			this.doSQLSync("UPDATE ftPages SET page = '" + newName + "' WHERE page = '" + oldName + "';");
			
			this.commit();
			
			return true;
		}
		
		
		public function storeFTAsync(page:String, text:String):void
		{
			text = text.replace(WikiDB.regFT, " ");									// Remove everything thats not a character or digit
			this.queueAsync("DELETE FROM ftPages WHERE page = '" + page + "';");
			this.queueAsync("INSERT INTO ftPages (page, words) VALUES ('" + page + "', '" + text + "');");			
		}
		
		
		private function storeFT(page:String, text:String):void
		{
			text = text.replace(WikiDB.regFT, " ");									// Remove everything thats not a character or digit
			this.begin();
			this.doSQLSync("DELETE FROM ftPages WHERE page = '" + page + "';");
			this.doSQLSync("INSERT INTO ftPages (page, words) VALUES ('" + page + "', '" + text + "');");
			this.commit();
		}
		
		public function searchFT(query:String):Array
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
						
			dbRes = this.doSQLSync("SELECT page, words FROM ftPages WHERE " + wClause + ";");
			if (dbRes) res = dbRes.data; else res = new Array();
			
			if (qWords.length > 1)
			{
				for each (w in qWords)
				{
					if (wClause != "") wClause += " OR ";
					wClause += "words LIKE '%" + Tools.stripWhiteSpace(w) + "%'";
				}
				
				for each (var p:Object in res)
				{
					if (notIn != "") notIn += ", ";
					notIn += "'" + p.page + "'";
				}
							
				dbRes = this.doSQLSync("SELECT page, words FROM ftPages WHERE ( " + wClause + " ) AND page NOT IN (" + notIn + ");");
				
				if (dbRes)
					res.concat(dbRes.data);
			}
			return res;
		}
	}
}