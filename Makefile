all: build test

deps:
	npm install

build:
	node ./node_modules/coffee-script/bin/coffee --compile *.coffee

test: build
	node ./node_modules/nodeunit/bin/nodeunit test.js

example: build
	node example.js

sandbox: build
	node sandbox.js
