# columnflow

(WIP) Quarto extension to add auto flowing columns work in Word (and potentially other formats). Potential inspo from https://github.com/jdutant/columns/blob/master/columns.lua too!

## Install

Quarto users ought to be able to install this as an extension:

```
quarto install extension jimjam-slam/columnflow
```

Then add the filter to your document's frontmatter:

````
---
title: My Environments Document
format: docx
filters:
  - columnflow
---
````

## Use

Surround a block with the `.columnflow` class to divide it into columns!

In Markdown:

````md
``` {.columnflow}
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam tempor
aliquam augue, eleifend eleifend eros placerat ac. Aenean in dignissim
dolor. Aliquam vitae turpis nulla. Aliquam erat volutpat. Nulla auctor
quam tellus, eu scelerisque quam semper quis. Cras posuere justo et 
scelerisque posuere. Vivamus diam massa, aliquet eu nibh sed, elementum
vulputate odio. Mauris nec gravida lorem. Phasellus egestas suscipit nibh,
vehicula fermentum turpis dictum viverra. Aenean eget consectetur est.
Suspendisse feugiat eget metus eget pulvinar.

Quisque id massa pretium, tempor dolor eget, ornare dolor. Donec id
facilisis ligula. Duis id scelerisque nulla. Interdum et malesuada fames ac
ante ipsum primis in faucibus. Phasellus mollis enim nec libero tincidunt
aliquet. Proin viverra tortor id risus luctus, ut lobortis mi efficitur.
Maecenas non lorem faucibus, egestas ex in, egestas turpis. Phasellus et
arcu sed nibh venenatis venenatis. Orci varius natoque penatibus et magnis
dis parturient montes, nascetur ridiculus mus. Quisque sagittis ac nisi
sit amet maximus. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
```
````

Or in HTML:

````html
<div class="columnflow">
  <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam tempor
    aliquam augue, eleifend eleifend eros placerat ac. Aenean in dignissim
    dolor. Aliquam vitae turpis nulla. Aliquam erat volutpat. Nulla auctor
    quam tellus, eu scelerisque quam semper quis. Cras posuere justo et 
    scelerisque posuere. Vivamus diam massa, aliquet eu nibh sed, elementum
    vulputate odio. Mauris nec gravida lorem. Phasellus egestas suscipit nibh,
    vehicula fermentum turpis dictum viverra. Aenean eget consectetur est.
    Suspendisse feugiat eget metus eget pulvinar.</p>

  <p>Quisque id massa pretium, tempor dolor eget, ornare dolor. Donec id
    facilisis ligula. Duis id scelerisque nulla. Interdum et malesuada fames ac
    ante ipsum primis in faucibus. Phasellus mollis enim nec libero tincidunt
    aliquet. Proin viverra tortor id risus luctus, ut lobortis mi efficitur.
    Maecenas non lorem faucibus, egestas ex in, egestas turpis. Phasellus et
    arcu sed nibh venenatis venenatis. Orci varius natoque penatibus et magnis
    dis parturient montes, nascetur ridiculus mus. Quisque sagittis ac nisi
    sit amet maximus. Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
</div>
````

## Roadmap

- [ ] Configuring columns (number, unequal widths)
- [ ] Remove Quarto dependencies so that this can be used as a vanilla Pnadoc filter too
- [ ] Testing with weird inputs (especially non-paragraph content in and around column sections)
- [ ] Support for other output formats:
  - ODT
  - PDF
  - HTML is pretty doable without a filter using CSS [`columns`](https://developer.mozilla.org/en-US/docs/Web/CSS/columns), but it'd be nice if this filter worked with all four formats and you just turned it off using (for example) [conditional content in Quarto](https://quarto.org/docs/authoring/conditional.html). Or maybe an option to tell the filter in which formats you want to use it.

## Issues

[Right here!](https://github.com/jimjam-slam/columnflow/issues) Or [reach out directly](https://jamesgoldie.dev) if you don't have a GitHub account.

Please pass on feedback and issues - this is still very proof-of-concept, and bugs are expected!

