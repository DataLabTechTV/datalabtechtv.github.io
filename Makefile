all: build

build:
	hugo

dev:
	hugo server -DF -b http://localhost:1313

preview:
	hugo server -b http://localhost:1313

setup:
	git submodule update --init --recursive

deploy:
	git subtree push --prefix public/ origin gh-pages

clean:
	find -name "*.sav" -delete -or -name "*.bak" -delete
	find -name "*Zone.Identifier" -delete
