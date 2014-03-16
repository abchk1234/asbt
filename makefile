NAME=asbt
VER=0.8.6
install=/usr/bin/install
rm=/usr/bin/rm
shell=/bin/bash
DESTDIR=
BINDIR=/usr/bin
DOCDIR=/usr/doc/$(NAME)-$(VER)
MANDIR=/usr/man/man1
SETDIR=/etc/asbt

install: 
	$(install) -d $(DESTDIR)$(BINDIR)
	$(install) -d $(DESTDIR)$(DOCDIR)
	$(install) -d $(DESTDIR)$(MANDIR)
	$(install) -d $(DESTDIR)$(SETDIR)
	$(install) -m755 src/asbt $(DESTDIR)$(BINDIR)
	$(install) -m644 README $(DESTDIR)$(DOCDIR)
	$(install) -m644 COPYING $(DESTDIR)$(DOCDIR)
	$(install) -m644 AUTHORS $(DESTDIR)$(DOCDIR)
	$(install) -m644 Changelog $(DESTDIR)$(DOCDIR)
	$(install) -m644 makefile $(DESTDIR)$(DOCDIR)
	$(install) -m644 man/asbt.1 $(DESTDIR)$(MANDIR)
	$(install) -m644 etc/asbt.conf $(DESTDIR)$(SETDIR)

uninstall: 
	$(rm) $(DESTDIR)$(BINDIR)/$(NAME)
	$(rm) $(DESTDIR)$(MANDIR)/$(NAME).1.gz
	$(rm) -r $(DESTDIR)$(SETDIR)
	$(rm) -r $(DESTDIR)$(DOCDIR)
