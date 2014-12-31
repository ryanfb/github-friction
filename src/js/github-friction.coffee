github_friction_oauth =
  client_id: 'f066b4cdf3404200113c'
  redirect_uri: 'http://localhost:4000/'

github_oauth_url = ->
  "https://github.com/login/oauth/authorize?#{$.param(github_friction_oauth)}"

friction_checks =
  readme:
    path: '/'
    regex: /README/
    name: 'README'
    info: 'Every project begins with a README.'
    url: 'http://bit.ly/1dqUYQF'
    critical: true
  contributing:
    path: '/'
    regex: /CONTRIBUTING/
    name: 'CONTRIBUTING guide'
    info: 'Add a guide for potential contributors.'
    url: 'http://git.io/z-TiGg'
    critical: true
  license:
    path: '/'
    regex: /LICENSE/
    name: 'LICENSE'
    info: 'Add a license to protect yourself and your users.'
    url: 'http://choosealicense.com/'
    critical: true
  testscript:
    path: '/script'
    regex: /test/
    name: 'Test script'
    info: 'Make it easy to run the test suite regardless of project type.'
    url: 'http://bit.ly/JZjVL6'
    critical: false
  bootstrap:
    path: '/script'
    regex: /bootstrap/
    name: 'Bootstrap script'
    info: 'A bootstrap script makes setup a snap.'
    url: 'http://bit.ly/JZjVL6'
    critical: false

# filter URL parameters out of the window URL using replaceState 
# returns the original parameters
get_auth_code = ->
  query_string = location.search.substring(1)
  params = {}
  if query_string.length > 0
    regex = /([^&=]+)=([^&]*)/g
    while m = regex.exec(query_string)
      params[decodeURIComponent(m[1])] = decodeURIComponent(m[2])
  history.replaceState(null,'',window.location.href.replace("#{location.search}",''))
  return params

expires_in_to_date = (expires_in) ->
  cookie_expires = new Date
  cookie_expires.setTime(cookie_expires.getTime() + expires_in * 1000)
  return cookie_expires

set_cookie = (key, value, expires_in) ->
  cookie = "#{key}=#{value}; "
  cookie += "expires=#{expires_in_to_date(expires_in).toUTCString()}; "
  cookie += "path=#{window.location.pathname.substring(0,window.location.pathname.lastIndexOf('/')+1)}"
  document.cookie = cookie

delete_cookie = (key) ->
  set_cookie key, null, -1

get_cookie = (key) ->
  key += "="
  for cookie_fragment in document.cookie.split(';')
    cookie_fragment = cookie_fragment.replace(/^\s+/, '')
    return cookie_fragment.substring(key.length, cookie_fragment.length) if cookie_fragment.indexOf(key) == 0
  return null

# write a GitHub OAuth access token into a cached cookie
set_access_token_cookie = (params, callback) ->
  console.log('set_access_token_cookie')
  console.log(params)
  if params['state']?
    console.log "Replacing hash with state: #{params['state']}"
    history.replaceState(null,'',window.location.href.replace("#{location.hash}","##{params['state']}"))
  if params['code']?
    console.log('got code')
    # use gatekeeper to exchange code for token https://github.com/prose/gatekeeper
    $.ajax "https://github-friction-gatekeeper.herokuapp.com/authenticate/#{params['code']}",
      type: 'GET'
      dataType: 'json'
      crossDomain: 'true'
      error: (jqXHR, textStatus, errorThrown) ->
        console.log "Access Token Exchange Error: #{textStatus}"
      success: (data) ->
        console.log('gatekeeper success')
        console.log(data)
        set_cookie('access_token',data.token,31536000)
        set_cookie('access_token_expires_at',expires_in_to_date(params['expires_in']).getTime(),params['expires_in'])
        callback() if callback?
  else
    callback() if callback?

set_cookie_expiration_callback = ->
  if get_cookie('access_token_expires_at')
    expires_in = get_cookie('access_token_expires_at') - (new Date()).getTime()
    console.log(expires_in)
    setTimeout ( ->
        console.log("cookie expired")
        window.location.reload()
      ), expires_in

check_friction = (repo, branch) ->
  console.log("check_friction for #{branch}")
  console.log(repo)
  repo.getTree branch, (err, tree) ->
    console.log(tree)
    (tree.filter (git_object) -> git_object.type == 'blob').map (blob) ->
      for name, friction_check of friction_checks
        if (friction_check.path == '/') && friction_check.regex.test(blob.path)
          console.log("#{blob.path} hit for #{name}")
    script_directory = (tree.filter (git_object) -> (git_object.type == 'tree') && (git_object.path == 'script'))[0]
    if script_directory
      repo.getTree script_directory.sha, (err, script_tree) ->
        console.log "script"
        console.log script_tree
        (script_tree.filter (git_object) -> git_object.type == 'blob').map (blob) ->
          for name, friction_check of friction_checks
            if (friction_check.path == '/script') && friction_check.regex.test(blob.path)
              console.log("#{blob.path} hit for #{name}")
    else
      console.log('no script directory')

build_github_friction = ->
  console.log('build')
  if get_cookie 'access_token'
    console.log('got access token')
    repo_list = $('<ul>').attr('id','repo_list')
    $(document.body).append(repo_list)
    github = new Github(
      token: get_cookie('access_token')
      auth: 'oauth'
    )
    user = github.getUser()
    user.repos((err, repos) ->
      repos.map (repo) ->
        console.log(repo)
        $('#repo_list').append($('<li>').text(repo.name))
        github.getRepo(repo.owner.login, repo.name).listBranches (err, branches) =>
          console.log(repo.name)
          console.log(branches)
          if 'master' in branches
            check_friction(github.getRepo(repo.owner.login, repo.name), 'master')
          else
            check_friction(github.getRepo(repo.owner.login, repo.name), branches[0])
    )
  else
    console.log('redirecting to oauth')
    window.location = github_oauth_url()

# main driver entry point
$(document).ready ->
  console.log('ready')
  set_access_token_cookie(get_auth_code(),build_github_friction)
