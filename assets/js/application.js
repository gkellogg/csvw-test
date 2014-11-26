/*global $, _, angular*/

var testApp = angular.module('testApp', ['ngRoute', 'ngResource', 'ui.bootstrap'])
  .config(['$routeProvider', '$locationProvider', '$logProvider',
    function($routeProvider, $locationProvider, $logProvider) {

      $locationProvider.html5Mode(true);
      $logProvider.debugEnabled(true);
      $routeProvider.
        when('/tests', {
          templateUrl: '/partials/tests-view.html',
          controller: 'TestListCtrl'
        }).
        when('/tests/:testId', {
          templateUrl: '/partials/test-detail.html',
          controller: 'TestDetailCtrl'
        }).
        otherwise({
          controller: function() {
              window.location.replace('/');
          }, 
          template: "<div></div>"
          //redirectTo: '/tests'
        });
    }
  ])
  // Test factory for returning individual test entries
  .factory('Test', ['$resource', '$log', function($resource, $log) {
    return $resource('tests/:testId', {}, {
      // Fetches manifest and extracts test entries
      query: {
        method: 'GET',
        params: {testId:'.jsonld'},
        headers: {'Accept':'application/ld+json'},
        transformResponse: function(data) {
          var jld = angular.fromJson(data)
          if(jld['@graph']) {
            // Returning the entire manifest, extract test entries
            return(_.map(jld['@graph'][0].entries, function(test) {
              test.status = "Test";
              return test;
            }));
          } else {
            // Returning a specific entry
            return(jld['@graph'][0].entries);
          }
        },
        isArray: true
      },
      run: {
        method:'POST',
        params:{testId:'tests', processorUrl:'processorUrl'}
      }
    });
  }])
  .controller('DebugController', function($scope, $route, $routeParams, $location) {
     $scope.$route = $route;
     $scope.$location = $location;
     $scope.$routeParams = $routeParams;
   })
  .controller('TestListCtrl', ['$scope', '$log', 'Test',
    function ($scope, $log, Test) {
      // Processors from script tag
      $scope.processors = angular.fromJson($("script#processors").text());
      $scope.processorUrl = $scope.processors[0].endpoint;

      // Automatically run tests?
      $scope.autorun = false;

      // Tests retrieved in manifest from service
      $scope.nexts = {};
      $scope.tests = Test.query({}, function(tests) {
        $log.debug(tests);

        // Nexts for each test
        for (i = 0; i < tests.length - 1; i++) {
          $scope.nexts[tests[i].id] = tests[i+1];
        }
      });

      // Watch changes to tests
      //$scope.$watch('tests', function(newVal) {
      //  $log.debug("test changed: " + _.map(newVal, function(test) {return test.status}));
      //}, true)

      $scope.passed = function() {
        return _.reduce($scope.tests, function(memo, test) {
          return memo + (test.status === "Pass" ? 1 : 0);
        }, 0);
      };
      $scope.failed = function() {
        return _.reduce($scope.tests, function(memo, test) {
          return memo + (test.status === "Fail" ? 1 : 0);  // XXX: Errored?
        }, 0);
      };
      $scope.errored = function() {
        return _.reduce($scope.tests, function(memo, test) {
          return memo + (test.status === "Error" ? 1 : 0);
        }, 0);
      };
      $scope.completed = function() {
        return _.reduce($scope.tests, function(memo, test) {
          return memo + (test.status === "Test" ? 0 : 1);
        }, 0);
      };
      $scope.setProcessor = function(proc) {
        $scope.processorUrl = proc.endpoint;
      };
      $scope.runTest = function(test, autonext) {
        if (test === "All") {
          $log.info("Run all tests");
          _.each($scope.tests, function(test) { test.status = "Test"; });
          $scope.autorun = true;
          $scope.runTest($scope.tests[0], true);
        } else {
          $log.info("Run " + test.id);
          test.status = "Running";
          test.$run({testId: test.id, processorUrl: $scope.processorUrl},
            function(response, responseHeaders) {
              if (autonext && $scope.nexts[test.id]) {
                $scope.runTest($scope.nexts[test.id], true);
              }
            },
            function(responseHeaders) {
              test.status = "Error";
              if (autonext && $scope.nexts[test.id]) {
                $scope.runTest($scope.nexts[test.id], true);
              }
            }
          );
        }
      };
    }
  ])
  .controller('TestDetailCtrl', ['$scope', '$routeParams', '$log', 'Test',
    function ($scope, $routeParams, $log, Test) {
      $scope.test = Test.get({testId: $routeParams.testId});
    }
  ]);
