build: 
	bundle exec jekyll build
test:
	bundle exec htmlproofer ./_site
clean:
	bundle exec jekyll clean
serve:
	bundle exec jekyll serve --watch --drafts
