PREFIX := /usr/local

all:

install:
	install -d $(DESTDIR)/etc/cron.d
	install -d $(DESTDIR)/etc/cron.daily
	install -d $(DESTDIR)/etc/cron.hourly
	install -d $(DESTDIR)/etc/cron.weekly
	install -d $(DESTDIR)/etc/cron.monthly
	install -m 0644 etc/btrfs-auto-snapshot.cron.frequent $(DESTDIR)/etc/cron.d/btrfs-auto-snapshot
	install etc/btrfs-auto-snapshot.cron.hourly   $(DESTDIR)/etc/cron.hourly/btrfs-auto-snapshot
	install etc/btrfs-auto-snapshot.cron.daily    $(DESTDIR)/etc/cron.daily/btrfs-auto-snapshot
	install etc/btrfs-auto-snapshot.cron.weekly   $(DESTDIR)/etc/cron.weekly/btrfs-auto-snapshot
	install etc/btrfs-auto-snapshot.cron.monthly  $(DESTDIR)/etc/cron.monthly/btrfs-auto-snapshot
	install -d $(DESTDIR)$(PREFIX)/share/man/man8
	install -m 0644 src/btrfs-auto-snapshot.8 $(DESTDIR)$(PREFIX)/share/man/man8/btrfs-auto-snapshot.8
	install -d $(DESTDIR)$(PREFIX)/sbin
	install src/btrfs-auto-snapshot.sh $(DESTDIR)$(PREFIX)/sbin/btrfs-auto-snapshot
	install src/_btrfs_zfs.sh $(DESTDIR)$(PREFIX)/sbin/_btrfs_zfs # TODO libexec?

uninstall:
	rm $(DESTDIR)/etc/cron.d/btrfs-auto-snapshot
	rm $(DESTDIR)/etc/cron.hourly/btrfs-auto-snapshot
	rm $(DESTDIR)/etc/cron.daily/btrfs-auto-snapshot
	rm $(DESTDIR)/etc/cron.weekly/btrfs-auto-snapshot
	rm $(DESTDIR)/etc/cron.monthly/btrfs-auto-snapshot
	rm $(DESTDIR)$(PREFIX)/share/man/man8/btrfs-auto-snapshot.8
	rm $(DESTDIR)$(PREFIX)/sbin/btrfs-auto-snapshot
	rm $(DESTDIR)$(PREFIX)/sbin/_btrfs_zfs
