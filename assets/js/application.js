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
      // Get all terms from the vocabulary
      $log.debug("TestListCtrl");
      // Processors from script tag
      $scope.processors = angular.fromJson($("script#processors").text());

      // Tests retrieved in manifest from service
      $scope.tests = Test.query();

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
      $scope.running = function() {
        return _.any($scope.tests, function(memo, test) {
          return test.status === "Running";
        }, 0);
      };
      $scope.setProcessor = function(proc) {
        $scope.processorUrl = proc.endpoint;
      };
      $scope.runTest = function(test) {
        test.status = "Running";
        var response = test.$run({testId: test.id},
          function(response, responseHeaders) {
            test.status = response.status;
          },
          function(responseHeaders) {
            test.status = "Error";
          });
      };
    }
  ])
  .controller('TestDetailCtrl', ['$scope', '$routeParams', '$log', 'Test',
    function ($scope, $routeParams, $log, Test) {
      $log.debug("TestDetailCtrl");
      $scope.test = Test.get({testId: $routeParams.testId});
    }
  ]);
