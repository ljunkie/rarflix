#!/usr/bin/env python

# Depends on both PyGithub and Poster

import getpass
import os
import sys
import urllib2

from github import Github
from poster.encode import multipart_encode
from poster.streaminghttp import register_openers

register_openers()

if len(sys.argv) > 1:
    path = sys.argv[1]
else:
    path = "../zips/Plex.zip"

print "Uploading %s to GitHub downloads..." % path

username = raw_input('GitHub username: ')
password = getpass.getpass()

g = Github(username, password)
repo = g.get_organization('plexinc').get_repo('roku-client-public')

name = os.path.split(path)[1]
size = os.path.getsize(path)

# There doesn't seem to be a way to update an existing download, so we have
# to delete the existing one first.

for dl in repo.get_downloads():
    if dl.name == name:
        dl.delete()

download = repo.create_download(name, size, 'Latest package for dev mode', 'application/zip')

# The order of these parameters matters!

params = []
params.append(('key', download.path))
params.append(('acl', download.acl))
params.append(('success_action_status', '201'))
params.append(('Filename', download.name))
params.append(('AWSAccessKeyId', download.accesskeyid))
params.append(('Policy', download.policy))
params.append(('Signature', download.signature))
params.append(('Content-Type', download.mime_type))
params.append(('file', open(path, 'rb')))

datagen, headers = multipart_encode(params)
request = urllib2.Request("https://github.s3.amazonaws.com/", datagen, headers)

urllib2.urlopen(request)

print "Successfully created download"
