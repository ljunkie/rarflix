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
APPNAME = RARflix
APPDEPS = manifest count_functions
ZIP_EXCLUDE = -x .git\* -x manifest.template -x \*.swp -x \*.DS_Store -x \*.py -x roku_screenshot.jpg
include ../app.mk

APPTITLE = RARflix
APPTEMPLATE = manifest.rarflix.template
VERSION=$(shell grep '^version' $(APPTEMPLATE) | sed s/version=//)

num_functions := $(shell grep -ri --include=*.brs 'end \(function\|sub\)' . | wc -l | tr -d ' ')

.PHONY: manifest count_functions beta dev rel test rarflix


beta: APPTITLE = RARflixBeta
beta: $(APPNAME)
beta: VERSION=$(shell grep '^version' $(APPTEMPLATE) | sed s/version=//)

test: APPTITLE = RARflixTest
test: $(APPNAME)
test: VERSION=$(shell grep '^version' $(APPTEMPLATE) | sed s/version=//)

dev: APPTITLE = RARflixDev
dev: APPTEMPLATE = manifest.rarflixDEV.template
dev: $(APPNAME)
dev: VERSION=$(shell grep '^version' $(APPTEMPLATE) | sed s/version=//)

rel: APPTITLE = RARflix
rel: $(APPNAME)

rarflix: APPTITLE = RARflix
rarflix: $(APPNAME)


manifest:
	echo "Creating manifest for $(APPTITLE)"
	sed s/APPTITLE/$(APPTITLE)/ < $(APPTEMPLATE) > manifest
	echo sed s/APPTITLE/$(APPTITLE)/ < $(APPTEMPLATE)

count_functions:
	echo "Counting functions for $(APPTITLE), Roku v5.x limit is 65536"
	test $(num_functions) -le 65536

screenshot:
	curl -s -F passwd= -F mysubmit=Screenshot -F "archive=;filename=" -H "Expect:" "http://$(ROKU_DEV_TARGET)/plugin_inspect" > /dev/null
	curl -s "http://$(ROKU_DEV_TARGET)/pkgs/dev.jpg" > roku_screenshot.jpg

download: $(APPNAME)
	echo "Uploading latest package to GitHub"
	./create_github_download.py $(ZIPREL)/$(APPNAME).zip

all: $(APPNAME)
