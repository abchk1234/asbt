NAME=slack
VER=0.2
install=/usr/bin/install
SHELL=/bin/bash
DESTDIR=
BINDIR=/usr/bin
APPDIR=/usr/share/$(NAME)-$(VER)

install: 
	$(install) -d $(DESTDIR)$(BINDIR)
	$(install) -d $(DESTDIR)$(APPDIR)
	$(install) -m755 slack $(DESTDIR)$(BINDIR)
	$(install) -m644 README $(DESTDIR)$(APPDIR)
	$(install) -m644 COPYING $(DESTDIR)$(APPDIR)
	$(install) -m644 makefile $(DESTDIR)$(APPDIR)

remove: 
	rm $(DESTDIR)$(BINDIR)/$(NAME)
	rm -r $(DESTDIR)$(APPDIR)

