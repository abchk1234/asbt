NAME=slack
VER=0.3.1
install=/usr/bin/install
shell=/bin/bash
DESTDIR=
BINDIR=/usr/bin
APPDIR=/usr/share/$(NAME)-$(VER)
MANDIR=/usr/man/man1
CONDIR=/etc/slack

install: 
	$(install) -d $(DESTDIR)$(BINDIR)
	$(install) -d $(DESTDIR)$(APPDIR)
	$(install) -d $(DESTDIR)$(MANDIR)
	$(install) -d $(DESTDIR)$(CONDIR)
	$(install) -m755 src/slack $(DESTDIR)$(BINDIR)
	$(install) -m644 README $(DESTDIR)$(APPDIR)
	$(install) -m644 COPYING $(DESTDIR)$(APPDIR)
	$(install) -m644 AUTHORS $(DESTDIR)$(APPDIR)
	$(install) -m644 makefile $(DESTDIR)$(APPDIR)
	$(install) -m644 src/man/slack.1.gz $(DESTDIR)$(MANDIR)
	$(install) -m644 src/etc/slack.conf $(DESTDIR)$(CONDIR)

uninstall: 
	rm $(DESTDIR)$(BINDIR)/$(NAME)
	rm $(DESTDIR)$(MANDIR)/$(NAME).1.gz
	rm -r $(DESTDIR)$(CONDIR)
	rm -r $(DESTDIR)$(APPDIR)
	
