compile:
	for f in src/*.ligo; do docker run -v $(PWD):$(PWD) ligolang/ligo:next compile-contract $(PWD)/$$f main > $(PWD)/$${f%.ligo}.tz; done

test:
	pytest . -v

install:
    pytezos deploy src/atomex.tz --dry_run