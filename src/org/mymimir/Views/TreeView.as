package org.mymimir.Views
{
	import flash.events.DataEvent;
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	import mx.controls.Tree;
	import mx.events.TreeEvent;
	
	import org.mymimir.sdk.Events;
	import org.mymimir.sdk.IWiki;
	import org.mymimir.sdk.Protocols;
	import org.mymimir.sdk.Views.MYMView;

	
	public class TreeView extends org.mymimir.sdk.Views.MYMView
	{
		private var _tree:Tree;
		private var _pageTree:XML;
		private var _pages:Array;
		private var _pageLinks:Object;
		
		
		
		public function TreeView(description:XML)
		{
			super(description);
			
			this._protocols = [org.mymimir.sdk.Protocols.WikiPageProtocol];
			this._tree = new Tree;
			this.setWidthHeight(this._tree);
			this._tree.labelField = "@label";
			this.addChild(this._tree);
		}
		
		override public function set wiki(value:IWiki):void
		{
			this._wiki = value;
			
			this._wiki.addEventListener(org.mymimir.sdk.Events.WIKI_CHANGED, onWikiChanged);
			this.updatePageTree();
			this._tree.addEventListener(MouseEvent.CLICK, onTreeClick);
			this._tree.addEventListener(TreeEvent.ITEM_OPEN, onTreeOpen);
			this._tree.addEventListener(TreeEvent.ITEM_CLOSE, onTreeClose);
		}
		
		
		private function onWikiChanged(ev:Event):void
		{
			this.updatePageTree();
		}
		
		
		private function onTreeOpen(ev:TreeEvent):void
		{
			var selectedNode:XML = ev.item as XML;
			selectedNode.@byUser = "1";
		}
		
		private function onTreeClose(ev:TreeEvent):void
		{
			var selectedNode:XML = ev.item as XML;
			selectedNode.@byUser = "0";
		}
		
		
		/**
		 * 
		 * @param ev
		 * 
		 */
		private function onTreeClick(ev:Event):void
		{
			var selectedNode:XML = Tree(ev.currentTarget).selectedItem as XML;								// Get clicked node as XML
			if (selectedNode.@root != "1")
				this.dispatchEvent(new DataEvent(org.mymimir.sdk.Events.VIEW_LOCATION_CHANGE, false, false, 
												 org.mymimir.sdk.Protocols.WikiPageProtocol + selectedNode.@label));
		}


		override public function handleLocation(location:String):Boolean
		{
			if (!this._wiki) return false;
			if (!this._pageTree) return false;
			
			var xl:XMLList = this._pageTree..node.(@expanded == "1");							// Get all expanded tree items
			var x:XML;
			for each (x in xl)																	// We'll close all that were not opened by the user
			{
				if (x.@byUser == "1") continue;
				this._tree.expandItem(x, false);
				x.@expanded = "0";
			}
			
			var t:XML
			if (x)
				t = x..node.(@label == this._wiki.currentPage.name)[0];						// Get tree item that was selected as child of the last opened item
			
			if ((!x) || (!t))																// ... if that didn't work...
				t = this._pageTree..node.(@label == this._wiki.currentPage.name)[0];	// Get tree item that was selected
				
			if (t)
			{
				var p:XML = t;
				while (p)																					// Open all parents
				{
					if (p.@expanded == "0")
					{
						this._tree.expandItem(p, true);
						p.@expanded = "1";
						if (p.@byUser != "1") p.@byUser = "0";
					}
					p = p.parent() as XML;
				}
				this._tree.selectedItem = t;																// select the item				
			}			
			
			return true;
		}
		
		
		
		
		private function cbUpdatePageTreeNonLinkedGot(success:Boolean, pages:Array, ... args):void
		{
			if (!pages) _pages = new Array();
				else this._pages = pages;
			if (_pageLinks) this.doPageTreeUpdate();
		}

		private function cbUpdatePageTreeLinksGot(success:Boolean, pageLinks:Object, ... args):void
		{
			if (!pageLinks) _pageLinks = new Object();
				else this._pageLinks = pageLinks;
			if (_pages) this.doPageTreeUpdate();
		}

		
		/**
		 * Update the page tree. Uses the link information in the DB to add/move/remove nodes in the tree. 
		 * 
		 */		
		private function updatePageTree():void
		{
			this._wiki.backend.getNotLinkedPages(this.cbUpdatePageTreeNonLinkedGot);
			this._wiki.backend.getAllPageLinks(this.cbUpdatePageTreeLinksGot);
		}


		private function doPageTreeUpdate():void
		{
			if (!this._pageTree) this._pageTree = <pageTree />; 
			
			var visited:Array = new Array;								// An array to store all pages we've already processed
			var lVisited:Array = new Array;
			if (!_pages) _pages = new Array();
			_pages = _pages.reverse();
			_pages.push(this._wiki.firstPage);
			_pages.reverse();			
			
			var nodes:XMLList = this._pageTree.node;		
			var test:XMLList;
			
			for each (var page:String in _pages)
			{
				if (visited.indexOf(page) != -1) continue;
				test = this._pageTree.node.(@label == page);
				if (!test.length())
				{
					var newNode:XML = this.createNodeForPage(page);
					if (!visited.length) 
						newNode.@expanded = "1";
					this._pageTree.appendChild(newNode); 
				}
				
				this.updatePageTreeRec(this._pageTree.node.(@label == page)[0], lVisited, visited);
			}
			
			
			var level1:XMLList = this._pageTree.node;
			
 			for each (var l:XML in level1)
			{
				var ln:String = new String(l.@label);
				if (_pages.indexOf(ln) == -1)
					delete this._pageTree.node.(@label == ln)[0];
			}

			level1 = this._pageTree.node;
			if (level1.length())
				level1[0].@expanded = "1";	
				
			if (!this._tree.dataProvider)
			{
				this._tree.dataProvider = this._pageTree.node;
			}				
			this._pages = null;
			this._pageLinks = null;
		}

		
		/**
		 * Create a new node for a page. 
		 * @param page	The page.
		 * @return 		Node as an XML &lt;node label="..." expanded="0" /&gt;
		 * 
		 */		
		private function createNodeForPage(page:String):XML
		{
			var node:XML = new XML("<node />");
			node.@label = page;
			node.@expanded = "0";
			node.@root = "0";
			
			return node;
		}
		

		/**
		 * Recursive function for page tree update. 
		 * @param node			Node to be processed
		 * @param visited		Already visited nodes in current branch. To avoid infinite loops
		 * @param visitedGlob	Already visited loops overall. To put pages on top level that are not linked to anywhere.
		 * 
		 */				
		private function updatePageTreeRec(node:XML, visited:Array, visitedGlob:Array):void
		{			
			if (!node) return;											// If no node given do nothing
			var page:String = new String(node.@label);
			if (!page) return;											// If no page name do nothing
						
			var lVisited:Array = new Array;								// A locally visited to store this branches visited pages
			visited.push(String(node.@label));								// Add currently processed page to visited 
			visitedGlob.push(String(node.@label));							// ... and the overall visited
			for each (var item:String in visited) lVisited.push(item);	// Copy all previously visited to this subbranches visited
			
			var pageLinks:Array = this._pageLinks[page];		// Get all page links for this node
			var test:XMLList;
			
			for each (var link:String in pageLinks)						// For each pagelink
			{
				if (lVisited.indexOf(link) >= 0) continue;				// If already visited: Ignore
				test = node.node.(@label == link);
				if (!test.length())										// If it is a new link
					node.appendChild(this.createNodeForPage(link));		// Add as new child
			}	
			
			var child:XML;
			var children:XMLList = node.children();						// Store children
			for each (child in children)								// For all saved children
			{
				if ((!pageLinks) ||  (pageLinks.indexOf(String(child.@label)) == -1))				// If it is not a link in the page anymore
					delete node.node.(@label == child.@label)[0];
			}
			children = node.children();									// Update tree for all sublinks
			for each (child in children)
				updatePageTreeRec(child, lVisited, visitedGlob);
		}

				
		
	}
}