---
---

github_friction_debug = false

github_friction_oauth =
  client_id: 'f066b4cdf3404200113c'
  redirect_uri: 'https://ryanfb.github.io/github-friction/'
  gatekeeper_uri: 'https://github-friction-gatekeeper.herokuapp.com/authenticate'

github_oauth_url = ->
  "https://github.com/login/oauth/authorize?#{$.param(github_friction_oauth)}"

friction_checks =
  readme:
    path: '/'
    regex: /^README/
    name: 'README'
    info: 'Every project begins with a README.'
    url: 'http://bit.ly/1dqUYQF'
    critical: true
  contributing:
    path: '/'
    regex: /^CONTRIBUTING/
    name: 'CONTRIBUTING guide'
    info: 'Add a guide for potential contributors.'
    url: 'http://git.io/z-TiGg'
    critical: true
  license:
    path: '/'
    regex: /^LICENSE/
    name: 'LICENSE'
    info: 'Add a license to protect yourself and your users.'
    url: 'http://choosealicense.com/'
    critical: true
  testscript:
    path: '/script'
    regex: /^test/
    name: 'Test script'
    info: 'Make it easy to run the test suite regardless of project type.'
    url: 'http://bit.ly/JZjVL6'
    critical: false
  bootstrap:
    path: '/script'
    regex: /^bootstrap/
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
  console.log('set_access_token_cookie') if github_friction_debug
  console.log(params) if github_friction_debug
  if params['state']?
    console.log "Replacing hash with state: #{params['state']}" if github_friction_debug
    history.replaceState(null,'',window.location.href.replace("#{location.hash}","##{params['state']}"))
  if params['code']?
    console.log('got code') if github_friction_debug
    # use gatekeeper to exchange code for token https://github.com/prose/gatekeeper
    console.log(github_friction_oauth['gatekeeper_uri'])
    $.ajax "#{github_friction_oauth['gatekeeper_uri']}/#{params['code']}",
      type: 'GET'
      dataType: 'json'
      crossDomain: 'true'
      error: (jqXHR, textStatus, errorThrown) ->
        console.log "Access Token Exchange Error: #{textStatus}"
      success: (data) ->
        console.log('gatekeeper success') if github_friction_debug
        console.log(data) if github_friction_debug
        set_cookie('access_token',data.token,31536000)
        set_cookie('access_token_expires_at',expires_in_to_date(31536000))
        callback() if callback?
  else
    callback() if callback?

set_cookie_expiration_callback = ->
  if get_cookie('access_token_expires_at')
    expires_in = get_cookie('access_token_expires_at') - (new Date()).getTime()
    console.log(expires_in) if github_friction_debug
    setTimeout ( ->
        console.log("cookie expired")
        window.location.reload()
      ), expires_in

mark_missing = (repo_id) ->
  for name, friction_check of friction_checks
    data_cell = $("##{repo_id} > .#{name}")
    if data_cell.hasClass('info')
      data_cell.removeClass('info')
      if friction_check.critical
        data_cell.addClass('danger')
      else
        data_cell.addClass('warning')
      link = $('<a>').attr('href',friction_check.url)
      link.attr('title',friction_check.info)
      link.attr('target','_blank')
      link.text(friction_check.name)
      data_cell.text('')
      data_cell.append('\u2612 ')
      data_cell.append(link)

mark_done = (repo_id, name, file_name) ->
  data_cell = $("##{repo_id} > .#{name}")
  data_cell.removeClass('info').addClass('success')
  link = $('<a>')
  repo_url = $("##{repo_id} > .name > a").attr('href')
  branch = $("##{repo_id} > .branch").text()
  link.attr('href',"#{repo_url}/blob/#{branch}/#{file_name}")
  link.attr('target','_blank')
  link.text(data_cell.text().replace(/[\u2610\u2611] /,''))
  data_cell.text('')
  data_cell.append('\u2611 ')
  data_cell.append(link)

check_friction = (repo_id, repo, branch) ->
  console.log("check_friction for #{branch} of #{repo_id}") if github_friction_debug
  # repo.show (err, github_repo) ->
  #  console.log('repo.show')
  #  console.log(github_repo)
  repo.getTree branch, (err, tree) ->
    console.log(tree) if github_friction_debug
    (tree.filter (git_object) -> git_object.type == 'blob').map (blob) ->
      for name, friction_check of friction_checks
        if (friction_check.path == '/') && friction_check.regex.test(blob.path)
          console.log("#{blob.path} hit for #{name}") if github_friction_debug
          console.log(blob) if github_friction_debug
          mark_done(repo_id,name,blob.path)
    script_directory = (tree.filter (git_object) -> (git_object.type == 'tree') && (git_object.path == 'script'))[0]
    if script_directory
      repo.getTree script_directory.sha, (err, script_tree) ->
        console.log "script" if github_friction_debug
        console.log script_tree if github_friction_debug
        (script_tree.filter (git_object) -> git_object.type == 'blob').map (blob) ->
          for name, friction_check of friction_checks
            if (friction_check.path == '/script') && friction_check.regex.test(blob.path)
              console.log("#{blob.path} hit for #{name}") if github_friction_debug
              mark_done(repo_id,name,"script/#{blob.path}")
        mark_missing(repo_id)
    else
      console.log("no script directory for #{repo_id}") if github_friction_debug
      mark_missing(repo_id)

add_repos = (github) ->
  (err, repos) ->
    repos.map (repo) ->
      console.log(repo) if github_friction_debug
      repo_row = $('<tr>').attr('id',repo.id)
      repo_link = $('<a>').attr('href',repo.html_url).text(repo.full_name).attr('target','_blank')
      repo_div = $('<td>').addClass('name').append(repo_link)
      repo_row.append(repo_div)
      repo_row.append($('<td>').attr('class','active text-center').text('master').addClass('branch'))
      for name, friction_check of friction_checks
        repo_row.append($('<td>').attr('class','info text-center').text('\u2610 ' + friction_check.name).addClass(name))
      $('#repo_list').append(repo_row)
      github.getRepo(repo.owner.login, repo.name).listBranches (err, branches) =>
        console.log(repo.name) if github_friction_debug
        console.log(branches) if github_friction_debug
        if 'master' in branches
          check_friction(repo.id, github.getRepo(repo.owner.login, repo.name), 'master')
        else
          $("##{repo.id} > .branch").text(branches[0])
          check_friction(repo.id, github.getRepo(repo.owner.login, repo.name), branches[0])

build_github_friction = ->
  console.log('build') if github_friction_debug
  if get_cookie 'access_token'
    console.log('got access token') if github_friction_debug
    repo_list = $('<table>').attr('id','repo_list').attr('class','table table-bordered')
    container = $('<div>').attr('class','container')
    container.append($('<br>'))
    jumbotron = $('<div>') #.attr('class','jumbotron')
    jumbotron.append($('<h1>').text('GitHub Friction'))
    fork_button = $('<div>').attr('style','float:right;padding-right:1em')
    fork_button.append('<iframe src="https://ghbtns.com/github-btn.html?user=ryanfb&repo=github-friction&type=fork&size=large" allowtransparency="true" frameborder="0" scrolling="0" width="78" height="30"></iframe>')
    jumbotron.append(fork_button)
    jumbotron.append($('<p>').attr('class','lead').text('Check for common sources of contributor friction across your GitHub repositories.'))
    container.append(jumbotron)
    container.append(repo_list)
    $(document.body).append(container)
    github = new Github(
      token: get_cookie('access_token')
      auth: 'oauth'
    )
    user = github.getUser()
    user.repos(add_repos(github))
    user.orgs((err, orgs) ->
      orgs.map (org) ->
        user.orgRepos(org.login, add_repos(github))
    )
  else
    console.log('redirecting to oauth') if github_friction_debug
    window.location = github_oauth_url()

# main driver entry point
$(document).ready ->
  console.log('ready') if github_friction_debug
  github_friction_oauth = $.extend({}, github_friction_oauth, window.github_friction_oauth)
  set_access_token_cookie(get_auth_code(),build_github_friction)
