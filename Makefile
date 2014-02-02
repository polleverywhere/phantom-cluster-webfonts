all: deps build test

deps:
	npm install

build:
	node ./node_modules/coffee-script/bin/coffee --compile *.coffee

example: build
	node example.js

test: build
	./node_modules/nodeunit/bin/nodeunit test.js
