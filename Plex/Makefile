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
APPDEPS = manifest count_functions
ZIP_EXCLUDE = -x .git\* -x manifest.template -x \*.swp -x \*.DS_Store -x \*.py -x roku_screenshot.jpg
include ../app.mk

APPTITLE = PlexDev

num_functions := $(shell grep -ri --include=*.brs 'end \(function\|sub\)' . | wc -l | tr -d ' ')

.PHONY: manifest count_functions beta dev rel test rarflix

beta: APPTITLE = PlexBeta
beta: $(APPNAME)

test: APPTITLE = PlexTest
test: $(APPNAME)

dev: APPTITLE = PlexDev
dev: $(APPNAME)

rel: APPTITLE = Plex
rel: $(APPNAME)

rarflix: APPTITLE = RARflix
rarflix: $(APPNAME)

manifest:
	echo "Creating manifest for $(APPTITLE)"
	sed s/APPTITLE/$(APPTITLE)/ < manifest.template > manifest
#	sed s/APPTITLE/$(APPTITLE)/ < manifest.rarflix.template > manifest

count_functions:
	echo "Counting functions for $(APPTITLE), Roku v3.x limit is 512"
	test $(num_functions) -le 512

screenshot:
	$(CURL) -s -F passwd= -F mysubmit=Screenshot -F "archive=;filename=" -H "Expect:" "http://$(ROKU_DEV_TARGET)/plugin_inspect" > /dev/null
	$(CURL) -s "http://$(ROKU_DEV_TARGET)/pkgs/dev.jpg" > roku_screenshot.jpg

all: $(APPNAME)
