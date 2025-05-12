all: build

build:
	hugo

dev:
	hugo server -D -b localhost:1313

setup:
	git submodule update --init --recursive

deploy: build
	git subtree push --prefix public/ origin gh-pages

clean:
	find -name "*.sav" -delete -or -name "*.bak" -delete
	find -name "*Zone.Identifier" -delete
