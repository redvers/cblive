rpm:
#	find . -name rel -exec rm -rf {} \;
	MIX_ENV=prod mix release.clean
	MIX_ENV=prod mix release --verbosity=verbose
	echo apps/cblmaster/rel/cblmaster/releases/0.0.1/cblmaster.tar.gz

distclean:
	find apps -name 'rel' -exec rm -rf {} \;
	find apps -name '_build' -exec rm -rf {} \;
