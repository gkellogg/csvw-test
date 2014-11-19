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
  .factory('Test', ['$resource', function($resource) {
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
            return(jld['@graph'][0].entries);
          } else {
            // Returning a specific entry
            return(jld['@graph'][0].entries);
          }
        },
        isArray: true
      },
      run: {method:'POST', params:{testId:'tests', processorUrl:'processorUrl'}}
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
      $scope.passed = function() {
        return _.reduce($scope.tests, function(memo, test) {
          return memo + (test.status == "PASSED" ? 1 : 0);
        }, 0);
      };
      $scope.failed = function() {
        return _.reduce($scope.tests, function(memo, test) {
          return memo + (test.status == "FAILED" ? 1 : 0);  // XXX: ERRORED?
        }, 0);
      };
      $scope.running = function() {
        return _.any($scope.tests, function(memo, test) {
          return test.status == "RUNNING";
        }, 0);
      };
      $scope.setProcessor = function(proc) {
        $scope.processorUrl = proc.endpoint;
      };
      $scope.runTest = function(test) {
        test.status = "RUNNING"
        test.$run();
      };
    }
  ])
  .controller('TestDetailCtrl', ['$scope', '$routeParams', '$log', 'Test',
    function ($scope, $routeParams, $log, Test) {
      $log.debug("TestDetailCtrl");
      $scope.test = Test.get({testId: $routeParams.testId});
    }
  ]);
