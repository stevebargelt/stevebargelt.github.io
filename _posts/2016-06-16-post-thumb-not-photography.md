---
layout: post
title: Regular Blog Post
subtitle: Thumbnail not huge
portfolio: 
thumbimage: http://placehold.it/400x200
author: Steve Bargelt
category: software
tags: [code,programming,markdown,c#]
---

A regular blog post (non photography related)

So this should have a thumb pic at 400x200 but not responsive - not photography post.

```c#
// some c# code
var a = "bad variable name"
```

```ruby
require 'redcarpet'
markdown = Redcarpet.new("Hello World!")
puts markdown.to_html
```

{% highlight ruby linenos %}
def show
  puts "Outputting a very lo-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-ong lo-o-o-o-o-o-o-o-o-o-o-o-o-o-o-o-ong line this is a very long line that will wrap if your screen isn't very very large...maybe one of those crazy wide-as-hell LG dispalys? Interesting"
  @widget = Widget(params[:id])
  respond_to do |format|
    format.html # show.html.erb
    format.json { render json: @widget }
  end
end
{% endhighlight %}


**Bold** text
