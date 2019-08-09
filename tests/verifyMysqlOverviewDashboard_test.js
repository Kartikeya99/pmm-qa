
Feature('to verify MySQL Overview Dashboards');

Before((I, loginPage) => {
    I.amOnPage(loginPage.url);
    loginPage.login("admin", "admin");
});

Scenario('Open the MySQL Overview Dashboard', async (I, adminPage, mysqlOverviewPage) => {
    I.amOnPage(mysqlOverviewPage.url);
    I.waitForElement(adminPage.fields.metricTitle, 30);
    adminPage.applyTimer("1m");

    let i=1;
    while(i<=5) {
        // Going through all dashboards
        I.click("(//a[@class='variable-value-link'])[6]");
        I.click("//value-select-dropdown/div/div/div/div/a[" + i + "]");
        I.wait(3);

        // Checking each dashboard
        await adminPage.handleLazyLoading(10);
        I.click(mysqlOverviewPage.fields.systemChartsToggle);
        I.pressKey('Home');
        mysqlOverviewPage.verifyMetricsExistence();

        i++;
    }
});
