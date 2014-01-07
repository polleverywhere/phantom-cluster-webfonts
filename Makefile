all: deps build

deps:
	npm install

build:
	node ./node_modules/coffee-script/bin/coffee --compile *.coffee

example: build
	node example.js
