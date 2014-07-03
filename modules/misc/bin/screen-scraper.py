#!/usr/bin/env python

# Screen scraping script

# Requires INI file with the following format:
#
# [source]
# # Root URL from which data is taken
# url = http://somewhere.com
#
# [output]
# dir = output
#
# # Optional section specifying URL roots from which pages should be pulled
# # (by default all external links are skipped).  Note that the search does
# # not recurse into these links.
# [external]
# some_label = http://some_external_site.com
#
# [options]
# # Optional values - specify number of seconds to wait.  The actual wait
# # will be a number of seconds between these two limits.
# wait_min = 5
# wait_max = 10


#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

from __future__ import print_function

from BeautifulSoup import BeautifulSoup
import re
import urllib
import urllib2
from urlparse import *
import os.path
import sys
import ConfigParser
import random
import time


#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

# Enumerated values for return from Visit function
VISIT_SKIP = 'skip'
VISIT_RESOURCE = 'resource'
VISIT_RECURSE = 'recurse'
VISIT_VISITED = 'visited'


#------------------------------------------------------------------------------
# Global variables
#------------------------------------------------------------------------------

DEPTH = 0
VISITED = {}
CONFIG = {}


#------------------------------------------------------------------------------
# Subroutines
#------------------------------------------------------------------------------

def PrintUsage():
	print("Usage: " + sys.argv[0]  + " <ini_file>")


def ExtractRequiredIniField(config, section, field, target):
	if config.has_option(section, field) != True:
		raise IOError("Required field '" + field + "' in section '" + section + "' not found in config file")
	CONFIG[target] = config.get(section, field)


def ExtractOptionalIniFieldInt(config, section, field, target):
	if config.has_option(section, field):
		CONFIG[target] = int(config.get(section, field))


def ParseIniFile(fileName):
	config = ConfigParser.RawConfigParser()
	if len(config.read(fileName)) == 0:
		raise IOError("Failed to read config file " + fileName)
	ExtractRequiredIniField(config, 'source', 'url', 'source_url')
	ExtractRequiredIniField(config, 'output', 'dir', 'output_dir')

	CONFIG['external_urls'] = []
	if config.has_section('external'):
		for key in config.options('external'):
			print("EXTERNAL " + config.get('external', key))
			CONFIG['external_urls'].append(config.get('external', key))

	CONFIG['options_wait_min'] = 0
	ExtractOptionalIniFieldInt(config, 'options', 'wait_min', 'options_wait_min')

	CONFIG['options_wait_max'] = 0
	ExtractOptionalIniFieldInt(config, 'options', 'wait_max', 'options_wait_max')

	if CONFIG['options_wait_max'] < CONFIG['options_wait_min']:
		CONFIG['options_wait_max'] = CONFIG['options_wait_min']

	CONFIG['options_depth_max'] = 0
	ExtractOptionalIniFieldInt(config, 'options', 'depth_max', 'options_depth_max')


def ProcessCommandLine():
	if len(sys.argv) < 2:
		PrintUsage()
		raise IOError("Invalid command line arguments")
	ParseIniFile(sys.argv[1])


def AbsoluteUrl(currentUrl, targetUrl):
	absoluteUrl = urljoin(currentUrl, targetUrl)
	return absoluteUrl


def Visit(url):
	# Check if this URL has already been visited
	for key in VISITED.keys():
		if key == url:
			print("Already visited: " + url)
			return VISIT_VISITED

	# Check whether this URL is below the list of external links
	# which should be treated as resources
	for externalUrl in CONFIG['external_urls']:
		index = url.find(externalUrl)
		if index == 0:
			print("Allowing external URL: " + url)
			return VISIT_RESOURCE

	# Check whether this URL is below the root
	index = url.find(CONFIG['source_url'])
	if index != 0:
		print("Skipping external URL: " + url)
		return VISIT_SKIP

	return VISIT_RECURSE


def TargetPath(url):
	targetPath = ''

	index = url.find(CONFIG['source_url'])
	if index == 0:
		targetPath = url
		targetPath = targetPath.replace(CONFIG['source_url'], '')

	if targetPath == '':
		targetPath = 'index.html'

	regex = re.compile('\.\w+\z')
	if regex.match(targetPath) == None:
		targetPath += '.html'

	return targetPath


def ProcessResource(url):

	for key in VISITED.keys():
		if key == url:
			return VISITED[url]

	print("ProcessResource " + url)

	o = urlparse(url)
	path = o.path
	regex = re.compile('.*\/')
	fileNameRoot = regex.sub('', path)

	fileName = fileNameRoot
	targetFileName = ''

	# Ensure that fileName is unique
	index = 0
	while True:
		targetFileName = CONFIG['output_dir'] + '/' + fileName
		if os.path.exists(targetFileName) != True:
			break
		fileName = "%d_%s" % (++index, fileNameRoot)

	urllib.urlretrieve(url, targetFileName)

	print("Stored mapping " + url + " to " + fileName)
	VISITED[url] = fileName

	return fileName


def ProcessLink(targetUrl):
	# Remove anchor from end of URL before checking whether to
	# follow the link
	regex = re.compile('#.*')
	trimmedUrl = regex.sub('', targetUrl)
	regex = re.compile('\?.*')
	trimmedUrl = regex.sub('', targetUrl)

	print("ProcessLink " + targetUrl)
	visit = Visit(trimmedUrl)

	if visit == VISIT_RECURSE:
		if CONFIG['options_depth_max'] == 0 or DEPTH < CONFIG['options_depth_max']:
			return ProcessUrl(trimmedUrl)
		else:
			print("Already at depth " + DEPTH + " - terminating recursion")
			return targetUrl
	if visit == VISIT_RESOURCE:
		return ProcessResource(trimmedUrl)
	elif visit == VISIT_VISITED:
		return VISITED[trimmedUrl]
	else:
		# External URL - leave unchanged
		return targetUrl


def Wait():
	interval = random.randint(CONFIG['options_wait_min'], CONFIG['options_wait_max'])
	print("Waiting for " + str(interval) + " sec ...")
	time.sleep(interval)


def ProcessUrl(url):
	regex = re.compile('#.*')
	trimmedUrl = regex.sub('', url)
	regex = re.compile('\?.*')
	trimmedUrl = regex.sub('', url)

	fileName = ''

	global DEPTH
	DEPTH += 1

	msg = "\nProcessUrl [%2d] %s" % (DEPTH, url)
	print(msg)

	fileName = TargetPath(url)

	# Mark URL as having been visited
	print("Stored mapping " + trimmedUrl + " to " + fileName)
	VISITED[trimmedUrl] = fileName

	try:
		# Retrieve and parse HTML
		response = urllib2.urlopen(url)
		html = response.read()
		Wait()
		soup = BeautifulSoup(html)

		# Retrieve all images
		images = soup.findAll('img', src=True)
		for image in images:
			imageUrl = AbsoluteUrl(url, image['src'])
			image['src'] = ProcessResource(imageUrl)

		# Retrieve all CSS files
		stylesheets = soup.findAll('link', type='text/css')
		for stylesheet in stylesheets:
			stylesheetUrl = AbsoluteUrl(url, stylesheet['href'])
			stylesheet['href'] = ProcessResource(stylesheetUrl)

		# Retrieve all script files
		scripts = soup.findAll('script', src=True)
		for script in scripts:
			scriptUrl = AbsoluteUrl(url, script['src'])
			script['src'] = ProcessResource(scriptUrl)

		# Recursively traverse all links
		links = soup.findAll('a', href=True)
		for link in links:
			linkUrl = AbsoluteUrl(url, link['href'])
			link['href'] = ProcessLink(linkUrl)
			print("Link in " + url + " (" + fileName + ") remapped from " + linkUrl + " to " + link['href'])

		# Write page to local file
		print("Writing " + url + " to " + fileName)
		file = open(CONFIG['output_dir'] + '/' + fileName, 'w')
		print(soup, file=file)

	except:
		print("Error occurred retrieving " + url)

	DEPTH -= 1

	return fileName

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

ProcessCommandLine()
ProcessUrl(CONFIG['source_url'])

