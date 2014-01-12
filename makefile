NAME=slack
VER=0.2.1
install=/usr/bin/install
SHELL=/bin/bash
DESTDIR=
BINDIR=/usr/bin
APPDIR=/usr/share/$(NAME)-$(VER)
MANDIR=/usr/man/man1

install: 
	$(install) -d $(DESTDIR)$(BINDIR)
	$(install) -d $(DESTDIR)$(APPDIR)
	$(install) -d $(DESTDIR)$(MANDIR)
	$(install) -m755 slack $(DESTDIR)$(BINDIR)
	$(install) -m644 README $(DESTDIR)$(APPDIR)
	$(install) -m644 COPYING $(DESTDIR)$(APPDIR)
	$(install) -m644 makefile $(DESTDIR)$(APPDIR)
	$(install) -m644 man/slack.1.gz $(DESTDIR)$(MANDIR)

remove: 
	rm $(DESTDIR)$(BINDIR)/$(NAME)
	rm $(DESTDIR)$(MANDIR)/$(NAME).1.gz
	rm -r $(DESTDIR)$(APPDIR)
	
