test:
	nvim --headless --noplugin -u lua/spec/minimal_init.vim -c "PlenaryBustedDirectory lua/spec { minimal_init = './lua/spec/minimal_init.vim' }"
ci:
	nvim --noplugin -u lua/spec/minimal_init.vim -c "TSUpdateSync javascript ruby" -c qa && make test
