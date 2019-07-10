const I = actor();

module.exports = {

    // insert your locators and methods here
    // setting locators
    url: "graph/login",
    fields: {
        username: "//input[@name='username']",
        password: "//input[@name='password']"
    },
    loginButton: "//button[@type='submit']",
    skip: "//a[@ng-click='skip();']",

    // introducing methods
    login (username, password) {
        I.fillField(this.fields.username, username);
        I.fillField(this.fields.password, password);
        I.click(this.loginButton);
        I.wait(1);
        I.click(this.skip);
        I.wait(1);
    }
};