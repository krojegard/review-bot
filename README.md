# Review Bot
Review Bot will automatically approve pull requests that only make trivial changes to the codebase. You can control which pull requests are considered trivial by editing the `.auto-approve` file in the root directory of your project. If all the files that changed match a pattern in that file, Review Bot will automatically approve the pull request on behalf of whatever user you set it up with. 

## Installation
1. Deploy this code on a server somewhere. Make sure it uses HTTPS since it will need access to your code base.
2. Create a user on github and give it access to your repo. Generate a personal access token for this user in Settings -> Developer settings -> Personal access tokens.
3. Set `GITHUB_API_KEY={api_key}` as an environment variable on the server using the key you generated in step 2.
4. Add a webhook to the github branch you want to protect with the following settings:
<br>&nbsp;&nbsp;&nbsp;&nbsp;Payload URL: `{your_server_url}/api/v1/pull-request`
<br>&nbsp;&nbsp;&nbsp;&nbsp;Content Type: `application/json`
<br>&nbsp;&nbsp;&nbsp;&nbsp;Events: Pull Requests
5. Create a `.auto-approve` file in the root of your project and add filenames or patterns seperated by line breaks

## Configuration
`.auto-approve` should have one file path per line. Paths that start with `/` will match from the root of the project, and `*` will match any file or directory name. An example file would look like this:<br>
```
/test/*/*test.rb
.rubocop.yml
/Gemfile.lock
```
And would match the following files:<br>
`/test/models/user_test.rb`<br>
`/test/models/item_test.rb`<br>
`/test/controllers/login_test.rb`<br>
`/.rubocop.yml`<br>
`/app/controllers/.rubocop.yml`<br>
`/Gemfile.lock`<br>

So if somebody opened a pull request that only modified `/test/controllers/login_test.rb` and `/Gemfile.lock`, it will be instantly approved.