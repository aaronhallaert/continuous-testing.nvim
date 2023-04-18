test:
	nvim --headless -u lua/spec/minimal_init.lua -c "PlenaryBustedDirectory lua/spec { minimal_init = './lua/spec/minimal_init.lua', sequential = true }" -c qa
ci:
	nvim --headless -u lua/spec/minimal_init.lua -c "TSUpdateSync javascript ruby" -c qa && make test
