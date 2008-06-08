#Copyright Jon Berg , turtlemeat.com

import string
import urllib
import os
from os import system, sys, path
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer


class MyHandler(BaseHTTPRequestHandler):

	def do_GET(self):
		print self.path
		try:
			if self.path[:16] == "/helper.sts.org/":
				
				self.path = self.path[16:]
				self.path = self.path.replace("/", path.sep);
				if sys.platform == "win32":
                                        r = os.startfile(urllib.unquote(self.path))
                                else:
                                        r = system('/usr/bin/open "%s"' % urllib.unquote(self.path))
				self.send_response(200)
				self.send_header('Content-type',	'text/html')
				self.end_headers()
				
                
		except IOError:
			self.send_error(404,'File Not Found: %s' % self.path)
		

def main():
	try:
		server = HTTPServer(('', 8080), MyHandler)
		print 'started httpserver...'
		server.serve_forever()
	except KeyboardInterrupt:
		print '^C received, shutting down server'
		server.socket.close()

if __name__ == '__main__':
	main()

