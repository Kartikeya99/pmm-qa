var HtmlScreenshotReporter = require('protractor-jasmine2-screenshot-reporter');

var reporter = new HtmlScreenshotReporter({
  dest: 'screenshots',
  filename: 'pmm-test-report.html',
  captureOnlyFailedSpecs: true
});
 
exports.config = {
 
  // -----------------------------------------------------------------
  // Selenium Setup: An existing Selenium standalone server.
  // -----------------------------------------------------------------
 
  // The address of an existing selenium server that Protractor will use.
  //
  // Note that this server must have chromedriver in its path for Chromium
  // tests to work.
  seleniumAddress: 'http://localhost:4444/wd/hub',
  //seleniumAddress: 'http://ondemand.saucelabs.com:80/wd/hub',
  // seleniumAddress for Crossbrowsertesting
  //seleniumAddress: 'http://your_mail:your_key@hub.crossbrowsertesting.com:80/wd/hub',
  //sauceUser: process.env.SAUCE_USERNAME,
  //sauceKey: process.env.SAUCE_ACCESS_KEY, 
  // -----------------------------------------------------------------
  // Specify the test code that will run.
  // -----------------------------------------------------------------
 
  // Spec patterns are relative to the location of this config.
  //specs: [
  //  'spec/*.spec.js'
  //],

  suites: {
    mainQanPage: 'specs/*spec.js',
    landingPage: 'specs/*spec.js',
//    managementPage: 'management_page/*spec.js',
  },

 
  // -----------------------------------------------------------------
  // Browser and Capabilities
  // -----------------------------------------------------------------
 
  // For a full list of available capabilities, see
  //
  // https://code.google.com/p/selenium/wiki/DesiredCapabilities
 
  // -----------------------------------------------------------------
  // Browser and Capabilities: PhantomJS
  // -----------------------------------------------------------------
 
  // Blocking issues prevent most uses of PhantomJS and Protractor as of
  // Q4 2013. See, for example:
  //
  // https://github.com/angular/protractor/issues/85
  //
  // It is also hard to pass through needed command line parameters.
 
  /*
  capabilities: {
    browserName: 'phantomjs',
    version: '',
    platform: 'ANY'
  },
  */
 
  // -----------------------------------------------------------------
  // Browser and Capabilities: Chrome
  // -----------------------------------------------------------------
  capabilities: {
    browserName: 'chrome',
    version: '',
    platform: 'ANY'
//crossbrowsertesting 
/* name : 'Selenium-Protractor',
    browser_api_name : 'Chrome53x64', // change this according to what browser you are using
    browserName: 'chrome', // change this according to what browser you are using 'internet explorer', 'chrome' etc
    os_api_name : 'Win10', // change this for the OS you are using
    screen_resolution : '1024x768', // change this for the resolution

    // optional recording capabilities
    record_video : 'true',
    record_network : 'false',
    record_snapshot : 'false',

    username :  "your_mail",
    password : "your_key", */
},
  // -----------------------------------------------------------------
  // Browser and Capabilities: Firefox
  // -----------------------------------------------------------------
/* 
  
  capabilities: {
    browserName: 'firefox',
    version: '',
    platform: 'ANY'
  },
 */
  // -----------------------------------------------------------------
  // Application configuration.
  // -----------------------------------------------------------------
 
  // A base URL for your application under test. Calls to browser.get()
  // with relative paths will be prepended with this.
  // baseUrl: 'http://localhost',
 
  // Selector for the element housing the angular app - this defaults to
  // body, but is necessary if ng-app is on a descendant of 
  //rootElement: '*[ng-app]',
//useAllAngular2AppRoots: true 
  // -----------------------------------------------------------------
  // Other configuration.
  // -----------------------------------------------------------------
 
  // The timeout for each script run on the browser. This should be longer
  // than the maximum time your application needs to stabilize between tasks.
  allScriptsTimeout: 15000,
  framework: "jasmine2",
 
  /**
   * A callback function called once protractor is ready and available,
   * and before the specs are executed.
   *
   * You can specify a file containing code to run by setting onPrepare to
   * the filename string.
   */
  beforeLaunch: function() {
      return new Promise(function(resolve){
        reporter.beforeLaunch(resolve);
      });
   },

  onPrepare: function() {
    // At this point, global 'protractor' object will be set up, and
    // jasmine will be available.
    var width = 1600;
    var height = 1200;
    var jasmineReporters = require('jasmine-reporters');
    browser.driver.manage().window().setSize(width, height);
    jasmine.getEnv().addReporter(new jasmineReporters.JUnitXmlReporter({
        consolidateAll: true,
        savePath: 'testresults',
        filePrefix: 'xmloutput'
    }));

    jasmine.getEnv().addReporter(reporter);
  },

  afterLaunch: function(exitCode) {
    return new Promise(function(resolve){
      reporter.afterLaunch(resolve.bind(this, exitCode));
      });
  },
 
  // ----- Options to be passed to minijasminenode -----
  jasmineNodeOpts: {
    /**
     * onComplete will be called just before the driver quits.
     */
    onComplete: function () {},
    // If true, display spec names.
    isVerbose: true,
    // If true, print colors to the terminal.
    showColors: true,
    // If true, include stack traces in failures.
    includeStackTrace: true,
    // Default time to wait in ms before a test fails.
    defaultTimeoutInterval: 100000
  }

};

