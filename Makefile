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

check-feature-images:
	@echo "==> Checking that all feature images are JPEG..."
	@find content/posts/ \
		-type f \
		-iname "feature*" ! -iname "feature*.jpeg" \
		-exec du -h {} \; | \
	grep . && \
	echo "❌ Found non-JPEG feature images" || \
	echo "✅ All feature images are JPEG"

	@echo "==> Checking that all feature images are smaller than 1 MiB..."
	@find content/posts/ \
		-type f \
		-iname "feature*" \
		-size +1M \
		-exec du -h {} \; | \
	grep . && \
	echo "❌ Found feature images larger than 1 MiB" || \
	echo "✅ All feature images are <= 1 MiB"


convert-feature-images:
	@echo "==> Converting all feature images to JPEG..."
	@find content/posts/ \
		-type f \
		-iname "feature*" ! -iname "feature*.jpeg" \
		-exec sh -c 'echo "    $$1"; convert "$$1" "$${1%.*}.jpeg"' _ {} \; \
		-delete && \
	echo "✅ All feature images were converted to JPEG" || \
	echo "❌ Could not convert non-JPEG feature images to JPEG"

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
	find public/ -mindepth 1 -not -name .gitkeep -delete
