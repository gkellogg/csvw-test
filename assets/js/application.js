/*global $, _, angular*/

var testApp = angular.module('testApp', ['ngRoute', 'ngResource'])
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
          return(angular.fromJson(data)['@graph'][0].entries);
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
  .controller('ProcessorCtrl', ['$scope', '$log', 'Test',
    function ($scope, $log, Test) {
      $log.debug("ProcessorCtrl");
      // Processors from script tag
      $scope.processors = angular.fromJson($("script#processors").text());
    }
  ])
  .controller('TestStatusCtrl', ['$scope', '$log', 'Test',
    function ($scope, $log, Test) {
      $log.debug("TestStatusCtrl");
      $scope.status = false;
      $scope.total = 0;
      $scope.passed = 0;
      $scope.failed = 0;
    }
  ])
  .controller('TestListCtrl', ['$scope', '$log', 'Test',
    function ($scope, $log, Test) {
      // Get all terms from the vocabulary
      $log.debug("TestListCtrl");
      $scope.tests = Test.query();
      $scope.orderProp = 'id';
    }
  ])
  .controller('TestDetailCtrl', ['$scope', '$routeParams', '$log', 'Test',
    function ($scope, $routeParams, $log, Test) {
      $log.debug("TestDetailCtrl");
      $scope.test = Test.get({testId: $routeParams.testId});
    }
  ]);
