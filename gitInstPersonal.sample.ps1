# if http proxy is needed for git, $this variable
# $CONF_GIT_PROXY = 'http://proxy.foo.com:8080'
$CONF_GIT_PROXY = $null

# root folder in which you will call git clone.  Do not use a Drive root (e.g. C:\)
$CONF_POSHGIT_STARTDIR = 'C:\github-personal'

# USER and EMAIL can be blank ($XXX = $null) if you want to force prompting

# standard user info for git operations
$CONF_GIT_DEFAULT_USER = 'John Doe'
$CONF_GIT_DEFAULT_EMAIL = 'johndoe@users.noreply.github.com'

# optional settings if a particular dir needs different git credentials for child repos
$CONF_GIT_SECONDARY_USER = 'Jane Doe'
$CONF_GIT_SECONDARY_EMAIL = 'janedoe@users.noreply.github.com'
$CONF_GIT_SECONDARY_PATH = 'C:/github-personal/'
