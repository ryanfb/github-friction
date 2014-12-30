github_friction_oauth =
  client_id: 'f066b4cdf3404200113c'
  redirect_uri: 'http://localhost:4000/'

github_oauth_url = ->
  "https://github.com/login/oauth/authorize?#{$.param(github_friction_oauth)}"

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

build_github_friction = ->
  console.log('build')
  if get_cookie 'access_token'
    console.log('got access token')
  else
    console.log('redirecting to oauth')
    window.location = github_oauth_url()

# main driver entry point
$(document).ready ->
  console.log('ready')
  set_access_token_cookie(get_auth_code(),build_github_friction)
