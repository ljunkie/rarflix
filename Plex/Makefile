#########################################################################
# Simple makefile for packaging Roku Simple Video Player example
#
# Makefile Usage:
# > make
# > make install
# > make remove
#
# Important Notes: 
# To use the "install" and "remove" targets to install your
# application directly from the shell, you must do the following:
#
# 1) Make sure that you have the curl command line executable in your path
# 2) Set the variable ROKU_DEV_TARGET in your environment to the IP 
#    address of your Roku box. (e.g. export ROKU_DEV_TARGET=192.168.1.1.
#    Set in your this variable in your shell startup (e.g. .bashrc)
##########################################################################  
APPNAME = Plex
APPDEPS = manifest
ZIP_EXCLUDE = -x .git\* -x manifest.template -x \*.swp -x \*.DS_Store -x \*.py
include ../app.mk

APPTITLE = PlexDev

.PHONY: manifest beta dev rel test

beta: APPTITLE = PlexBeta
beta: $(APPNAME)

test: APPTITLE = PlexTest
test: $(APPNAME)

dev: APPTITLE = PlexDev
dev: $(APPNAME)

rel: APPTITLE = Plex
rel: $(APPNAME)

manifest:
	echo "Creating manifest for $(APPTITLE)"
	sed s/APPTITLE/$(APPTITLE)/ < manifest.template > manifest

screenshot:
	curl -s -F passwd= -F mysubmit=Screenshot -F "archive=;filename=" -H "Expect:" "http://$(ROKU_DEV_TARGET)/plugin_inspect" > /dev/null
	curl -s "http://$(ROKU_DEV_TARGET)/pkgs/dev.jpg" > roku_screenshot.jpg

download: $(APPNAME)
	echo "Uploading latest package to GitHub"
	./create_github_download.py $(ZIPREL)/$(APPNAME).zip

all: $(APPNAME)
