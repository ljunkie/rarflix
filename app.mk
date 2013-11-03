#########################################################################
# common include file for application Makefiles
#
# Makefile Usage:
# > make
# > make install
# > make remove
#
# to exclude certain files from being added to the zipfile during packaging
# include a line like this:ZIP_EXCLUDE= -x keys\*
# that will exclude any file who's name begins with 'keys'
# to exclude using more than one pattern use additional '-x <pattern>' arguments
# ZIP_EXCLUDE= -x \*.pkg -x storeassets\*
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
PKGREL = ../packages
ZIPREL = ../zips
SOURCEREL = ..
FILE1 = PlexDev
FILE2 = RARflix
FILE3 = RARflixTest
FILE4 = RARflixDev
FILE5 = RARflixBeta

.PHONY: all $(APPNAME)

$(APPNAME): $(APPDEPS)
	@echo "*** Creating $(APPNAME).zip ***"

	@echo "  >> removing old application zip $(ZIPREL)/$(APPTITLE).zip"
	@if [ -e "$(ZIPREL)/$(APPTITLE).zip" ]; \
	then \
		rm  $(ZIPREL)/$(APPTITLE).zip; \
	fi

	@echo "  >> removing old application zip $(SOURCEREL)/$(APPNAME)/$(FILE1).zip"
	@if [ -e "$(SOURCEREL)/$(APPNAME)/$(FILE1).zip" ]; \
	then \
		rm  $(SOURCEREL)/$(APPNAME)/$(FILE1).zip; \
	fi
	@echo "  >> removing old application zip $(SOURCEREL)/$(APPNAME)/$(FILE2).zip"
	@if [ -e "$(SOURCEREL)/$(APPNAME)/$(FILE2).zip" ]; \
	then \
		rm  $(SOURCEREL)/$(APPNAME)/$(FILE2).zip; \
	fi
	@echo "  >> removing old application zip $(SOURCEREL)/$(APPNAME)/$(FILE3).zip"
	@if [ -e "$(SOURCEREL)/$(APPNAME)/$(FILE3).zip" ]; \
	then \
		rm  $(SOURCEREL)/$(APPNAME)/$(FILE3).zip; \
	fi
	@echo "  >> removing old application zip $(SOURCEREL)/$(APPNAME)/$(FILE4).zip"
	@if [ -e "$(SOURCEREL)/$(APPNAME)/$(FILE4).zip" ]; \
	then \
		rm  $(SOURCEREL)/$(APPNAME)/$(FILE4).zip; \
	fi
	@echo "  >> removing old application zip $(SOURCEREL)/$(APPNAME)/$(FILE5).zip"
	@if [ -e "$(SOURCEREL)/$(APPNAME)/$(FILE5).zip" ]; \
	then \
		rm  $(SOURCEREL)/$(APPNAME)/$(FILE5).zip; \
	fi

	@echo "  >> creating destination directory $(ZIPREL)"	
	@if [ ! -d $(ZIPREL) ]; \
	then \
		mkdir -p $(ZIPREL); \
	fi

	@echo "  >> setting directory permissions for $(ZIPREL)"
	@if [ ! -w $(ZIPREL) ]; \
	then \
		chmod 755 $(ZIPREL); \
	fi

# zip .png files without compression
# do not zip up Makefiles, or any files ending with '~'
	@echo "  >> creating application zip $(ZIPREL)/$(APPTITLE).zip"	
	@if [ -d $(SOURCEREL)/$(APPNAME) ]; \
	then \
		(zip -0 -r "$(ZIPREL)/$(APPTITLE).zip" . -i \*.png $(ZIP_EXCLUDE)); \
		(zip -9 -r "$(ZIPREL)/$(APPTITLE).zip" . -x \*~ -x \*.png -x Makefile $(ZIP_EXCLUDE)); \
	else \
		echo "Source for $(APPNAME) not found at $(SOURCEREL)/$(APPNAME)"; \
	fi

	@echo "*** developer zip  $(APPNAME) complete ***"

	cp "$(ZIPREL)/$(APPTITLE).zip" "$(ZIPREL)/$(APPTITLE)-$(VERSION).zip"
	cp "$(ZIPREL)/$(APPTITLE).zip" "../$(APPNAME)/$(APPTITLE).zip"

install: $(APPNAME)
	@echo "Installing $(APPNAME) to host $(ROKU_DEV_TARGET)"
	@curl -s -S -F "mysubmit=Install" -F "archive=@$(ZIPREL)/$(APPTITLE).zip" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//"

pkg: install
	@echo "*** Creating Package ***"

	@echo "  >> creating destination directory $(PKGREL)"	
	@if [ ! -d $(PKGREL) ]; \
	then \
		mkdir -p $(PKGREL); \
	fi

	@echo "  >> setting directory permissions for $(PKGREL)"
	@if [ ! -w $(PKGREL) ]; \
	then \
		chmod 755 $(PKGREL); \
	fi

	@echo "Packaging  $(APPNAME) on host $(ROKU_DEV_TARGET)"
	@read -p "Password: " REPLY ; echo $$REPLY | xargs -i curl -s -S -Fmysubmit=Package -Fapp_name=$(APPNAME)/$(VERSION) -Fpasswd={} -Fpkg_time=`expr \`date +%s\` \* 1000` "http://$(ROKU_DEV_TARGET)/plugin_package" | grep '^<font face=' | sed 's/.*href=\"\([^\"]*\)\".*/\1/' | sed 's#pkgs/##' | xargs -i curl -s -S -o $(PKGREL)/$(APPNAME)_{} http://$(ROKU_DEV_TARGET)/pkgs/{}

	@echo "*** Package  $(APPNAME) complete ***" 
remove:
	@echo "Removing $(APPNAME) from host $(ROKU_DEV_TARGET)"
	@curl -s -S -F "mysubmit=Delete" -F "archive=" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//"
