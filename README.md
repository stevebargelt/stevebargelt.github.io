# stevebargelt.com

## Add a Blog post
From a command line, simply: 

~~~~
    
new_post "this is a new post title"
new_draft "this is a new post title"
publish_draft this-is-a-new-post.md

~~~~
[Source for scripts](https://github.com/stevebargelt/scripts/) 

The long way: 

1. Add a file in ~/code/stevebargelt.com/_posts or /_drafts
2. Naming - 
    * Post: date+title.md -- 2016-10-22-my-birthday.md
    * Draft: title.md -- this-is-a-draft-post.md
3. Add front matter:

    ~~~~
    ---
    layout: post
    title: My Health data
    subtitle: This is a subtitle
    portfolio: 
    image: 
    thumbimage:
    author: Steve Bargelt
    category: health
    tags: [weight,keto,"blood sugar",glucode,ketones,fat,fasting,fast]
    ---
    ~~~~

1. Write post using markdown
1. Follow republish site instructions below 

## Adding a Gallery

### In Lightroom 
1. Add a collection under !Portfolio
1. Add images to new portfolio
1. Create a cover image (1x1 ratio - eventually will be 400pxX400px)
1. Create a smart collection under the jf Collection Publisher "stevebargelt.com Portfolio"
    1. Collection contains 'Portfolio-NAME'
    1. Keywords doesn't contain "boudoir"
    1. Select: In it's own folder
    1. Select Sub-folder is named for the colelction given above
1. Add cover image to the !WEB - photography / Portfolio Covers 400x400 collection
1. Publish new (or All) jf Collection Publisher "stevebargelt.com Portfolio"
1. Publish the jf Collection Publisher "stevebargelt.com Portfolio Covers"

###In a text editor
1. Location ~/code/stevebargelt.com/_portfolio
1. Add .MD file corresponding to the portfolio named
1. Add front matter:

    ~~~~
    ---
    galleryorder: 1
    thumb_path: /img/portfolio/People400x400.jpg
    image_path: /img/portfolio/people/14.jpg
    title: People
    galleryname: People 
    description: I love to shoot people.
    ---
    ~~~~

I think the values are self-explainatory!

## Adding a banner image

### In Lightroom 

1. Add image(s) to !WEB - photography / Home Page Slider collection
1. Publish new (or All) jf Collection Publisher "stevebargelt.com Banners"

## Republish site
1. Command Line 

    ~~~~
    cd ~/code/stevebargelt.com/_portfolio
    bundle exec jekyll serve 
    ~~~~

2. Check out the site on http://localhost:4000
1. CTRL-C 

    ~~~~
    git add .
    git commit "Commit message"
    git push origin master 
    ~~~~

1. Changes will be pushed to http://test.stevebargelt.com automatically
1. Goto https://bargelt.visualstudio.com to push live

## Notes:

Cool Jekyll responsive sites:
https://phlow.github.io/feeling-responsive/

https://github.com/johnotander/pixyll
http://pixyll.com


