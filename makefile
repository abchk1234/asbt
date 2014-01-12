NAME=slacker
VER=0.1
install=/usr/bin/install
SHELL=/bin/bash
DESTDIR=
BINDIR=/usr/bin
APPDIR=/usr/share/$(NAME)-$(VER)

install: 
	$(install) -d $(DESTDIR)$(BINDIR)
	$(install) -d $(DESTDIR)$(APPDIR)
	$(install) -m755 slacker $(DESTDIR)$(BINDIR)
	$(install) -m644 README $(DESTDIR)$(APPDIR)
	$(install) -m644 COPYING $(DESTDIR)$(APPDIR)
	$(install) -m644 makefile $(DESTDIR)$(APPDIR)

remove: slacker README COPYING makefile
	rm $(DESTDIR)$(BINDIR)/$(NAME)
	rm -r $(DESTDIR)$(APPDIR)

