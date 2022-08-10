# GithubText Test


## Installation

`pod install`

- create developer app on github
- paste your github client id and github client secret here:
CredentialsStorage -> 

```
    var githubClientId: String {
        return <#github_client_id#>
    }

    var githubClientSecret: String {
        return <#github_client_secret#>
    }
```
- setup Authorization callback URL to githubtexture://github-auth-callback/
