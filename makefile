build: 
	bundle exec jekyll build
test:
	bundle exec htmlproofer ./_site --file-ignore "./_site/WHO_CHO_CVD.html" --http-status-ignore "999"
clean:
	bundle exec jekyll clean
serve-prod:
	bundle exec jekyll serve --watch
serve:
	bundle exec jekyll serve --watch --drafts
