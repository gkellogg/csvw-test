# Introduction

This repository controls the [csvw.info](http://csvw.info/) website

# License

Unless otherwise noted, all content in this source repository is Distributed under the [W3C Test Suite License][license]. This includes all HTML, CSS, and JavaScript,
including all source code and testing files associated with the CSVW Test Harness.

# CSVW Test Harness

The CSVW Test Harness is a set of Web Services, Web Applications and tests that
can be used to verify CSVW Processor conformance to the set of specifications
that constitute CSVW 1.0. The goal of the suite is to provide an easy and
comprehensive CSVW testing solution for developers creating CSVW Processors.

The CSVW Test Harness allows developers to mix and match CSVW processor endpoints. Test endpoints may be registered along with a name and developer ([DOAP][]) information; this aids in the creation of implementation reports (see [EARL][]). A test endpoint should be specified using a URL to which the _test action_ is appended. Other runtime options may be specified with additional query parameters. For example `http://example.org/endpoint?uri=` would have a test at `http://w3c.github.io/csvw/tests/test001.csv`

## Issues

* Currently, all tests are accessed from the [CSVW Github Repository][csvw-github]. As many tests depend on the property MIME-type and Link Headers being returned, it may be that the tests should be contained entirely within this repository as well.
* This service could also serve as a general home for the CSVW information, providing access to specifications, wiki and a playground in a manner similar to the [rdfa.info](http://rdfa.info) and [json-ld.org](http://json-ld.org). In this case, merging the application with the existing [CSVW Github Repository][csvw-github] might make sense.
* Implementation Reports could be automatically submitted through an HTML form.
* The CSVW Test Harness runs on Heroku, creating a useful domain name to reference this will ease use by the community.

## Design

The CSVW Test Harness is an HTML application driving the entire
process. The harness is composed of an HTML Application and Web Service. The application is responsible for presenting the tests and allowing individual tests to be run, or run all tests by selecting a processor endpoint.

The HTML Application drives the entire process. The first step is to retrieve
the test manifest including the list of tests. Then the CSVW Test Harness
requests the endpoint being tested to return the processing result associated
with the test. Depending on the type of test, the result is compared with
expected results using either JSON equivalence, RDF graph isomorphism, or the
result of a SPARQL ASK query performed on the results. The Web Service will
poke the URL, referencing the chosen processor endpoint with a query parameter
indicating the test document, and other parameters used to control the
processor.

The test-suite is implemented using [Ruby](http://www.ruby-lang.org/),
[Sinatra](http://www.sinatrarb.com/) along with [Linked
Data](http://rubygems.org/gems/linkeddata) gems. The user interface is
implemented in JavaScript using
[Bootstrap][] and
[AngularJS][].

Ruby/Sinatra is responsible for running the service, which provides the test
files, launches the HTML application, invokes the test endpoint to return a processing result, and evaluates the result.

The HTML application is implemented principally in JavaScript using
[AngularJS][], which downloads the test suite manifest and creates a
simple user interface using [Bootstrap][] to run tests, or get test details.

Processing happens in the following order:

    HTML Application | CSVW Service | CSVW Processor
    load manifest   ->
                    <- JSON-LD manifest
    run test        -> Load test entry details.
                                    -> Process referenced
                                       test document and
                                       return JSON or RDF with
                                       Content-Type indicating
                                    <- format.
                       Evaluate processing
                       results returning
                       further information
                       about the test,
                       the processing result,
                       
    display results <- and the evaluation status.

## Running the test suite

You can view and run this test suite at the following URL:

FIXME: [http://csvw.info/](http://csvw.info/)

## How to create a processor endpoint.

FIXME

## Document caching

Test cases are provided with HTTP ETag headers and expiration values.
Processors _MAY_ cache test case documents but _MUST_ validate the document
using HTTP HEAD or conditional GET operations.

[AngularJS]:    https://angularjs.org
[Bootstrap]:    http://getbootstrap.com
[csvw-github]:  http://github.com/w3c/csvw/
[DOAP]:         https://github.com/edumbill/doap/wiki
[EARL]:         http://www.w3.org/TR/EARL10-Schema/
[license]:      http://www.w3.org/Consortium/Legal/2008/04-testsuite-license
