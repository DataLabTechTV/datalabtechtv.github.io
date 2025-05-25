all: build

build:
	hugo --minify

dev:
	hugo server -DF -b http://localhost:1313

future:
	hugo server -F -b http://localhost:1313

preview:
	hugo server -b http://localhost:1313

setup:
	git submodule update --init --recursive

deploy: build
	cd public && \
	rm -rf .git && \
	git init -b main && \
	git config core.sshCommand "ssh -i ~/.ssh/datalabtech" && \
	git config user.name "Data Lab Tech" && \
	git config user.email "204358040+DataLabTechTV@users.noreply.github.com" && \
	git add . && \
	git commit -m "chore: local build deployment" && \
	git remote add origin git@github.com:DataLabTechTV/datalabtechtv.github.io.git && \
	git push --force origin main:gh-pages

clean:
	find -name "*.sav" -delete -or -name "*.bak" -delete
	find -name "*Zone.Identifier" -delete
