# Introduction

This repository controls the [csvw.info](http://csvw.info/) website

# License

Unless otherwise noted, all content in this source repository is released
under a public domain dedication. This includes all HTML, CSS, and JavaScript,
including all source code and testing files associated with the CSVW Test Suite.
At this point in time, the only exception to the public domain dedication are
the icons used on the site, which are copyright by Glyphicons and are
released under the CC-BY-SA-3.0 license.

# CSVW Test Suite

The CSVW Test Suite is a set of Web Services, markup and tests that can 
be used to verify CSVW Processor conformance to the set of specifications
that constitute CSVW 1.0. The goal of the suite is to provide an easy and 
comprehensive CSVW testing solution for developers creating CSVW Processors.

## Design

The CSVW Test suite allows developers to mix and match CSVW processor endpoints.

The CSVW Test Suite is an HTML application driving the entire
process.

The CSVW Test Suite drives the entire process. The first step is to retrieve
the list of tests. Then the CSVW Test Suite requests the endpoint being tested
to return the processing result associated with the test. Depending on the type
of test, the result is compared with expected results using either JSON
equivalence, RDF isomorphism, or the result of a SPARQL ASK query performed on
the results. The CSVW Test Suite will poke the URL, referencing the chosen
processor endpoint with a query parameter indicating the test document, and
other parameters used to control the processor.

The test-suite is implemented using [Ruby](http://www.ruby-lang.org/),
[Sinatra](http://www.sinatrarb.com/) along with the [Linked
Data](http://rubygems.org/gems/linkeddata) gems. The user interface is
implemented in JavaScript using
[Bootstrap.js](http://twitter.github.com/bootstrap/) and
[Backbone.js](http://documentcloud.github.com/backbone/).

Ruby/Sinatra is responsible for running the service, which provides the test
files, launches the HTML application, and executes SPARQL queries on request
from the HTML app. The SPARQL queries, in turn, are access the processor
endpoint to create a graph against which the query is run, with the results
returned to the HTML app as a JSON `true` or `false`.

The HTML application is implemented principally in JavaScript using
[Backbone.js](http://documentcloud.github.com/backbone/). as a
model-viewer-controller, which downloads the test suite manifest and creates a
simple user interface using Bootstrap.js](http://twitter.github.com/bootstrap/)
to run tests, or get test details.

Processing happens in the following order:

    CSVW Test Suite | CSVW Service | CSVW Processor
    load webpage    ->
                    <- test scaffold
    load manifest   ->
                    <- JSON-LD manifest
    run test        -> Load test entry details.
                                    -> Process referenced
                                       test document and
                                       return JSON or RDF with
                                       Content-Type indicating
                                    <- format.
                       SPARQL runs with
                       returned document
                       returning _true_
    display results <- or _false_.

## Running the test suite

You can view and run this test suite at the following URL:

[http://csvw.info/](http://csvw.info/)

## How to create a processor endpoint.

FIXME

## Document caching

Test cases are provided with HTTP ETag headers and expiration values.
Processors _MAY_ cache test case documents but _MUST_ validate the document using HTTP HEAD or conditional GET
operations.
