CONTRIBUTING
============

Set up your development environment:

 * `bundle install`
 * `bundle exec jekyll serve -w`
 * Access <http://localhost:4000/development.html> in your browser
   * If you need to use a different hostname/port: 
     * [Register an application with GitHub](https://github.com/settings/applications/new), setting the appropriate `redirect_uri` there.
     * [Spin up your own Gatekeeper instance with your API key](https://github.com/prose/gatekeeper)
     * Make an HTML file like `development.html` with your API key and Gatekeeper instance.
     * Do not include these changes in any pull request.
 * Edit `src/js/github-friction.coffee`
 * Any changes to the HTML skeleton (JS frameworks, etc.) should happen in `_layouts/default.html`
